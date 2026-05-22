public with sharing class CreateWorkspaceUploadRequestAction {

    public class Request {
        @InvocableVariable(required=true label='商談ID' description='アップロードリクエストを作成するワークスペースの商談ID')
        public String opportunityId;

        @InvocableVariable(required=true label='リクエスト名' description='アップロードリクエストの名前（例: 見積書、契約書、身分証明書）')
        public String name;

        @InvocableVariable(required=false label='説明' description='アップロードリクエストの詳細説明')
        public String description;

        @InvocableVariable(required=false label='期日' description='書類提出期日（YYYY-MM-DD形式）。省略した場合は30日後が自動設定される')
        public String dueDate;

        @InvocableVariable(required=false label='担当者メールアドレス' description='書類提出を依頼するユーザーのメールアドレス')
        public String assigneeEmail;

        @InvocableVariable(required=false label='担当者名（名）' description='担当者のファーストネーム')
        public String assigneeFirstName;

        @InvocableVariable(required=false label='担当者名（姓）' description='担当者のラストネーム')
        public String assigneeLastName;
    }

    public class Response {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='作成結果を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='アップロードリクエストID' description='作成されたアップロードリクエストのID')
        public String uploadRequestId;
    }

    @InvocableMethod(
        label='アップロードリクエスト作成'
        description='DocuSignワークスペースにアップロードリクエスト（書類提出依頼）を作成する。「書類を依頼して」「アップロードリクエストを作って」「〇〇さんに書類を提出してもらって」「見積書をアップロードするよう依頼して」などの指示に対応。'
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
                String wsId = opp.DocuSign_Workspace_Id__c;
                if (String.isBlank(wsId)) {
                    resp.message = '商談「' + opp.Name + '」にはワークスペースが作成されていません。先にワークスペースを作成してください。';
                    results.add(resp);
                    continue;
                }

                List<Map<String, String>> assignees = new List<Map<String, String>>();
                if (String.isNotBlank(req.assigneeEmail)) {
                    assignees.add(new Map<String, String>{
                        'email'     => req.assigneeEmail,
                        'firstName' => req.assigneeFirstName != null ? req.assigneeFirstName : '',
                        'lastName'  => req.assigneeLastName  != null ? req.assigneeLastName  : ''
                    });
                }

                Map<String, Object> result = WorkspaceService.createUploadRequest(
                    wsId, req.name, req.description, req.dueDate, assignees
                );
                String reqId = result.get('upload_request_id') != null ? String.valueOf(result.get('upload_request_id')) : '';

                resp.uploadRequestId = reqId;
                resp.message = 'アップロードリクエスト「' + req.name + '」を作成しました。ID: ' + reqId
                    + (String.isNotBlank(req.assigneeEmail) ? ' / 担当者: ' + req.assigneeEmail : '');
                resp.success = true;

            } catch (Exception e) {
                resp.success = false;
                resp.message = '例外: ' + e.getTypeName() + ' - ' + e.getMessage();
            }
            results.add(resp);
        }
        return results;
    }
}
