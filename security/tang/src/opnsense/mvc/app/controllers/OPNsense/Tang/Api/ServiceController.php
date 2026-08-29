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

namespace OPNsense\Tang\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;

/**
 * Start / stop / restart / reconfigure / status for the Tang (tangd) daemon.
 *
 * The base class runs the configd actions "tang start|stop|restart|reload|status"
 * (defined in service/conf/actions.d/actions_tang.conf) and derives status from
 * the rc.subr output text.
 *
 *   POST /api/tang/service/start
 *   POST /api/tang/service/stop
 *   POST /api/tang/service/restart
 *   POST /api/tang/service/reconfigure
 *   GET  /api/tang/service/status
 *
 * @package OPNsense\Tang
 */
class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\OPNsense\Tang\Tang';
    protected static $internalServiceTemplate = 'OPNsense/Tang';
    protected static $internalServiceEnabled = 'general.enabled';
    protected static $internalServiceName = 'tang';

    /**
     * Reload the firewall on reconfigure so the automatic interface-restriction
     * rules registered by tang_firewall() are (re)generated immediately when the
     * settings are saved, rather than only on the next manual filter apply.
     */
    protected function invokeFirewallReload()
    {
        return true;
    }
}
