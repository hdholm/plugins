<?php

/*
 * Copyright (C) 2021 Deciso B.V.
 * All rights reserved.
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
namespace OPNsense\Apache\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class GatewayController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'apache';
    protected static $internalModelClass = 'OPNsense\Apache\Apache';

    public function searchVirtualServerAction()
    {
        return $this->searchBase("virtualservers.virtualserver", ['enabled', 'description'], "sequence");
    }

    public function setVirtualServerAction($uuid)
    {
        return $this->setBase("virtualserver", "virtualservers.virtualserver", $uuid);
    }

    public function addVirtualServerAction()
    {
        return $this->addBase("virtualserver", "virtualservers.virtualserver");
    }

    public function getVirtualServerAction($uuid = null)
    {
        return $this->getBase("virtualserver", "virtualservers.virtualserver", $uuid);
    }

    public function delVirtualServerAction($uuid)
    {
        return $this->delBase("virtualservers.virtualserver", $uuid);
    }

    public function toggleVirtualServerAction($uuid, $enabled = null)
    {
        return $this->toggleBase("virtualservers.virtualserver", $uuid, $enabled);
    }

    public function searchLocationAction()
    {
        $virtualserver = $this->request->get('virtualserver');
        $filter_funct = null;
        if (!empty($virtualserver)) {
            $filter_funct = function ($record) use ($virtualserver) {
                return $record->virtualserver == $virtualserver;
            };
        }
        return $this->searchBase(
            "locations.location",
            ['enabled', 'description', 'virtualserver'],
            "sequence",
            $filter_funct
        );
    }

    public function setLocationAction($uuid)
    {
        return $this->setBase("location", "locations.location", $uuid);
    }

    public function addLocationAction()
    {
        return $this->addBase("location", "locations.location");
    }

    public function getLocationAction($uuid = null)
    {
        $vs_uuid = $this->request->get('virtualserver');
        $result = $this->getBase("location", "locations.location", $uuid);
        if (empty($uuid) && !empty($vs_uuid)) {
            foreach ($result['location']['virtualserver'] as $key => &$value) {
                if ($key == $vs_uuid) {
                    $value['selected'] = 1;
                } else {
                    $value['selected'] = 0;
                }
            }
        }
        return $result;
    }

    public function delLocationAction($uuid)
    {
        return $this->delBase("locations.location", $uuid);
    }

    public function toggleLocationAction($uuid, $enabled = null)
    {
        return $this->toggleBase("locations.location", $uuid, $enabled);
    }
}
