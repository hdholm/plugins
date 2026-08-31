#!/usr/local/bin/php
<?php

/*
 * Copyright (C) 2021-2026 Howard Holm <hdholm@alumni.iastate.edu>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Synchronise Tang key material between config.xml (the authoritative, backed-up
 * and HA-replicated store) and the on-disk JWK directory that the tangd daemon
 * actually serves from.
 *
 *   store.php materialize   config.xml -> disk (used on boot / apply / HA peer)
 *   store.php capture        disk -> config.xml (used after keygen/rotate/delete)
 *
 * A key file named "<thp>.jwk" is advertised; ".<thp>.jwk" (leading dot) is a
 * hidden/rotated key that is still served for existing bindings but no longer
 * advertised. Both are round-tripped verbatim (base64 in config.xml).
 */

require_once('config.inc');
require_once('util.inc');

use OPNsense\Core\Config;
use OPNsense\Tang\Tang;

function tang_jwkdir($mdl)
{
    $dir = trim((string)$mdl->general->jwkdir);
    return $dir !== '' ? $dir : '/var/db/tang';
}

/* absolute paths of every key file (advertised + hidden) currently on disk */
function tang_disk_files($dir)
{
    $files = [];
    foreach (['*.jwk', '.*.jwk'] as $glob) {
        foreach (glob($dir . '/' . $glob, GLOB_NOSORT) ?: [] as $path) {
            $base = basename($path);
            if ($base === '.' || $base === '..' || !is_file($path)) {
                continue;
            }
            $files[$base] = $path;
        }
    }
    return $files;
}

function do_materialize()
{
    $mdl = new Tang();
    $dir = tang_jwkdir($mdl);

    $wanted = [];
    foreach ($mdl->keys->key->iterateItems() as $node) {
        $name = basename(trim((string)$node->filename));
        $data = base64_decode(preg_replace('/\s+/', '', (string)$node->payload), true);
        if ($name === '' || $data === false) {
            continue;
        }
        $wanted[$name] = $data;
    }

    /*
     * An empty key list in config.xml is never an instruction to empty the key
     * directory. It means this host's keys have not been adopted yet: the plugin
     * was just installed on a firewall that already serves tang, or the
     * directory was seeded out of band - note that tangd itself mints a pair on
     * the first request whenever it finds the directory empty. Pruning here
     * would destroy key material that live Clevis bindings depend on and that no
     * backup has a copy of, since the whole point of the config.xml store is to
     * be that backup. Adopt what is on disk instead.
     */
    if (empty($wanted)) {
        $ondisk = tang_disk_files($dir);
        if (empty($ondisk)) {
            echo "no keys in configuration and none in {$dir}; nothing to do\n";
            return;
        }
        echo "no keys in configuration; adopting " . count($ondisk) . " key(s) from {$dir}\n";
        do_capture();
        return;
    }

    foreach ($wanted as $name => $data) {
        $path = $dir . '/' . $name;
        if (!is_file($path) || file_get_contents($path) !== $data) {
            file_put_contents($path, $data);
        }
        @chmod($path, 0440);
    }

    /* drop on-disk keys that are no longer present in config (rotations/deletes) */
    foreach (tang_disk_files($dir) as $base => $path) {
        if (!array_key_exists($base, $wanted)) {
            @unlink($path);
        }
    }

    echo "materialized " . count($wanted) . " key(s) to {$dir}\n";
}

function do_capture()
{
    $mdl = new Tang();
    $dir = tang_jwkdir($mdl);

    /* remove existing key entries */
    $uuids = [];
    foreach ($mdl->keys->key->iterateItems() as $uuid => $node) {
        $uuids[] = $uuid;
    }
    foreach ($uuids as $uuid) {
        $mdl->keys->key->del($uuid);
    }

    /* re-add from disk */
    $count = 0;
    foreach (tang_disk_files($dir) as $base => $path) {
        $data = file_get_contents($path);
        if ($data === false) {
            continue;
        }
        $node = $mdl->keys->key->add();
        $node->filename = $base;
        $node->payload = base64_encode($data);
        $count++;
    }

    $mdl->serializeToConfig();
    Config::getInstance()->save();

    echo "captured {$count} key(s) from {$dir}\n";
}

$mode = $argv[1] ?? '';
switch ($mode) {
    case 'materialize':
        do_materialize();
        break;
    case 'capture':
        do_capture();
        break;
    default:
        fwrite(STDERR, "Usage: store.php {materialize|capture}\n");
        exit(1);
}
