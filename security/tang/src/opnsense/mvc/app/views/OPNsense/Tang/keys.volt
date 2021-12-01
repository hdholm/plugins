{#

Copyright (C) 2021 Howard Holm <hdholm@alumni.iastate.edu>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
RISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

#}

<script type="text/javascript">
    $( document ).ready(function() {
        var data_get_map = {'frm_GeneralSettings':"/api/tang/settings/get"};
        mapDataToFormUI(data_get_map).done(function(data){
            // place actions to run after load, for example update form styles.
        });

        // link rekey button to API rekey action
        $("#rekeyAct").click(function(){
          $("#responseMsg").removeClass("hidden");
            ajaxCall(url="/api/tang/service/rekey", sendData={},callback=function(data,status) {
                // action to run after reload
               $("#responseMsg").html(data['message']);
            });
        });

    });
</script>

<div class="alert alert-info hidden" role="alert" id="responseMsg">

</div>

{# Need to find a way to coherrently list keys and allow for deletion of the key files.
   Complicated by the each rekey providing two files, and tang-show-keys only presenting
   the identity of the currently advertised key which maps to one of those files.
#}
<div  class="col-md-12">
    <h2>Currently advertised key</h2>
    {# Need to grab output from tang-show-keys here somehow but only if tangd running #}
    <p>
    {{ lang._('You can rekey the tang server with the Rekey button below.  This will add new keys
    but will not automaticaly remove the old keys to give you the opportunity to make sure all clients
    using this service have updated to new keys.') }}
    </p>

</div>

<div class="col-md-12">
    <button class="btn btn-primary"  id="rekeyAct" type="button"><b>{{ lang._('Rekey') }}</b></button>
</div>
