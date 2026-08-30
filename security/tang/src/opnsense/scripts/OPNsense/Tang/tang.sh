#!/bin/sh

# Copyright (C) 2026 Howard Holm <hdholm@alumni.iastate.edu>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# ---------------------------------------------------------------------------
# Tang NBDE helper - invoked by configd (see actions_tang.conf).
#
# Service control is delegated to the rc.d/tangd script shipped by the
# security/tang package (a socat listener that forks the tangd CGI per
# connection). This wrapper keeps the on-disk JWK directory in sync with the
# authoritative copy of the keys held in config.xml (which is what gets backed
# up and replicated to HA peers), and drives the key-management tools that ship
# with tang.
#
# config.xml <-> disk synchronisation is done by store.php:
#   materialize : config.xml -> disk   (before the daemon serves keys)
#   capture     : disk -> config.xml   (after keys are created/rotated/deleted)
#
# Subcommands:
#   start | stop | restart | status   - service lifecycle (via service(8))
#   materialize                       - write config.xml keys to disk
#   keygen                            - create an initial key pair if none exist
#   rotate                            - hide current keys, advertise a new pair
#   delhidden                         - permanently delete hidden (rotated) keys
#   list                              - emit JSON describing keys on disk
#   log [lines] [filter]              - emit JSON with the tail of the log file
#   clearlog                          - truncate the log file in place
#
# Key files:
#   <jwkdir>/<thp>.jwk    advertised keys
#   <jwkdir>/.<thp>.jwk   hidden keys (still served for existing bindings)
#
# Logging:
#   The rc.d/tangd script shipped with security/tang appends the daemon's stderr
#   to ${tangd_logfile} with "2>> ${tangd_logfile}", so the descriptor is opened
#   O_APPEND and stays open for the lifetime of the daemon. clearlog therefore
#   truncates the file in place rather than unlinking it: removing the file would
#   leave the running daemon writing to an orphaned inode, and truncating a
#   non-O_APPEND descriptor would leave a NUL-padded sparse file. Truncation also
#   preserves the file's ownership and mode, and needs no service restart.
# ---------------------------------------------------------------------------

set -u

CONFIG_XML="/conf/config.xml"
LIBEXEC="/usr/local/libexec"
DEFAULT_JWKDIR="/var/db/tang"
DEFAULT_LOGFILE="/var/log/tang"
PHP="/usr/local/bin/php"
STORE="/usr/local/opnsense/scripts/OPNsense/Tang/store.php"

# Largest slice of the log file examined by the "log" subcommand. Bounds both
# memory use and response size on a log that has grown without rotation; the
# emitted JSON reports whether the window clipped the file.
LOG_WINDOW_BYTES=8388608

jwkdir() {
    d=$(/usr/local/bin/xmllint --xpath "string(//OPNsense/Tang/general/jwkdir)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${d}" ] && echo "${d}" || echo "${DEFAULT_JWKDIR}"
}

# Path the rc.d script appends the daemon's stderr to, as configured on the
# General tab (tangd_logfile in /etc/rc.conf.d/tangd).
logfile() {
    f=$(/usr/local/bin/xmllint --xpath "string(//OPNsense/Tang/general/logfile)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${f}" ] && echo "${f}" || echo "${DEFAULT_LOGFILE}"
}

JWKDIR=$(jwkdir)

ensure_dir() {
    if [ ! -d "${JWKDIR}" ]; then
        mkdir -p "${JWKDIR}" || return 1
        chmod 0700 "${JWKDIR}"
    fi
}

