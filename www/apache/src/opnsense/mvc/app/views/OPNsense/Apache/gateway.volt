<script>
    $( document ).ready(function() {
        let grid_vs = $("#grid-virtual-servers").UIBootgrid({
            search:'/api/apache/gateway/search_virtual_server/',
            get:'/api/apache/gateway/get_virtual_server/',
            set:'/api/apache/gateway/set_virtual_server/',
            add:'/api/apache/gateway/add_virtual_server/',
            del:'/api/apache/gateway/del_virtual_server/',
            toggle:'/api/apache/gateway/toggle_virtual_server/',
            options:{
                selection: true,
                multiSelect: false,
                rowSelect: true,
                rowCount: [3,7,14,20,50,100,-1]
            }
        }).on("selected.rs.jquery.bootgrid", function(e, rows) {
            $("#grid-locations").bootgrid('reload');
        }).on("deselected.rs.jquery.bootgrid", function(e, rows) {
            $("#grid-locations").bootgrid('reload');
        }).on("loaded.rs.jquery.bootgrid", function (e) {
            let ids = $("#grid-virtual-servers").bootgrid("getCurrentRows");
            if (ids.length > 0) {
                $("#grid-virtual-servers").bootgrid('select', [ids[0].uuid]);
            }
        });

        let grid_locations = $("#grid-locations").UIBootgrid({
            search:'/api/apache/gateway/search_location/',
            get:'/api/apache/gateway/get_location/',
            set:'/api/apache/gateway/set_location/',
            add:'/api/apache/gateway/add_location/',
            del:'/api/apache/gateway/del_location/',
            toggle:'/api/apache/gateway/toggle_location/',
            options:{
                useRequestHandlerOnGet: true,
                requestHandler: function(request) {
                    let ids = $("#grid-virtual-servers").bootgrid("getSelectedRows");
                    request['virtualserver'] = ids.length > 0 ? ids[0] : "__not_found__";
                    if (ids.length > 0) {
                        $(".vs_selected").show();
                    } else {
                        $(".vs_selected").hide();
                    }
                    return request;
                }
            }
        });

        /* a bit of trickery to add heading texts */
        $("div.actionBar").each(function(){
            let heading_text = "";
            if ($(this).closest(".bootgrid-header").attr("id").includes("location")) {
                heading_text = "{{ lang._('Locations') }}";
            } else {
                heading_text = "{{ lang._('Virtual servers') }}";
            }
            $(this).parent().prepend($('<td class="col-sm-2 theading-text">'+heading_text+'</div>'));
            $(this).removeClass("col-sm-12");
            $(this).addClass("col-sm-10");
        });

        $("#reconfigureAct").SimpleActionButton();
    });
</script>
<style>
    .theading-text {
        font-weight: 800;
        font-style: italic;
    }
</style>
<!-- "virtualservers" -->
<div class="tab-content content-box col-xs-12 __mb">
    <table id="grid-virtual-servers" class="table table-condensed table-hover table-striped" data-editDialog="DialogVirtualServer" data-editAlert="GatewayChangeMessage">
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
</div>
<!-- "locations" -->
<div class="tab-content content-box col-xs-12 __mb">
    <table id="grid-locations" class="table table-condensed table-hover table-striped" data-editDialog="DialogLocation" data-editAlert="GatewayChangeMessage">
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
        <tfoot class="vs_selected">
        <tr>
            <td></td>
            <td>
                <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
            </td>
        </tr>
        </tfoot>
    </table>
</div>
<!-- "reconfigure" -->
<div class="tab-content content-box col-xs-12 __mb">
    <div id="GatewayChangeMessage" class="alert alert-info" style="display: none" role="alert">
        {{ lang._('After changing settings, please remember to apply them with the button below') }}
    </div>
    <table class="table table-condensed">
        <tbody>
        <tr>
            <td>
                <button class="btn btn-primary" id="reconfigureAct"
                        data-endpoint='/api/apache/service/reconfigure'
                        data-label="{{ lang._('Apply') }}"
                        data-error-title="{{ lang._('Configure error') }}"
                        type="button"
                ></button>
            </td>
        </tr>
        </tbody>
    </table>
</div>

{{ partial("layout_partials/base_dialog",['fields':formDialogVirtualServer,'id':'DialogVirtualServer','label':lang._('Edit VirtualServer')])}}
{{ partial("layout_partials/base_dialog",['fields':formDialogLocation,'id':'DialogLocation','label':lang._('Edit Location')])}}
