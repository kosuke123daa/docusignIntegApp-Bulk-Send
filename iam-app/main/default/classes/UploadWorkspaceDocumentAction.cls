public with sharing class UploadWorkspaceDocumentAction {

    public class Request {
        @InvocableVariable(required=true label='商談ID' description='ドキュメントをアップロードするワークスペースの商談ID')
        public String opportunityId;

        @InvocableVariable(required=true label='コンテンツドキュメントID' description='アップロードするファイルのSalesforce ContentDocument ID。GetRecordAttachmentsActionで取得できる')
        public String contentDocumentId;
    }

    public class Response {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='アップロード結果を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='ドキュメントID' description='DocuSignワークスペース上で割り当てられたドキュメントID')
        public String documentId;
    }

    @InvocableMethod(
        label='ワークスペースへドキュメントをアップロード'
        description='商談の添付ファイルをDocuSignワークスペースにアップロードする。「〇〇のファイルをワークスペースにアップロードして」「書類をDocuSignに送って」などの指示に対応。対象ファイルのContentDocumentIDはGetRecordAttachmentsActionで事前に取得すること。'
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

                // Fetch file title for the result message before uploading
                ContentDocument doc = [SELECT Title FROM ContentDocument WHERE Id = :req.contentDocumentId LIMIT 1];

                Map<String, Object> result = WorkspaceService.uploadDocument(wsId, req.contentDocumentId);
                String docId = result.get('document_id') != null ? String.valueOf(result.get('document_id')) : '';

                resp.documentId = docId;
                resp.message    = '「' + doc.Title + '」をワークスペースにアップロードしました。ドキュメントID: ' + docId;
                resp.success    = true;

            } catch (Exception e) {
                resp.success = false;
                resp.message = '例外: ' + e.getTypeName() + ' - ' + e.getMessage();
            }
            results.add(resp);
        }
        return results;
    }
}
