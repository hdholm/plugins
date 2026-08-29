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

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Tang\Tang;

/**
 * Key lifecycle endpoints for the Tang daemon.
 *
 * Keys are stored authoritatively in config.xml (so they are backed up and
 * replicated to HA peers) and mirrored to the on-disk JWK directory that tangd
 * serves from. The configd-invoked helper (tang.sh) keeps the two in sync:
 * every mutating operation writes the new on-disk state back into config.xml.
 *
 *   GET  /api/tang/keys/search      - list stored keys with thumbprints
 *   POST /api/tang/keys/keygen      - generate an initial key pair (if none)
 *   POST /api/tang/keys/rotate      - rotate: hide current keys, add a new pair
 *   POST /api/tang/keys/delhidden   - permanently delete hidden (rotated) keys
 *
 * @package OPNsense\Tang
 */
class KeysController extends ApiControllerBase
{
    /**
     * RFC 7638 JWK thumbprint (SHA-256, base64url, unpadded) - identical to
     * `jose jwk thp -a S256`, which is what tang advertises and clevis pins.
     */
    private function thumbprint($jwk)
    {
        if (!is_array($jwk) || empty($jwk['kty'])) {
            return '';
        }
        switch ($jwk['kty']) {
            case 'EC':
                $members = ['crv', 'kty', 'x', 'y'];
                break;
            case 'RSA':
                $members = ['e', 'kty', 'n'];
                break;
            case 'oct':
                $members = ['k', 'kty'];
                break;
            default:
                return '';
        }
        $canon = [];
        foreach ($members as $m) {
            if (!isset($jwk[$m])) {
                return '';
            }
            $canon[$m] = $jwk[$m];
        }
        $json = json_encode($canon, JSON_UNESCAPED_SLASHES);
        return rtrim(strtr(base64_encode(hash('sha256', $json, true)), '+/', '-_'), '=');
    }

    private function role($alg)
    {
        if ($alg === 'ES512') {
            return 'signing';
        }
        if ($alg === 'ECMR') {
            return 'exchange';
        }
        return $alg !== '' ? $alg : 'unknown';
    }

    /**
     * List keys held in config.xml (advertised and hidden) with thumbprints.
     * @return array
     */
    public function searchAction()
    {
        $rows = [];
        $mdl = new Tang();
        foreach ($mdl->keys->key->iterateItems() as $node) {
            $name = (string)$node->filename;
            $jwk = json_decode(base64_decode((string)$node->payload), true);
            $alg = is_array($jwk) && isset($jwk['alg']) ? $jwk['alg'] : '';
            $rows[] = [
                'file' => $name,
                'thp' => $this->thumbprint($jwk),
                'alg' => $alg,
                'role' => $this->role($alg),
                'advertised' => (strpos($name, '.') !== 0),
            ];
        }
        return [
            'rows' => $rows,
            'rowCount' => count($rows),
            'total' => count($rows),
            'current' => 1,
        ];
    }

    /**
     * Generate an initial key pair when no keys exist yet.
     * @return array
     */
    public function keygenAction()
    {
        if ($this->request->isPost()) {
            $response = trim((new Backend())->configdRun('tang keys keygen'));
            return ['status' => 'ok', 'response' => $response];
        }
        return ['status' => 'failed'];
    }

    /**
     * Rotate keys: the current advertised keys are hidden (they keep working for
     * existing Clevis bindings) and a fresh pair is generated and advertised.
     * @return array
     */
    public function rotateAction()
    {
        if ($this->request->isPost()) {
            $response = trim((new Backend())->configdRun('tang keys rotate'));
            return ['status' => 'ok', 'response' => $response];
        }
        return ['status' => 'failed'];
    }

    /**
     * Permanently delete the hidden (previously rotated) keys.
     * @return array
     */
    public function delhiddenAction()
    {
        if ($this->request->isPost()) {
            $response = trim((new Backend())->configdRun('tang keys delhidden'));
            return ['status' => 'ok', 'response' => $response];
        }
        return ['status' => 'failed'];
    }
}
