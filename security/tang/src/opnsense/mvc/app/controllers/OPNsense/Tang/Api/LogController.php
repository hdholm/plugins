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

/**
 * Read and clear the Tang daemon log.
 *
 * tangd has no syslog facility of its own: the rc.d script shipped with
 * security/tang appends the daemon's stderr to the file named by
 * ${tangd_logfile} (the "Log file" setting on the General tab). It is therefore
 * a plain file rather than something the standard syslog viewer can serve, so
 * reading and truncating it are delegated to the configd helper, which runs
 * privileged and resolves the configured path.
 *
 *   GET  /api/tang/log/get      - tail of the log, optionally filtered
 *   POST /api/tang/log/clear    - truncate the log file in place
 *
 * @package OPNsense\Tang
 */
class LogController extends ApiControllerBase
{
    /**
     * Upper bound on the number of lines returned in one response, mirroring the
     * limit the helper script enforces. Kept in step with tang.sh.
     */
    private const MAX_LINES = 10000;

    /**
     * Longest accepted filter string.
     */
    private const MAX_FILTER = 128;

    /**
     * Return the tail of the log file.
     *
     * Accepts two optional query parameters:
     *   lines  - number of lines to return (1 - 10000, default 500)
     *   filter - case-insensitive substring; only matching lines are returned
     *
     * @return array
     */
    public function getAction()
    {
        $lines = $this->request->get('lines', 'int', 500);
        if ($lines < 1) {
            $lines = 500;
        }
        $lines = min($lines, self::MAX_LINES);

        /* Strip control characters so the filter cannot smuggle newlines or
           terminal escapes into the configd command line, and cap the length. */
        $filter = (string)$this->request->get('filter', null, '');
        $filter = preg_replace('/[[:cntrl:]]/', '', $filter);
        $filter = mb_substr($filter, 0, self::MAX_FILTER);

        $response = (new Backend())->configdpRun('tang log get', [$lines, $filter]);
        $result = json_decode(trim((string)$response), true);
        if (!is_array($result)) {
            return [
                'status' => 'failed',
                'message' => gettext('Could not read the log file.'),
                'rows' => [],
            ];
        }
        $result['status'] = 'ok';

        return $result;
    }

    /**
     * Truncate the log file.
     *
     * The file is emptied in place rather than removed, because the running
     * daemon holds an open descriptor on it.
     *
     * @return array
     */
    public function clearAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed'];
        }
        $response = trim((string)(new Backend())->configdRun('tang log clear'));
        if (strpos($response, 'OK') === 0) {
            return ['status' => 'ok', 'response' => $response];
        }

        return ['status' => 'failed', 'response' => $response];
    }
}
