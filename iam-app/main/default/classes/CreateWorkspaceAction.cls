public with sharing class CreateWorkspaceAction {

    public class Request {
        @InvocableVariable(required=true label='商談ID' description='ワークスペースを作成する商談のSalesforce ID')
        public String opportunityId;

        @InvocableVariable(required=false label='ワークスペース名' description='作成するワークスペースの名前。省略した場合は商談名が使用される')
        public String workspaceName;
    }

    public class Response {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='作成結果を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='ワークスペースID' description='作成または既存のワークスペースの数値ID')
        public String workspaceId;
        @InvocableVariable(label='ワークスペースURL' description='DocuSign上のワークスペースURL')
        public String workspaceUrl;
    }

    @InvocableMethod(
        label='ワークスペース作成'
        description='商談に紐づくDocuSignワークスペースを作成する。すでに存在する場合は既存のワークスペース情報を返す。「ワークスペースを作って」「DocuSignのワークスペースを準備して」「書類管理スペースを作成して」などの指示に対応。'
        category='DocuSign'
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response resp = new Response();
            resp.success = false;
            resp.message = '未実行';
            try {
                Opportunity opp = [SELECT DocuSign_Workspace_Id__c, Name FROM Opportunity WHERE Id = :req.opportunityId LIMIT 1];

                if (String.isNotBlank(opp.DocuSign_Workspace_Id__c)) {
                    resp.workspaceId  = opp.DocuSign_Workspace_Id__c;
                    resp.workspaceUrl = 'https://apps-d.docusign.com/workspaces/' + opp.DocuSign_Workspace_Id__c;
                    resp.message      = '商談「' + opp.Name + '」のワークスペースはすでに存在します。ワークスペースID: ' + opp.DocuSign_Workspace_Id__c;
                    resp.success      = true;
                    results.add(resp);
                    continue;
                }

                String wsName = String.isNotBlank(req.workspaceName) ? req.workspaceName : opp.Name;
                Map<String, Object> result = WorkspaceService.createWorkspace(wsName);

                String wsId  = (String) result.get('display_id');
                String wsUrl = (String) result.get('workspace_url');

                opp.DocuSign_Workspace_Id__c = wsId;
                update opp;

                resp.workspaceId  = wsId;
                resp.workspaceUrl = wsUrl;
                resp.message      = '商談「' + opp.Name + '」のワークスペース「' + wsName + '」を作成しました。ワークスペースID: ' + wsId + ' / URL: ' + wsUrl;
                resp.success      = true;

            } catch (Exception e) {
                resp.success = false;
                resp.message = '例外: ' + e.getTypeName() + ' - ' + e.getMessage();
            }
            results.add(resp);
        }
        return results;
    }
}
