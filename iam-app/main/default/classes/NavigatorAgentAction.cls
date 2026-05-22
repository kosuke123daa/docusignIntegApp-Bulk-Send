public with sharing class NavigatorAgentAction {

    public class NavigatorRequest {
        @InvocableVariable(required=false label='Agreement ID' description='特定の文書詳細取得またはAI要約生成を行う場合の文書ID。一覧取得時は不要')
        public String agreementId;

        @InvocableVariable(required=false label='AI要約を生成' description='trueにすると指定文書のAI要約を生成する。agreementIdと必ず併用すること')
        public Boolean generateSummary;

        @InvocableVariable(required=false label='ステータス' description='ステータスで絞り込む。COMPLETE（完了）/ PENDING（処理中）/ INACTIVE（無効）')
        public String status;

        @InvocableVariable(required=false label='取引先名' description='契約書上の取引先・企業名で絞り込む。例: 株式会社XX、XX Corp')
        public String partyName;

        @InvocableVariable(required=false label='文書種別' description='文書種別で絞り込む。例: Non-disclosure Agreement / Master Service Agreement / Statement of Work / Purchase Order')
        public String documentType;

        @InvocableVariable(required=false label='タイトル' description='文書タイトルで絞り込む')
        public String title;

        @InvocableVariable(required=false label='満了日（開始）' description='この日付以降に満了する文書を絞り込む。YYYY-MM-DD形式。例: 来月期限切れの契約書を調べる場合の開始日')
        public String expirationDateFrom;

        @InvocableVariable(required=false label='満了日（終了）' description='この日付以前に満了する文書を絞り込む。YYYY-MM-DD形式')
        public String expirationDateTo;

        @InvocableVariable(required=false label='有効日（開始）' description='この日付以降に有効になる文書を絞り込む。YYYY-MM-DD形式')
        public String effectiveDateFrom;

        @InvocableVariable(required=false label='有効日（終了）' description='この日付以前に有効になる文書を絞り込む。YYYY-MM-DD形式')
        public String effectiveDateTo;

        @InvocableVariable(required=false label='取込元' description='文書の取込元で絞り込む。例: Docusign eSign / CLM')
        public String sourceName;

        @InvocableVariable(required=false label='最大件数' description='取得する最大件数。デフォルトは20')
        public Integer maxResults;
    }

    public class NavigatorResponse {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='取得した文書の一覧または詳細情報を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='文書一覧JSON' description='Navigator APIから返却された生のJSONデータ。詳細な属性値の参照に使用する')
        public String documentListJson;
        @InvocableVariable(label='文書数' description='取得できた文書の件数')
        public Integer documentCount;
        @InvocableVariable(label='先頭文書ID' description='一覧取得時の先頭文書のID。続けて詳細取得やAI要約を行う場合にagreementIdとして使用する')
        public String firstAgreementId;
        @InvocableVariable(label='AI要約' description='AI要約生成モード時に返却される文書の要約テキスト')
        public String summary;
    }

    @InvocableMethod(
        label='Navigator文書を検索・取得'
        description='DocuSign Navigator APIから合意文書を検索・取得する専用アクション。「XX社の契約書を教えて」「来月期限の契約書は？」「NDA一覧を見せて」「この契約書の詳細は？」「この契約書を要約して」などの質問に対応。必ずこのアクションを使うこと。標準のレコード検索アクションは使わないこと。'
        category='DocuSign'
    )
    public static List<NavigatorResponse> execute(List<NavigatorRequest> requests) {
        List<NavigatorResponse> results = new List<NavigatorResponse>();
        for (NavigatorRequest reqItem : requests) {
            NavigatorResponse resp = new NavigatorResponse();
            resp.success          = false;
            resp.message          = '未実行';
            resp.documentListJson = '';
            resp.documentCount    = 0;
            resp.firstAgreementId = '';
            resp.summary          = '';
            try {
                NavigatorService.Config cfg = NavigatorService.loadConfig();
                String accessToken          = NavigatorService.getAccessToken(cfg);
                String baseUrl              = NavigatorService.getAgreementsBaseUrl(cfg.accountId);

                Boolean hasId = reqItem != null && String.isNotBlank(reqItem.agreementId);

                if (hasId && reqItem.generateSummary == true) {
                    handleSummary(resp, baseUrl, reqItem.agreementId, accessToken);
                } else if (hasId) {
                    handleGetDetail(resp, baseUrl, reqItem.agreementId, accessToken);
                } else {
                    handleGetList(resp, baseUrl, reqItem, accessToken);
                }

            } catch (Exception e) {
                resp.success  = false;
                resp.message  = '例外: ' + e.getTypeName() + ' - ' + e.getMessage();
            }
            results.add(resp);
        }
        return results;
    }

    // ── AI要約生成 ───────────────────────────────────────────────────────────

    private static void handleSummary(NavigatorResponse resp, String baseUrl, String agreementId, String accessToken) {
        HttpResponse res = NavigatorService.callPost(
            baseUrl + '/' + agreementId + '/ai/actions/summarize', accessToken, '{}'
        );
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            resp.message = 'AI要約生成失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody();
            return;
        }

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String summaryText = resMap.containsKey('summary')
            ? String.valueOf(resMap.get('summary'))
            : res.getBody();

        resp.summary          = summaryText;
        resp.documentListJson = res.getBody();
        resp.documentCount    = 1;
        resp.firstAgreementId = agreementId;
        resp.message          = 'AI要約:\n' + summaryText;
        resp.success          = true;
    }

    // ── 特定文書の詳細取得 ────────────────────────────────────────────────────

    private static void handleGetDetail(NavigatorResponse resp, String baseUrl, String agreementId, String accessToken) {
        HttpResponse res = NavigatorService.callGet(baseUrl + '/' + agreementId, accessToken);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            resp.message = 'Navigator API 失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody();
            return;
        }

        Map<String, Object> doc = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        resp.documentListJson = res.getBody();
        resp.documentCount    = 1;
        resp.firstAgreementId = agreementId;
        resp.message          = buildDetailMessage(doc);
        resp.success          = true;
    }

    // ── 一覧取得（フィルター付き） ─────────────────────────────────────────────

    private static void handleGetList(NavigatorResponse resp, String baseUrl, NavigatorRequest req, String accessToken) {
        NavigatorService.ListParams lp = new NavigatorService.ListParams();
        if (req != null) {
            lp.status             = req.status;
            lp.partyName          = req.partyName;
            lp.documentType       = req.documentType;
            lp.title              = req.title;
            lp.expirationDateFrom = req.expirationDateFrom;
            lp.expirationDateTo   = req.expirationDateTo;
            lp.effectiveDateFrom  = req.effectiveDateFrom;
            lp.effectiveDateTo    = req.effectiveDateTo;
            lp.sourceName         = req.sourceName;
            lp.maxResults         = req.maxResults;
        }

        String url          = NavigatorService.buildListUrl(baseUrl, lp);
        HttpResponse navRes = NavigatorService.callGet(url, accessToken);
        if (navRes.getStatusCode() < 200 || navRes.getStatusCode() >= 300) {
            resp.message = 'Navigator API 失敗: HTTP ' + navRes.getStatusCode() + ' ' + navRes.getBody();
            return;
        }

        Map<String, Object> navMap = (Map<String, Object>) JSON.deserializeUntyped(navRes.getBody());
        List<Object> dataList      = navMap.containsKey('data')
            ? (List<Object>) navMap.get('data')
            : new List<Object>();
        Integer count = dataList.size();

        resp.documentListJson = navRes.getBody();
        resp.documentCount    = count;

        if (count == 0) {
            resp.message = '条件に一致する文書は見つかりませんでした。';
            resp.success  = true;
            return;
        }

        List<String> lines = new List<String>{ count + '件の文書が見つかりました。' };
        Integer idx = 1;
        for (Object obj : dataList) {
            if (!(obj instanceof Map<String, Object>)) continue;
            Map<String, Object> doc = (Map<String, Object>) obj;

            if (idx == 1 && doc.containsKey('id') && doc.get('id') != null) {
                resp.firstAgreementId = String.valueOf(doc.get('id'));
            }

            String docId     = doc.containsKey('id')     && doc.get('id')     != null ? String.valueOf(doc.get('id'))     : '';
            String docTitle  = doc.containsKey('title')  && doc.get('title')  != null ? String.valueOf(doc.get('title'))  : '（タイトルなし）';
            String docType   = doc.containsKey('type')   && doc.get('type')   != null ? String.valueOf(doc.get('type'))   : '';
            String docStatus = doc.containsKey('status') && doc.get('status') != null ? String.valueOf(doc.get('status')) : '';
            String expDate   = '不明';
            String party     = '';

            if (doc.containsKey('provisions') && doc.get('provisions') instanceof Map<String, Object>) {
                Map<String, Object> prov = (Map<String, Object>) doc.get('provisions');
                if (prov.containsKey('expiration_date') && prov.get('expiration_date') != null) {
                    expDate = String.valueOf(prov.get('expiration_date'));
                }
            }
            if (doc.containsKey('parties') && doc.get('parties') instanceof List<Object>) {
                List<Object> parties    = (List<Object>) doc.get('parties');
                List<String> partyNames = new List<String>();
                for (Object p : parties) {
                    if (p instanceof Map<String, Object>) {
                        Map<String, Object> pm = (Map<String, Object>) p;
                        if (pm.containsKey('name_in_agreement') && pm.get('name_in_agreement') != null) {
                            partyNames.add(String.valueOf(pm.get('name_in_agreement')));
                        }
                    }
                }
                if (!partyNames.isEmpty()) party = String.join(partyNames, ' / ');
            }

            lines.add(idx + '. [' + docId + '] ' + docTitle
                + '\n   種別:' + docType + ' / ステータス:' + docStatus
                + ' / 満了日:' + expDate + ' / 取引先:' + party);
            idx++;
        }

        resp.message = String.join(lines, '\n');
        resp.success  = true;
    }

    // ── 詳細メッセージ生成 ────────────────────────────────────────────────────

    private static String buildDetailMessage(Map<String, Object> doc) {
        List<String> lines = new List<String>{ '【文書詳細】' };

        appendField(lines, 'タイトル',   doc, 'title');
        appendField(lines, '種別',       doc, 'type');
        appendField(lines, 'カテゴリ',   doc, 'category');
        appendField(lines, 'ステータス', doc, 'status');
        appendField(lines, '取込元',     doc, 'source_name');

        if (doc.containsKey('summary') && doc.get('summary') != null) {
            lines.add('概要: ' + String.valueOf(doc.get('summary')));
        }

        if (doc.containsKey('parties') && doc.get('parties') instanceof List<Object>) {
            List<String> names = new List<String>();
            for (Object p : (List<Object>) doc.get('parties')) {
                if (p instanceof Map<String, Object>) {
                    Map<String, Object> pm = (Map<String, Object>) p;
                    if (pm.containsKey('name_in_agreement') && pm.get('name_in_agreement') != null) {
                        names.add(String.valueOf(pm.get('name_in_agreement')));
                    }
                }
            }
            if (!names.isEmpty()) lines.add('当事者: ' + String.join(names, ' / '));
        }

        if (doc.containsKey('provisions') && doc.get('provisions') instanceof Map<String, Object>) {
            Map<String, Object> prov = (Map<String, Object>) doc.get('provisions');
            lines.add('--- 主要条項 ---');
            appendField(lines, '有効日',       prov, 'effective_date');
            appendField(lines, '満了日',       prov, 'expiration_date');
            appendField(lines, '締結日',       prov, 'execution_date');
            appendField(lines, '契約期間',     prov, 'term_length');
            appendField(lines, '契約総額',     prov, 'total_agreement_value');
            appendField(lines, '年間契約額',   prov, 'annual_agreement_value');
            appendField(lines, '更新タイプ',   prov, 'renewal_type');
            appendField(lines, '更新通知日',   prov, 'renewal_notice_date');
            appendField(lines, '更新通知期間', prov, 'renewal_notice_period');
            appendField(lines, '自動更新期間', prov, 'auto_renewal_term_length');
            appendField(lines, '準拠法',       prov, 'governing_law');
            appendField(lines, '裁判管轄',     prov, 'jurisdiction');
            appendField(lines, '支払期限',     prov, 'payment_terms_due_date');
            appendField(lines, '責任制限額',   prov, 'liability_cap_fixed_amount');
            appendField(lines, '譲渡タイプ',   prov, 'assignment_type');
            appendField(lines, '有因解除期間', prov, 'termination_period_for_cause');
            appendField(lines, '便宜解除期間', prov, 'termination_period_for_convenience');
        }

        if (doc.containsKey('id') && doc.get('id') != null) {
            lines.add('---');
            lines.add('文書ID: ' + String.valueOf(doc.get('id')));
        }

        return String.join(lines, '\n');
    }

    private static void appendField(List<String> lines, String label, Map<String, Object> m, String key) {
        if (m.containsKey(key) && m.get(key) != null) {
            String val = String.valueOf(m.get(key));
            if (String.isNotBlank(val) && val != 'null') {
                lines.add(label + ': ' + val);
            }
        }
    }
}
