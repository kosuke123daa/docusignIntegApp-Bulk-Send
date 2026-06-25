/**
 * Opportunity 等のレコードページから DocuSign Agreement Manager(Navigator) を扱うコントローラ。
 *
 * 認証・JWT(PKCS#1→PKCS#8変換含む)・callout は既存の NavigatorService を流用する。
 *  - getAgreementsForRecord : レコードに linked_data で紐づく Agreement を一覧取得
 *  - uploadDocumentForRecord : 文書を bulk ingestion でアップロードし linked_data で紐付け
 *
 * 一覧は既定スコープ(adm_store_unified_repo_read)で動作する。
 * アップロードは書き込みスコープ(adm_store_unified_repo_write)の consent と、
 * プリサインドURL(Azure Blob)ホストの Remote Site Settings 登録が前提。
 */
public with sharing class RecordAgreementsController {

    /**
     * 開いているレコードに紐づく Agreement を JSON ({ "data": [...] }) で返す。
     * 返却形は navigatorExplorer と同じ data[] 配列なので、LWC 側で同様に整形できる。
     */
    @AuraEnabled(cacheable=false)
    public static String getAgreementsForRecord(String recordId) {
        try {
            NavigatorService.Config cfg = NavigatorService.loadConfig();
            String token = NavigatorService.getAccessToken(cfg);

            String url = 'callout:DocuSign_Navigator/v1/accounts/' + cfg.accountId
                + '/agreements?include_linked_data=true&limit=100';

            HttpResponse res = NavigatorService.callGet(url, token);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'Navigator API エラー: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
            }

            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> rawList = (List<Object>) root.get('data');
            List<Object> matched = new List<Object>();

            String target15 = to15(recordId);
            if (rawList != null) {
                for (Object o : rawList) {
                    Map<String, Object> doc = (Map<String, Object>) o;
                    if (matchesRecord(doc, target15)) {
                        matched.add(doc);
                    }
                }
            }
            return JSON.serialize(new Map<String, Object>{ 'data' => matched });
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * 文書を Agreement Manager にアップロードし、開いているレコードに linked_data で紐付ける。
     * @return アップロードジョブID
     */
    @AuraEnabled(cacheable=false)
    public static String uploadDocumentForRecord(
        String recordId, String objectApiName, String fileName, String base64Data) {
        try {
            NavigatorService.Config cfg = NavigatorService.loadConfig();
            String token = NavigatorService.getAccessToken(cfg, NavigatorService.UPLOAD_SCOPE);
            String jobsBase = 'callout:DocuSign_Navigator/v1/accounts/' + cfg.accountId + '/upload/jobs';

            // --- ステップ1: アップロードジョブ作成 ---
            String jobBody = JSON.serialize(new Map<String, Object>{
                'expected_number_of_docs' => 1,
                'job_name' => fileName,
                'language' => 'en-US'
            });
            HttpResponse jobRes = NavigatorService.callPost(jobsBase, token, jobBody);
            if (jobRes.getStatusCode() < 200 || jobRes.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'アップロードジョブ作成に失敗: HTTP ' + jobRes.getStatusCode() + ' ' + jobRes.getBody());
            }
            Map<String, Object> job = (Map<String, Object>) JSON.deserializeUntyped(jobRes.getBody());
            String jobId = (String) job.get('id');
            String uploadUrl = extractUploadUrl(job);
            if (String.isBlank(uploadUrl)) {
                throw new AuraHandledException(
                    'プリサインドURL(upload_document)が取得できませんでした: ' + jobRes.getBody());
            }

            // --- ステップ2: Azure Blob へ直接 PUT（linked_data を付与）---
            String linkedDataJson = JSON.serialize(new Map<String, Object>{
                'linked_data' => new List<Object>{
                    new Map<String, Object>{
                        'application_name' => 'Salesforce',
                        'object_name' => objectApiName,
                        'record_id' => recordId
                    }
                }
            });

            HttpRequest put = new HttpRequest();
            put.setEndpoint(uploadUrl);
            put.setMethod('PUT');
            put.setHeader('x-ms-blob-type', 'BlockBlob');
            put.setHeader('x-ms-meta-filename',
                EncodingUtil.urlEncode(fileName, 'UTF-8').replace('+', '%20'));
            put.setHeader('x-ms-meta-metadata', linkedDataJson); // linked_data は ASCII のみ
            put.setHeader('Content-Type', 'application/pdf');
            put.setBodyAsBlob(EncodingUtil.base64Decode(base64Data));
            put.setTimeout(120000);

            HttpResponse putRes;
            try {
                putRes = new Http().send(put);
            } catch (System.CalloutException ce) {
                throw new AuraHandledException(
                    'Blob へのアップロードに失敗しました。プリサインドURLのホストを '
                    + 'Remote Site Settings に登録してください。URL=' + uploadUrl
                    + ' / 元エラー: ' + ce.getMessage());
            }
            if (putRes.getStatusCode() < 200 || putRes.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'Blob への PUT に失敗: HTTP ' + putRes.getStatusCode() + ' ' + putRes.getBody());
            }

            // --- ステップ3: ジョブ完了通知（HATEOASのアクションを優先、無ければ規定パス）---
            String completeUrl = resolveCompleteUrl(job, jobsBase, jobId);
            HttpResponse compRes = NavigatorService.callPost(completeUrl, token, '{}');
            if (compRes.getStatusCode() < 200 || compRes.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'アップロード完了通知に失敗: HTTP ' + compRes.getStatusCode()
                    + ' ' + compRes.getBody() + ' (endpoint=' + completeUrl + ')');
            }
            return jobId;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    @TestVisible
    private static Boolean matchesRecord(Map<String, Object> doc, String target15) {
        Object linked = doc.get('linked_data');
        if (!(linked instanceof List<Object>)) {
            return false;
        }
        for (Object o : (List<Object>) linked) {
            if (o instanceof Map<String, Object>) {
                String recId = (String) ((Map<String, Object>) o).get('record_id');
                if (String.isNotBlank(recId) && to15(recId) == target15) {
                    return true;
                }
            }
        }
        return false;
    }

    @TestVisible
    private static String extractUploadUrl(Map<String, Object> job) {
        Object embedded = job.get('_embedded');
        if (!(embedded instanceof Map<String, Object>)) return null;
        Object docs = ((Map<String, Object>) embedded).get('documents');
        if (!(docs instanceof List<Object>) || ((List<Object>) docs).isEmpty()) return null;
        Object first = ((List<Object>) docs)[0];
        if (!(first instanceof Map<String, Object>)) return null;
        Object actions = ((Map<String, Object>) first).get('_actions');
        if (!(actions instanceof Map<String, Object>)) return null;
        return (String) ((Map<String, Object>) actions).get('upload_document');
    }

    /**
     * ジョブ作成レスポンスの _actions から完了系アクションURLを探す。
     * 見つかれば Named Credential 経由の絶対参照に変換、無ければ既定の actions/complete を使う。
     */
    @TestVisible
    private static String resolveCompleteUrl(Map<String, Object> job, String jobsBase, String jobId) {
        Object actions = job.get('_actions');
        if (actions instanceof Map<String, Object>) {
            for (Object v : ((Map<String, Object>) actions).values()) {
                String href = hrefOf(v);
                if (String.isNotBlank(href)
                    && (href.contains('complete') || href.contains('commit') || href.contains('process'))) {
                    return toNamedCredentialUrl(href);
                }
            }
        }
        return jobsBase + '/' + jobId + '/actions/complete';
    }

    private static String hrefOf(Object action) {
        if (action instanceof String) return (String) action;
        if (action instanceof Map<String, Object>) {
            return (String) ((Map<String, Object>) action).get('href');
        }
        return null;
    }

    private static String toNamedCredentialUrl(String href) {
        if (href.startsWithIgnoreCase('http')) {
            // 絶対URL(api-d.docusign.com...)は Named Credential のパスに置き換える
            Integer idx = href.indexOf('/v1/');
            return idx >= 0 ? 'callout:DocuSign_Navigator' + href.substring(idx) : href;
        }
        return 'callout:DocuSign_Navigator' + (href.startsWith('/') ? href : '/' + href);
    }

    private static String to15(String recordId) {
        if (String.isBlank(recordId)) return '';
        return recordId.length() >= 15 ? recordId.substring(0, 15) : recordId;
    }
}