# True (0) when at least one advertised or hidden key file is present.
have_keys() {
    for f in "${JWKDIR}"/*.jwk "${JWKDIR}"/.*.jwk; do
        [ -e "${f}" ] && return 0
    done
    return 1
}

materialize() {
    "${PHP}" "${STORE}" materialize >/dev/null 2>&1 || true
}

capture() {
    "${PHP}" "${STORE}" capture >/dev/null 2>&1 || true
}

# Restore keys from config, and if nothing exists anywhere, seed an initial pair.
prepare_keys() {
    ensure_dir || return 1
    materialize
    # tangd will generate it's own keys if none exist when it gets asked for
    # keys.  But since we need to capture the generated keys for config.xml,
    # we'll generate some if we don't have them and then capture them
    if ! have_keys; then
        "${LIBEXEC}/tangd-keygen" "${JWKDIR}" >/dev/null 2>&1 || return 1
        capture
    fi
    return 0
}

case "${1:-}" in
    start)
        prepare_keys || echo "warning: could not prepare key directory ${JWKDIR}" >&2
        /usr/sbin/service tangd onestart
        ;;
    stop)
        /usr/sbin/service tangd onestop
        ;;
    restart)
        prepare_keys || echo "warning: could not prepare key directory ${JWKDIR}" >&2
        /usr/sbin/service tangd onerestart
        ;;
    status)
        /usr/sbin/service tangd onestatus
        exit 0
        ;;
    materialize)
        ensure_dir || { echo "ERROR: cannot create ${JWKDIR}"; exit 1; }
        "${PHP}" "${STORE}" materialize
        ;;
    keygen)
        ensure_dir || { echo "ERROR: cannot create ${JWKDIR}"; exit 1; }
        materialize
        # Only seed a pair when the directory is empty; use rotate to add keys.
        adv=$(ls -1 "${JWKDIR}"/*.jwk 2>/dev/null | wc -l | tr -d ' ')
        if [ "${adv}" != "0" ]; then
            echo "OK: keys already present; use rotate to add a new pair"
            exit 0
        fi
        if "${LIBEXEC}/tangd-keygen" "${JWKDIR}"; then
            capture
            echo "OK: initial key pair generated in ${JWKDIR}"
        else
            echo "ERROR: tangd-keygen failed"
            exit 1
        fi
        ;;
    rotate)
        ensure_dir || { echo "ERROR: cannot create ${JWKDIR}"; exit 1; }
        materialize
        if "${LIBEXEC}/tangd-rotate-keys" -d "${JWKDIR}"; then
            capture
            echo "OK: keys rotated"
        else
            echo "ERROR: tangd-rotate-keys failed"
            exit 1
        fi
        ;;
    delhidden)
        materialize
        n=0
        for f in "${JWKDIR}"/.*.jwk; do
            [ -e "${f}" ] || continue
            rm -f "${f}" && n=$((n + 1))
        done
        capture
        echo "OK: deleted ${n} hidden key file(s)"
        ;;
    list)
        JWKDIR="${JWKDIR}" /usr/local/bin/python3 - <<'PYEOF'
import os, sys, json, glob, base64, hashlib

jwkdir = os.environ.get("JWKDIR", "/var/db/tang")

def thumbprint(jwk):
    kty = jwk.get("kty")
    if kty == "EC":
        members = ["crv", "kty", "x", "y"]
    elif kty == "RSA":
        members = ["e", "kty", "n"]
    elif kty == "oct":
        members = ["k", "kty"]
    else:
        members = sorted(k for k in jwk if k not in ("d", "p", "q", "dp", "dq", "qi", "key_ops", "alg", "kid"))
    try:
        canon = {m: jwk[m] for m in members}
    except KeyError:
        return ""
    data = json.dumps(canon, sort_keys=True, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()

def role(alg):
    if alg == "ES512":
        return "signing"
    if alg == "ECMR":
        return "exchange"
    return alg or "unknown"

rows = []
patterns = [(os.path.join(jwkdir, "*.jwk"), True),
            (os.path.join(jwkdir, ".*.jwk"), False)]
for pattern, advertised in patterns:
    for path in sorted(glob.glob(pattern)):
        name = os.path.basename(path)
        if name in (".", ".."):
            continue
        try:
            with open(path) as fh:
                jwk = json.load(fh)
        except Exception:
            continue
        alg = jwk.get("alg", "")
        rows.append({
            "file": name,
            "thp": thumbprint(jwk),
            "alg": alg,
            "role": role(alg),
            "advertised": advertised,
        })

print(json.dumps(rows))
PYEOF
        ;;
    log)
        # Emit the tail of the log file as JSON. Arguments are supplied by
        # configd, which already single-quotes them; they are re-validated here
        # so the script is also safe to run by hand.
        LOGFILE="$(logfile)" LINES="${2:-500}" FILTER="${3:-}" \
            WINDOW="${LOG_WINDOW_BYTES}" /usr/local/bin/python3 - <<'PYEOF'
import json, os

path = os.environ.get("LOGFILE", "/var/log/tang")
flt = os.environ.get("FILTER", "")

def clamp(name, default, low, high):
    try:
        value = int(os.environ.get(name, ""))
    except ValueError:
        return default
    return max(low, min(value, high))

maxlines = clamp("LINES", 500, 1, 10000)
window = clamp("WINDOW", 8388608, 65536, 67108864)

result = {
    "logfile": path,
    "exists": False,
    "size": 0,
    "clipped": False,
    "matched": 0,
    "rows": [],
}

if os.path.isfile(path):
    result["exists"] = True
    size = os.path.getsize(path)
    result["size"] = size
    with open(path, "rb") as fh:
        if size > window:
            # Seek to the start of the window and drop the (probably partial)
            # first line so callers never see a half record.
            fh.seek(size - window)
            fh.readline()
            result["clipped"] = True
        data = fh.read()
    # The daemon writes plain text, but never assume that of a log file.
    lines = data.decode("utf-8", "replace").splitlines()
    if flt:
        needle = flt.lower()
        lines = [line for line in lines if needle in line.lower()]
    result["matched"] = len(lines)
    result["rows"] = [{"line": line} for line in lines[-maxlines:]]

print(json.dumps(result))
PYEOF
        ;;
    clearlog)
        LOGFILE=$(logfile)
        if [ ! -e "${LOGFILE}" ]; then
            # Nothing written yet: report success so the GUI stays idempotent.
            echo "OK: ${LOGFILE} does not exist"
        elif [ ! -f "${LOGFILE}" ]; then
            echo "ERROR: ${LOGFILE} is not a regular file"
            exit 1
        elif : > "${LOGFILE}"; then
            # Truncate rather than unlink: the daemon holds an O_APPEND
            # descriptor on this file and would otherwise keep writing to an
            # inode nothing can read.
            echo "OK: cleared ${LOGFILE}"
        else
            echo "ERROR: could not clear ${LOGFILE}"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|materialize|keygen|rotate|delhidden|list|log|clearlog}" >&2
        exit 1
        ;;
esac
