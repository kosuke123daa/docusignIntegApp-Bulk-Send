public with sharing class UploadAgreementToNavigatorAction {

    public class Request {
        @InvocableVariable(required=true label='レコードID' description='ドキュメントを紐付けるSalesforceレコードのID（商談・取引先など）')
        public String recordId;

        @InvocableVariable(required=true label='コンテンツドキュメントID' description='アップロードするファイルのSalesforce ContentDocument ID。GetRecordAttachmentsActionで取得できる')
        public String contentDocumentId;
    }

    public class Response {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='アップロード結果を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='ジョブID' description='Navigator Bulk Upload JobのジョブID')
        public String jobId;
        @InvocableVariable(label='ドキュメントID' description='Navigator上で割り当てられたドキュメントID')
        public String documentId;
    }

    @InvocableMethod(
        label='Navigatorへドキュメントをアップロード'
        description='Salesforceレコードの添付ファイルをDocuSign Navigatorの合意書リポジトリにアップロードし、レコードと紐付ける（linked_data）。アップロード後はSalesforce標準のDocusign Completed Agreementsコンポーネントに表示される。対象ファイルのContentDocumentIDはGetRecordAttachmentsActionで事前に取得すること。'
        category='DocuSign'
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response resp = new Response();
            resp.success = false;
            resp.message = '未実行';
            try {
                Id recId = Id.valueOf(req.recordId);
                String objectName = recId.getSObjectType().getDescribe().getName();

                ContentDocument doc = [SELECT Title FROM ContentDocument WHERE Id = :req.contentDocumentId LIMIT 1];

                NavigatorAgreementUploadService.UploadResult result =
                    NavigatorAgreementUploadService.uploadAgreement(req.contentDocumentId, objectName, req.recordId);

                resp.jobId      = result.jobId;
                resp.documentId = result.documentId;
                resp.message    = '「' + doc.Title + '」をNavigatorにアップロードしました。ジョブID: ' + result.jobId;
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
