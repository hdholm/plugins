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

use OPNsense\Core\Backend;
use OPNsense\Tang\Tang;

/**
 * Register Tang as a manageable service so it appears in the OPNsense
 * services overview and dashboard widget.
 */
function tang_services()
{
    $services = [];

    $mdl = new Tang();
    if ((string)$mdl->general->enabled === '1') {
        $services[] = [
            'description' => gettext('Tang NBDE Key Server'),
            'configd' => [
                'restart' => ['tang restart'],
                'start' => ['tang start'],
                'stop' => ['tang stop'],
            ],
            'name' => 'tangd',
        ];
    }

    return $services;
}

/**
 * Boot-time hook: write the keys held in config.xml out to the on-disk JWK
 * directory so a restored backup or a freshly synced HA peer serves the right
 * keys. tangd is spawned per-connection by socat and re-reads the directory on
 * every request, so no restart is required for the keys to take effect.
 */
function tang_configure()
{
    return [
        'bootup' => ['tang_configure_do'],
    ];
}

function tang_configure_do($verbose = false)
{
    $mdl = new Tang();
    if ((string)$mdl->general->enabled === '1') {
        (new Backend())->configdRun('tang keys materialize');
        (new Backend())->configdRun('tang restart');
    }
}

/**
 * The tangd daemon listens on all interfaces. When the operator selects one or
 * more interfaces, add automatic firewall rules that pass the Tang port to this
 * firewall on those interfaces and block it on every other interface.
 */
function tang_firewall($fw)
{
    global $config;

    $general = $config['OPNsense']['Tang']['general'] ?? null;
    if (empty($general) || ($general['enabled'] ?? '0') != '1') {
        return;
    }

    $interfaces = trim((string)($general['interfaces'] ?? ''));
    if ($interfaces === '') {
        /* no interfaces selected: do not add any automatic rules */
        return;
    }

    $port = !empty($general['port']) ? $general['port'] : '9090';

    foreach (['inet', 'inet6'] as $ipproto) {
        /* allow the selected interfaces to reach the daemon on this firewall */
        $fw->registerFilterRule(
            10,
            [
                'type' => 'pass',
                'direction' => 'in',
                'quick' => true,
                'interface' => $interfaces,
                'ipprotocol' => $ipproto,
                'protocol' => 'tcp',
                'to' => '(self)',
                'to_port' => $port,
                'descr' => 'Tang NBDE allow (' . $ipproto . ')',
            ]
        );
        /* block the daemon port to this firewall on all other interfaces */
        $fw->registerFilterRule(
            11,
            [
                'type' => 'block',
                'direction' => 'in',
                'quick' => true,
                'ipprotocol' => $ipproto,
                'protocol' => 'tcp',
                'to' => '(self)',
                'to_port' => $port,
                'descr' => 'Tang NBDE block others (' . $ipproto . ')',
            ]
        );
    }
}

/**
 * Replicate the Tang configuration - including the stored keys - to HA peers
 * via XMLRPC sync.
 */
function tang_xmlrpc_sync()
{
    $result = [];
    $result[] = [
        'description' => gettext('Tang NBDE'),
        'section' => 'OPNsense.Tang',
        'id' => 'tang',
        'services' => ['tangd'],
    ];

    return $result;
}
