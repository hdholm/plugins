<script>
    $( document ).ready(function() {
        let grid_vs = $("#grid-virtual-servers").UIBootgrid({
            search:'/api/apache/gateway/search_virtual_server/',
            get:'/api/apache/gateway/get_virtual_server/',
            set:'/api/apache/gateway/set_virtual_server/',
            add:'/api/apache/gateway/add_virtual_server/',
            del:'/api/apache/gateway/del_virtual_server/',
            toggle:'/api/apache/gateway/toggle_virtual_server/'
        });

        $("#reconfigureAct").SimpleActionButton();
    });
</script>


<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#virtualservers">{{ lang._('VirtualServers') }}</a></li>
</ul>
<div class="tab-content content-box">
    <div id="virtualservers" class="tab-pane fade in active">
        <!-- tab page "virtualservers" -->
        <table id="grid-virtual-servers" class="table table-condensed table-hover table-striped" data-editDialog="DialogVirtualServer" data-editAlert="VirtualServersChangeMessage">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true"  data-visible="false">{{ lang._('ID') }}</th>
                    <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('Enabled') }}</th>
                    <th data-column-id="description" data-type="string">{{ lang._('Description') }}</th>
                    <th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                </tr>
            </thead>
            <tbody>
            </tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
        <div class="col-md-12">
            <div id="VirtualServersChangeMessage" class="alert alert-info" style="display: none" role="alert">
                {{ lang._('After changing settings, please remember to apply them with the button below') }}
            </div>
            <hr/>
            <button class="btn btn-primary" id="reconfigureAct"
                    data-endpoint='/api/apache/service/reconfigure'
                    data-label="{{ lang._('Apply') }}"
                    data-error-title="{{ lang._('Configure error') }}"
                    type="button"
            ></button>
            <br/><br/>
        </div>
    </div>
</div>

{{ partial("layout_partials/base_dialog",['fields':formDialogVirtualServer,'id':'DialogVirtualServer','label':lang._('Edit VirtualServer')])}}
