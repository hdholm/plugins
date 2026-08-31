{#
 # Copyright (C) 2021-2026 Howard Holm <hdholm@alumni.iastate.edu>
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
 # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 #}

<script>
$(document).ready(function () {

    function htmlEnc(s) {
        const entityMap = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        };

        return String(s).replace(/[&<>"']/g, match => entityMap[match]);
        //return String(s)
        //    .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        //    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function showAlert(type, msg) {
        var a = $('<div class="alert alert-' + type + ' alert-dismissible" role="alert">' +
            '<button type="button" class="close" data-dismiss="alert">&times;</button>' +
            msg + '</div>');
        $('#tang-alerts').empty().append(a);
        if (type === 'success') {
            setTimeout(function () { a.fadeOut(400, function () { a.remove(); }); }, 4000);
        }
    }

    function refreshStatus() {
        ajaxCall("/api/tang/service/status", {}, function (d) {
            var s = (d && d.status) ? d.status : 'unknown';
            var cls = 'label-default', txt = '{{ lang._("Unknown") }}';
            if (s === 'running') { cls = 'label-success'; txt = '{{ lang._("Running") }}'; }
            else if (s === 'stopped') { cls = 'label-danger'; txt = '{{ lang._("Stopped") }}'; }
            else if (s === 'disabled') { cls = 'label-default'; txt = '{{ lang._("Disabled") }}'; }
            $('#svc-badge').removeClass('label-success label-danger label-default').addClass(cls).text(txt);
        });
    }

    function loadKeys() {
        $('#keys-tbody').html('<tr><td colspan="4" class="text-center"><i class="fa fa-spinner fa-spin"></i></td></tr>');
        ajaxCall("/api/tang/keys/search", {}, function (d) {
            var rows = '';
            if (d && d.rows && d.rows.length) {
                d.rows.forEach(function (k) {
                    var badge = k.advertised
                        ? '<span class="label label-success">{{ lang._("advertised") }}</span>'
                        : '<span class="label label-default">{{ lang._("hidden") }}</span>';
                    rows += '<tr>'
                        + '<td><code>' + htmlEnc(k.thp || '') + '</code></td>'
                        + '<td>' + htmlEnc(k.alg || '') + '</td>'
                        + '<td>' + htmlEnc(k.role || '') + '</td>'
                        + '<td>' + badge + '</td>'
                        + '</tr>';
                });
            } else {
                rows = '<tr><td colspan="4" class="text-muted text-center">{{ lang._("No keys found.") }}</td></tr>';
            }
            $('#keys-tbody').html(rows);
        });
    }

    function fmtBytes(n) {
        var units = ['B', 'KB', 'MB', 'GB'], i = 0;
        n = Number(n) || 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        return (i === 0 ? n : n.toFixed(1)) + ' ' + units[i];
    }

    function loadLog() {
        var out = $('#log-content');
        var filter = $('#log-filter').val();
        ajaxGet("/api/tang/log/get", {lines: $('#log-lines').val(), filter: filter}, function (d) {
            if (!d || d.status !== 'ok') {
                out.text('{{ lang._("Could not read the log file.") }}');
                $('#log-meta').empty();
                return;
            }
            var rows = d.rows || [];
            if (!d.exists) {
                out.text('{{ lang._("The log file does not exist yet. It is created the first time the daemon writes to it.") }}');
            } else if (!rows.length) {
                out.text(filter
                    ? '{{ lang._("No lines match the filter.") }}'
                    : '{{ lang._("The log file is empty.") }}');
            } else {
                /* .text() escapes on assignment; log lines contain remote input */
                out.text(rows.map(function (r) { return r.line; }).join('\n'));
            }

            var meta = $('<span/>').text(d.logfile || '');
            if (d.exists) {
                meta.append(document.createTextNode(
                    ' \u2014 ' + fmtBytes(d.size) +
                    ' \u2014 ' + rows.length + '/' + d.matched + ' {{ lang._("lines shown") }}'
                ));
                if (d.clipped) {
                    meta.append($('<span class="text-warning"/>').text(
                        ' {{ lang._("(large file: only the most recent portion was examined)") }}'
                    ));
                }
            }
            $('#log-meta').empty().append(meta);

            /* keep the newest entries in view */
            out.scrollTop(out.prop('scrollHeight'));
        });
    }

    /* general settings */
    mapDataToFormUI({'frm_general': "/api/tang/settings/get"}).done(function () {
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
    });

    $('#btn-save').on('click', function () {
        saveFormToEndpoint("/api/tang/settings/set", 'frm_general', function () {
            showAlert('success', '{{ lang._("Settings saved, applying...") }}');
            ajaxCall("/api/tang/service/reconfigure", {}, function () {
                refreshStatus();
                loadKeys();
            });
        }, true, function () {
            showAlert('danger', '{{ lang._("Please correct the highlighted validation errors.") }}');
        });
    });

    /* service buttons */
    updateServiceControlUI('tang');

    /* key buttons */
    function keyOp(endpoint, msg) {
        ajaxCall("/api/tang/" + endpoint, {}, function (d) {
            if (d && d.status === 'ok') {
                showAlert('success', msg);
            } else {
                showAlert('danger', (d && d.response) ? htmlEnc(d.response) : '{{ lang._("Operation failed.") }}');
            }
            loadKeys();
        });
    }

    $('#btn-rotate').on('click', function () {
        if (!confirm('{{ lang._("Rotate keys? The current keys are hidden (they keep working for existing bindings) and a new pair is advertised.") }}')) return;
        keyOp('keys/rotate', '{{ lang._("Keys rotated. Re-provision clients before deleting hidden keys.") }}');
    });
    $('#btn-delhidden').on('click', function () {
        if (!confirm('{{ lang._("WARNING: deleting hidden keys is permanent. Clients still bound to them will no longer be able to recover. Continue?") }}')) return;
        keyOp('keys/delhidden', '{{ lang._("Hidden keys deleted.") }}');
    });

    /* log buttons */
    $('#btn-reloadlog').on('click', loadLog);
    $('#log-lines').on('change', loadLog);

    var filterTimer = null;
    $('#log-filter').on('keyup', function (e) {
        clearTimeout(filterTimer);
        if (e.which === 13) {
            loadLog();
        } else {
            filterTimer = setTimeout(loadLog, 400);
        }
    });

    $('#btn-clearlog').on('click', function () {
        if (!confirm('{{ lang._("Clear the log file? Its current contents are discarded permanently. The daemon keeps running and continues logging to the same file.") }}')) return;
        ajaxCall("/api/tang/log/clear", {}, function (d) {
            if (d && d.status === 'ok') {
                showAlert('success', '{{ lang._("Log file cleared.") }}');
            } else {
                showAlert('danger', (d && d.response)
                    ? htmlEnc(d.response)
                    : '{{ lang._("Could not clear the log file.") }}');
            }
            loadLog();
        });
    });

    /* only read the log once the tab is actually opened */
    $('a[data-toggle="tab"][href="#tab-log"]').on('shown.bs.tab', function () {
        loadLog();
    });

    refreshStatus();
    loadKeys();
    setInterval(refreshStatus, 10000);
});
</script>

<div id="tang-alerts"></div>

<ul class="nav nav-tabs" data-tabs="tabs">
    <li><a data-toggle="tab" href="#tab-about">{{ lang._('About') }}</a></li>
    <li class="active"><a data-toggle="tab" href="#tab-general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#tab-keys">{{ lang._('Keys') }}</a></li>
    <li><a data-toggle="tab" href="#tab-log">{{ lang._('Log') }}</a></li>
</ul>

<div class="tab-content content-box">

    <div id="tab-general" class="tab-pane fade in active">

        {{ partial('layout_partials/base_form', ['fields': generalForm, 'id': 'frm_general']) }}

        <div class="content-box" style="padding: 10px 20px;">
            <button id="btn-save" class="btn btn-primary" type="button">
                <i class="fa fa-save"></i> {{ lang._('Save') }}
            </button>
        </div>
    </div>

    <div id="tab-keys" class="tab-pane fade">
        <div class="content-box" style="padding: 10px 20px;">
            <h4>{{ lang._('Stored keys') }}</h4>
            <p class="text-muted">
                {{ lang._('Keys are stored in the firewall configuration (config.xml) and mirrored to the key directory that tangd serves. Advertised keys are offered to clients; hidden keys were rotated out and remain valid for existing Clevis bindings but are no longer advertised.') }}
            </p>
            <table class="table table-condensed table-hover">
                <thead>
                    <tr>
                        <th>{{ lang._('Thumbprint (SHA-256)') }}</th>
                        <th>{{ lang._('Algorithm') }}</th>
                        <th>{{ lang._('Role') }}</th>
                        <th>{{ lang._('State') }}</th>
                    </tr>
                </thead>
                <tbody id="keys-tbody"></tbody>
            </table>

            <hr/>

            <button id="btn-rotate" class="btn btn-warning" type="button">
                <i class="fa fa-refresh"></i> {{ lang._('Rotate keys') }}
            </button>
            <button id="btn-delhidden" class="btn btn-danger" type="button">
                <i class="fa fa-trash"></i> {{ lang._('Delete hidden keys') }}
            </button>
        </div>
    </div>

    <div id="tab-log" class="tab-pane fade">
        <div class="content-box" style="padding: 10px 20px;">
            <h4>{{ lang._('Daemon log') }}</h4>
            <p class="text-muted">
                {{ lang._('The Tang daemon appends its output to the log file named on the General tab. Lines are written as clients fetch the key advertisement and perform recovery, so this is the place to confirm that a client actually reached the server.') }}
            </p>

            <div class="form-inline" style="margin-bottom: 10px;">
                <label for="log-lines">{{ lang._('Lines') }}</label>
                <select id="log-lines" class="form-control">
                    <option value="100">100</option>
                    <option value="500" selected="selected">500</option>
                    <option value="1000">1000</option>
                    <option value="5000">5000</option>
                </select>
                <label for="log-filter" style="margin-left: 15px;">{{ lang._('Filter') }}</label>
                <input id="log-filter" type="text" class="form-control" size="30"
                       placeholder="{{ lang._('match text, e.g. an address') }}"/>
                <button id="btn-reloadlog" class="btn btn-default" type="button" style="margin-left: 15px;">
                    <i class="fa fa-refresh"></i> {{ lang._('Refresh') }}
                </button>
                <button id="btn-clearlog" class="btn btn-danger" type="button">
                    <i class="fa fa-trash"></i> {{ lang._('Clear log') }}
                </button>
            </div>

            <pre id="log-content" style="height: 480px; overflow: auto; white-space: pre-wrap; word-break: break-all;"></pre>
            <div id="log-meta" class="text-muted"></div>
        </div>
    </div>

    <div id="tab-about" class="tab-pane fade">
        <div class="content-box" style="padding: 10px 20px; max-width: 760px;">
            <h4>{{ lang._('Tang NBDE Key Server') }}</h4>
            <p>{{ lang._('Tang implements the McCallum-Relyea key exchange for Network-Bound Disk Encryption. Clevis-enabled clients can automatically unlock LUKS volumes at boot whenever they can reach this server, without storing any secret on the client.') }}</p>
            <ol>
                <li>{{ lang._('Enable the service and Save. An initial key pair is generated automatically if the key directory is empty.') }}</li>
                <li>{{ lang._('Select the interfaces allowed to reach the daemon on the General tab; the plugin restricts the Tang port to those interfaces automatically.') }}</li>
                <li>{{ lang._('Bind a client: clevis luks bind -d /dev/sdX tang \'{"url":"http://this-firewall:9090"}\'.') }}</li>
                <li>{{ lang._('To rotate, click Rotate keys, re-provision every client against the new keys, then delete the hidden keys.') }}</li>
            </ol>
            <p>{{ lang._('Keys are stored in config.xml, so they are included in configuration backups and are replicated to High Availability peers automatically. Because config.xml then contains private key material, protect your configuration backups accordingly.') }}</p>
            <p>
                <a href="https://github.com/latchset/tang" target="_blank" class="btn btn-xs btn-default">Tang</a>
                <a href="https://github.com/latchset/clevis" target="_blank" class="btn btn-xs btn-default">Clevis</a>
            </p>
        </div>
    </div>

</div>
