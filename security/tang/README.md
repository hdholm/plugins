# os-tang — Tang NBDE key server plugin for OPNsense

Manages the [Tang](https://github.com/latchset/tang) daemon for Network-Bound
Disk Encryption (NBDE) from the OPNsense GUI, under **Services → Tang NBDE**.

## How it runs

The `security/tang` FreeBSD package ships the `tangd` program plus an
`rc.d/tangd` script. This plugin does not replace that; it drives it:

- The settings form writes `/etc/rc.conf.d/tangd` (via the configd template
  `OPNsense/Tang`) with the exact variables the port's rc script reads:
  `tangd_enable`, `tangd_port`, `tangd_jwkdir`, and `tangd_logfile`.
- Service start/stop/restart/status go through `service tangd` (configd
  actions in `actions_tang.conf`, invoked by the standard
  `ApiMutableServiceControllerBase`).
- Before the daemon is started, the helper script ensures the key directory
  exists and contains a key pair, generating one with `tangd-keygen` if needed.

socat is not involved. Since tang 15 the rc script runs
`tangd -p <port> -l <jwkdir>`, which binds the port itself and stays resident
while the service is enabled, forking a child for each accepted connection.

## Keys

Keys are stored authoritatively in `config.xml` and mirrored to the on-disk key
directory (default `/var/db/tang`) that tangd serves from. Storing them in
`config.xml` means they are captured in configuration backups and replicated to
High Availability peers automatically, with no extra steps.

Synchronisation is handled by `scripts/OPNsense/Tang/store.php`:

- **materialize** (`config.xml` -> disk) runs on boot, on apply, and before the
  service starts - so a restored backup or a freshly synced HA peer serves the
  right keys. If `config.xml` holds no keys, materialize does **not** empty the
  directory: it adopts whatever keys are already there, capturing them into the
  configuration. Installing the plugin on a firewall that already serves tang
  therefore preserves that host's keys, and with them every existing Clevis
  binding.
- **capture** (disk -> `config.xml`) runs after every key operation, recording
  the new on-disk state back into the configuration.

Operations:

- **Rotate keys** — `tangd-rotate-keys` hides the current keys (renamed to
  `.<thp>.jwk`, still served for existing bindings) and advertises a fresh pair.
- **Delete hidden keys** — permanently removes the rotated-out `.<thp>.jwk`
  keys. Do this only after every client has been re-provisioned.

Key changes do not require a service restart. Each tangd request handler calls
`read_keys()`, which re-reads the key directory on that request; nothing is
cached in the resident parent process. Changing a *setting* (port, key
directory, log file) does need a restart, because those are command-line
arguments, and the reconfigure that runs on save already performs it.

Because `config.xml` now contains private key material, protect your
configuration backups accordingly.

## Logging

The `rc.d/tangd` script appends the daemon's standard error to the file named by
`tangd_logfile` (the **Log file** setting on the General tab, default
`/var/log/tang`). tangd has no syslog facility of its own, so this plain file is
the only record of client activity.

The **Log** tab shows the tail of that file. Choose how many lines to display,
optionally filter to a case-insensitive substring (handy for isolating a single
client address), and use **Clear log** to empty the file.

Clearing truncates the file in place instead of deleting it. The daemon holds an
open append-mode descriptor on the log for as long as it runs, so unlinking the
file would leave it writing to an inode nothing can read until the next restart.
Truncation keeps the existing ownership and mode and needs no restart.

Nothing here rotates the log. If it is left to grow, the viewer examines only the
most recent 8 MiB and says so; add an entry under
Services: Log Files if you want the file rotated on a schedule.

## Dependencies

`tang` (which provides `tangd`, `tangd-keygen`, `tangd-rotate-keys`,
`tang-show-keys` and the `rc.d/tangd` script.)

## Firewall

Tang performs no authentication. The tangd daemon listens on all
interfaces by design; access is restricted at the firewall. On the General
tab, select the interfaces that should be allowed to reach the daemon. The
plugin then registers automatic rules (visible under Firewall: Automation)
that pass the configured TCP port (default 9090) to this firewall on the
selected interfaces and block it on all other interfaces, for both IPv4 and
IPv6. Leaving the interface list empty adds no automatic rules, so access is
then governed entirely by your existing ruleset.

## Claude.ai
Claude Pro (Opus 4.8 High) was  used to assist in creating the plugin based on
some previous non-AI attempts. The bulk of that interaction is recorded
[here](Claude.md).  All code was human reviewed and tested.

## License

BSD 2-Clause.
