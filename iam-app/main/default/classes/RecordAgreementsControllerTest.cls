@isTest
private class RecordAgreementsControllerTest {

    private static final String OPP_ID_18 = '006000000000001AAA';
    private static final String OPP_ID_15 = '006000000000001';

    // 認証(token)・一覧・アップロード各エンドポイントを URL で振り分けるモック。
    private class MultiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String url = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            if (url.contains('/oauth/token')) {
                res.setBody('{"access_token":"TEST_TOKEN","token_type":"Bearer","expires_in":3600}');
            } else if (url.contains('/agreements')) {
                res.setBody(agreementsJson());
            } else if (url.endsWith('/upload/jobs')) {
                res.setStatusCode(201);
                res.setBody(jobJson());
            } else if (url.contains('blob.core.windows.net')) {
                res.setStatusCode(201);
                res.setBody('');
            } else { // actions/complete 等
                res.setBody('{}');
            }
            return res;
        }
    }

    private static String agreementsJson() {
        // 1件はレコードに linked_data で紐付き、もう1件は紐付き無し（除外される想定）。
        return '{"data":['
            + '{"id":"a1","file_name":"linked.pdf","type":"Purchase","status":"COMPLETE",'
            +   '"review_status":"PENDING","source_name":"UploadApiJob",'
            +   '"metadata":{"created_at":"2026-06-24T05:16:03Z"},'
            +   '"linked_data":[{"application_name":"Salesforce","object_name":"Opportunity","record_id":"' + OPP_ID_15 + '"}]},'
            + '{"id":"a2","file_name":"other.pdf","type":"Other","status":"COMPLETE",'
            +   '"linked_data":[{"application_name":"Salesforce","object_name":"Opportunity","record_id":"006XXXXXXXXXXXX"}]},'
            + '{"id":"a3","file_name":"nolink.pdf","type":"Other","status":"COMPLETE"}'
            + ']}';
    }

    private static String jobJson() {
        return '{"id":"job-1",'
            + '"_embedded":{"documents":[{"_actions":{"upload_document":"https://teststorage.blob.core.windows.net/u/abc?sig=x"}}]},'
            + '"_actions":{"complete":{"href":"/v1/accounts/ACC/upload/jobs/job-1/actions/complete"}}}';
    }

    @isTest
    static void testGetAgreementsForRecord_filtersByLinkedData() {
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        Test.startTest();
        String resultJson = RecordAgreementsController.getAgreementsForRecord(OPP_ID_18);
        Test.stopTest();

        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        List<Object> data = (List<Object>) root.get('data');
        System.assertEquals(1, data.size(), 'linked_data が一致する1件のみ返るはず');
        Map<String, Object> doc = (Map<String, Object>) data[0];
        System.assertEquals('a1', doc.get('id'));
    }

    @isTest
    static void testUploadDocumentForRecord_success() {
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        Test.startTest();
        String jobId = RecordAgreementsController.uploadDocumentForRecord(
            OPP_ID_18, 'Opportunity', 'test.pdf', EncodingUtil.base64Encode(Blob.valueOf('hello')));
        Test.stopTest();
        System.assertEquals('job-1', jobId);
    }

    @isTest
    static void testHelpers() {
        // matchesRecord
        Map<String, Object> matchDoc = new Map<String, Object>{
            'linked_data' => new List<Object>{
                new Map<String, Object>{ 'record_id' => OPP_ID_18 }
            }
        };
        System.assertEquals(true, RecordAgreementsController.matchesRecord(matchDoc, OPP_ID_15));
        System.assertEquals(false,
            RecordAgreementsController.matchesRecord(new Map<String, Object>(), OPP_ID_15));

        // extractUploadUrl
        Map<String, Object> job = (Map<String, Object>) JSON.deserializeUntyped(jobJson());
        System.assert(RecordAgreementsController.extractUploadUrl(job).startsWith('https://teststorage'));

        // resolveCompleteUrl (HATEOAS)
        String c = RecordAgreementsController.resolveCompleteUrl(job, 'callout:DocuSign_Navigator/x', 'job-1');
        System.assert(c.contains('/actions/complete'), 'completeアクションを解決すること: ' + c);
    }
}
