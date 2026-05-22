public with sharing class GetEnvelopesAction {

    private static final String ENVELOPE_BASE_URL = 'https://apps-d.docusign.com/send/documents/details/';

    public class EnvelopeRequest {
        @InvocableVariable(required=true label='商談ID' description='エンベロープを検索する商談のSalesforceレコードID')
        public String opportunityId;
    }

    public class EnvelopeResponse {
        @InvocableVariable(label='成功フラグ' description='処理が成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='エンベロープ一覧を日本語でまとめたテキスト。ステータス・件名・最終更新日・完了日・詳細URLを含む。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='件数' description='取得できたエンベロープの件数')
        public Integer envelopeCount;
        @InvocableVariable(label='先頭エンベロープID' description='一覧の先頭（最新）エンベロープのDocuSign ID')
        public String firstEnvelopeId;
        @InvocableVariable(label='先頭エンベロープURL' description='一覧の先頭（最新）エンベロープの詳細画面URL')
        public String firstEnvelopeUrl;
        @InvocableVariable(label='エンベロープ一覧JSON' description='全エンベロープの情報（ID・ステータス・件名・日付・URL）をJSON形式で返す')
        public String envelopeListJson;
    }

    @InvocableMethod(
        label='DocuSignエンベロープ一覧を取得'
        description='指定した商談に紐づくDocuSignエンベロープの一覧と詳細画面URLを返す。「この商談のエンベロープを教えて」「署名状況を確認して」「DocuSignのリンクを教えて」などの質問に対応。'
        category='DocuSign'
    )
    public static List<EnvelopeResponse> getEnvelopes(List<EnvelopeRequest> requests) {
        List<EnvelopeResponse> results = new List<EnvelopeResponse>();

        for (EnvelopeRequest req : requests) {
            EnvelopeResponse resp = new EnvelopeResponse();
            resp.success          = false;
            resp.envelopeCount    = 0;
            resp.firstEnvelopeId  = '';
            resp.firstEnvelopeUrl = '';
            resp.envelopeListJson = '[]';

            try {
                if (String.isBlank(req.opportunityId)) {
                    resp.message = '商談IDが指定されていません。';
                    results.add(resp);
                    continue;
                }

                // ① dfsle__Envelope__c.dfsle__SourceId__c で商談に紐づくエンベロープを取得
                List<dfsle__Envelope__c> envelopes = [
                    SELECT dfsle__DocuSignId__c, dfsle__EmailSubject__c
                    FROM dfsle__Envelope__c
                    WHERE dfsle__SourceId__c = :req.opportunityId
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];

                if (envelopes.isEmpty()) {
                    resp.message = 'この商談に紐づくエンベロープは見つかりませんでした。';
                    resp.success = true;
                    results.add(resp);
                    continue;
                }

                // ② DocuSign GUID をキーに dfsle__EnvelopeStatus__c からステータスを取得
                Set<String> guids = new Set<String>();
                for (dfsle__Envelope__c env : envelopes) {
                    if (String.isNotBlank(env.dfsle__DocuSignId__c)) {
                        guids.add(env.dfsle__DocuSignId__c);
                    }
                }

                Map<String, dfsle__EnvelopeStatus__c> statusMap = new Map<String, dfsle__EnvelopeStatus__c>();
                for (dfsle__EnvelopeStatus__c es : [
                    SELECT dfsle__DocuSignId__c, dfsle__Status__c, dfsle__EmailSubject__c,
                           dfsle__LastStatusUpdate__c, dfsle__Completed__c, dfsle__SenderName__c
                    FROM dfsle__EnvelopeStatus__c
                    WHERE dfsle__DocuSignId__c IN :guids
                ]) {
                    statusMap.put(es.dfsle__DocuSignId__c, es);
                }

                // ③ 両オブジェクトの情報を合わせてレスポンスを構築
                List<Map<String, Object>> envelopeList = new List<Map<String, Object>>();
                List<String> lines = new List<String>{ envelopes.size() + '件のエンベロープが見つかりました。' };
                Integer idx = 1;

                for (dfsle__Envelope__c env : envelopes) {
                    String envelopeId = String.valueOf(env.dfsle__DocuSignId__c);
                    String url        = ENVELOPE_BASE_URL + envelopeId;

                    dfsle__EnvelopeStatus__c es = statusMap.get(envelopeId);
                    String status        = es != null && es.dfsle__Status__c           != null ? es.dfsle__Status__c                                 : '（未取得）';
                    String subject       = es != null && es.dfsle__EmailSubject__c     != null ? es.dfsle__EmailSubject__c
                                        : (env.dfsle__EmailSubject__c                  != null ? env.dfsle__EmailSubject__c                          : '（件名なし）');
                    String lastUpdate    = es != null && es.dfsle__LastStatusUpdate__c != null ? String.valueOf(es.dfsle__LastStatusUpdate__c.date()) : '-';
                    String completedDate = es != null && es.dfsle__Completed__c        != null ? String.valueOf(es.dfsle__Completed__c.date())        : '-';
                    String senderName    = es != null && es.dfsle__SenderName__c       != null ? es.dfsle__SenderName__c                             : '';

                    if (idx == 1) {
                        resp.firstEnvelopeId  = envelopeId;
                        resp.firstEnvelopeUrl = url;
                    }

                    lines.add(idx + '. ' + subject
                        + '\n   ステータス: ' + status
                        + ' / 最終更新: ' + lastUpdate
                        + ' / 完了日: ' + completedDate
                        + (String.isNotBlank(senderName) ? ' / 送信者: ' + senderName : '')
                        + '\n   詳細URL: ' + url);

                    envelopeList.add(new Map<String, Object>{
                        'envelopeId'    => envelopeId,
                        'status'        => status,
                        'subject'       => subject,
                        'lastUpdate'    => lastUpdate,
                        'completedDate' => completedDate,
                        'senderName'    => senderName,
                        'url'           => url
                    });
                    idx++;
                }

                resp.message          = String.join(lines, '\n');
                resp.envelopeCount    = envelopes.size();
                resp.envelopeListJson = JSON.serialize(envelopeList);
                resp.success          = true;

            } catch (Exception e) {
                resp.success = false;
                resp.message = '例外: ' + e.getTypeName() + ' - ' + e.getMessage();
            }

            results.add(resp);
        }

        return results;
    }
}
