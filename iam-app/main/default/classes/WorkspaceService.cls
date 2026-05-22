public with sharing class WorkspaceService {

    private static final String WORKSPACE_BASE_URL  = 'callout:DocuSign_Navigator/v1/accounts/';
    private static final String WORKSPACE_APP_URL   = 'https://apps-d.docusign.com/workspaces/';
    private static final String MULTIPART_BOUNDARY  = '----DocuSignApexBoundary';

    // ── ワークスペース作成 ─────────────────────────────────────────────────────

    public static Map<String, Object> createWorkspace(String workspaceName) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token   = NavigatorService.getAccessToken(cfg);
        String url     = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces';
        String body    = JSON.serialize(new Map<String, Object>{ 'name' => workspaceName });

        HttpResponse res = NavigatorService.callPost(url, token, body);
        if (res.getStatusCode() != 201) {
            throw new CalloutException('Workspace作成失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        // workspace_id UUID first 8 hex chars encode the numeric ID used in browser URLs
        String uuidId    = (String) result.get('workspace_id');
        String numericId = uuidToNumericId(uuidId);
        result.put('display_id', numericId);
        result.put('workspace_url', WORKSPACE_APP_URL + numericId);
        return result;
    }

    // ── ワークスペース取得 ─────────────────────────────────────────────────────

    public static Map<String, Object> getWorkspace(String workspaceId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token  = NavigatorService.getAccessToken(cfg);
        String apiId  = toApiId(workspaceId);
        String url    = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + apiId;

        HttpResponse res = NavigatorService.callGet(url, token);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Workspace取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String uuidId    = (String) result.get('workspace_id');
        String numericId = uuidToNumericId(uuidId != null ? uuidId : workspaceId);
        result.put('display_id', numericId);
        result.put('workspace_url', WORKSPACE_APP_URL + numericId);
        return result;
    }

    // ── ドキュメント一覧取得 ───────────────────────────────────────────────────

    public static List<Object> getWorkspaceDocuments(String workspaceId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/documents';

        HttpResponse res = NavigatorService.callGet(url, token);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('ドキュメント一覧取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return body.containsKey('documents') ? (List<Object>) body.get('documents') : new List<Object>();
    }

    // ── ドキュメントアップロード（multipart/form-data） ────────────────────────

    public static Map<String, Object> uploadDocument(String workspaceId, String contentDocumentId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);

        ContentVersion cv = [
            SELECT VersionData, Title, FileExtension, FileType
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];

        String fileName    = cv.Title + (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : '');
        String contentType = getContentType(cv.FileType);

        Blob multipartBody = buildMultipartBody(cv.VersionData, fileName, contentType);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/documents');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + MULTIPART_BOUNDARY);
        req.setBodyAsBlob(multipartBody);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 201) {
            throw new CalloutException('ドキュメントアップロード失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // ── ワークスペースユーザー一覧取得 ────────────────────────────────────────

    public static List<Object> getWorkspaceUsers(String workspaceId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/users';

        HttpResponse res = NavigatorService.callGet(url, token);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('ユーザー一覧取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return body.containsKey('users') ? (List<Object>) body.get('users') : new List<Object>();
    }

    // ── ユーザー追加 ──────────────────────────────────────────────────────────

    public static void addWorkspaceUser(String workspaceId, String email, String roleId, String firstName, String lastName) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/users';

        Map<String, Object> bodyMap = new Map<String, Object>{
            'email'      => email,
            'first_name' => firstName != null ? firstName : '',
            'last_name'  => lastName  != null ? lastName  : ''
        };
        if (String.isNotBlank(roleId)) bodyMap.put('role_id', roleId);
        String reqBody = JSON.serialize(bodyMap);
        System.debug('addWorkspaceUser url: ' + url + ' body: ' + reqBody);

        HttpResponse res = NavigatorService.callPost(url, token, reqBody);
        System.debug('addWorkspaceUser response: ' + res.getStatusCode() + ' ' + res.getBody());
        if (res.getStatusCode() == 400 && res.getBody().contains('CANNOT_ASSIGN_INTERNAL_ROLE_TO_EXTERNAL_USER')) {
            // External user: retry without role_id (defaults to Participate role)
            bodyMap.remove('role_id');
            res = NavigatorService.callPost(url, token, JSON.serialize(bodyMap));
            System.debug('addWorkspaceUser retry response: ' + res.getStatusCode() + ' ' + res.getBody());
        }
        if (res.getStatusCode() == 429) {
            throw new CalloutException('ユーザー追加失敗(' + email + '): APIのレート制限に達しました。しばらく待ってから再試行してください。');
        }
        if (res.getStatusCode() != 201 && res.getStatusCode() != 200) {
            throw new CalloutException('ユーザー追加失敗(' + email + '): HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    // ── 割り当て可能なロール一覧取得 ────────────────────────────────────────────

    public static List<Object> getAssignableRoles(String workspaceId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/assignable-roles';

        HttpResponse res = NavigatorService.callGet(url, token);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('ロール取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return body.containsKey('roles') ? (List<Object>) body.get('roles') : new List<Object>();
    }

    // ── エンベロープドラフト作成 ──────────────────────────────────────────────

    public static Map<String, Object> createEnvelope(String workspaceId, String envelopeName, List<String> documentIds) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/envelopes';

        Map<String, Object> bodyMap = new Map<String, Object>{ 'envelope_name' => envelopeName };
        if (documentIds != null && !documentIds.isEmpty()) bodyMap.put('document_ids', documentIds);

        HttpResponse res = NavigatorService.callPost(url, token, JSON.serialize(bodyMap));
        if (res.getStatusCode() != 201) {
            throw new CalloutException('エンベロープ作成失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // ── エンベロープ一覧取得 ──────────────────────────────────────────────────

    public static List<Object> getWorkspaceEnvelopes(String workspaceId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/envelopes';

        HttpResponse res = NavigatorService.callGet(url, token);
        System.debug('getWorkspaceEnvelopes response: ' + res.getStatusCode() + ' ' + res.getBody());
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('エンベロープ一覧取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> envelopes = body.containsKey('envelopes') ? (List<Object>) body.get('envelopes') : new List<Object>();
        if (!envelopes.isEmpty()) {
            enrichEnvelopesWithESignData(envelopes, token, cfg);
        }
        return envelopes;
    }

    private static void enrichEnvelopesWithESignData(List<Object> envelopes, String token, NavigatorService.Config cfg) {
        List<String> ids = new List<String>();
        for (Object env : envelopes) {
            String eid = (String) ((Map<String, Object>) env).get('envelope_id');
            if (String.isNotBlank(eid)) ids.add(eid);
        }
        if (ids.isEmpty()) return;

        String eSignUrl = NavigatorService.getESignBaseUrl(cfg)
            + '/v2.1/accounts/' + cfg.accountId
            + '/envelopes?envelope_ids=' + String.join(ids, ',');

        try {
            HttpResponse res = NavigatorService.callGet(eSignUrl, token);
            System.debug('enrichEnvelopes eSign response: ' + res.getStatusCode() + ' ' + res.getBody().left(1000));
            if (res.getStatusCode() != 200) return;

            Map<String, Object> respBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> eSignEnvs = respBody.containsKey('envelopes') ? (List<Object>) respBody.get('envelopes') : new List<Object>();

            // eSign API returns camelCase envelopeId; workspace API uses snake_case envelope_id
            Map<String, Map<String, Object>> eSignMap = new Map<String, Map<String, Object>>();
            for (Object e : eSignEnvs) {
                Map<String, Object> em = (Map<String, Object>) e;
                String eid = (String) em.get('envelopeId');
                if (String.isNotBlank(eid)) eSignMap.put(eid.toLowerCase(), em);
            }

            for (Object env : envelopes) {
                Map<String, Object> envMap = (Map<String, Object>) env;
                String eid = (String) envMap.get('envelope_id');
                Map<String, Object> eSign = eSignMap.get(eid != null ? eid.toLowerCase() : '');
                if (eSign != null) {
                    String subject = (String) eSign.get('emailSubject');
                    if (String.isNotBlank(subject)) envMap.put('name', subject);
                    String lastModified = (String) eSign.get('lastModifiedDateTime');
                    if (String.isNotBlank(lastModified)) envMap.put('last_modified_date_time', lastModified);
                }
            }
        } catch (Exception e) {
            System.debug('enrichEnvelopesWithESignData failed: ' + e.getMessage());
        }
    }

    // ── アップロードリクエスト一覧取得 ───────────────────────────────────────

    public static List<Object> getWorkspaceUploadRequests(String workspaceId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/upload-requests';

        HttpResponse res = NavigatorService.callGet(url, token);
        System.debug('getWorkspaceUploadRequests response: ' + res.getStatusCode() + ' ' + res.getBody());
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('アップロードリクエスト一覧取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        // Try known response key variants
        for (String key : new List<String>{ 'upload_requests', 'uploadRequests', 'items', 'data' }) {
            if (body.containsKey(key) && body.get(key) instanceof List<Object>) {
                return (List<Object>) body.get(key);
            }
        }
        return new List<Object>();
    }

    // ── アップロードリクエスト作成 ────────────────────────────────────────────

    public static Map<String, Object> createUploadRequest(
        String workspaceId, String name, String description, String dueDate, List<Map<String, String>> assignees
    ) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);
        String url   = WORKSPACE_BASE_URL + cfg.accountId + '/workspaces/' + toApiId(workspaceId) + '/upload-requests';

        // due_date is required by the API; default to 30 days from today if not provided
        String effectiveDueDate = dueDate;
        if (String.isBlank(effectiveDueDate)) {
            Datetime dt = Datetime.newInstance(Date.today().addDays(30), Time.newInstance(0, 0, 0, 0));
            effectiveDueDate = dt.format('yyyy-MM-dd');
        }

        Map<String, Object> bodyMap = new Map<String, Object>{
            'name'        => name,
            'description' => description != null ? description : '',
            'due_date'    => effectiveDueDate,
            'status'      => 'draft'
        };
        List<Map<String, Object>> assignments = new List<Map<String, Object>>();
        if (assignees != null) {
            for (Map<String, String> a : assignees) {
                String email = a.get('email');
                if (String.isNotBlank(email)) {
                    assignments.add(new Map<String, Object>{
                        'email'                                 => email,
                        'upload_request_responsibility_type_id' => 'assignee',
                        'first_name'                            => a.get('firstName') != null ? a.get('firstName') : '',
                        'last_name'                             => a.get('lastName')  != null ? a.get('lastName')  : ''
                    });
                }
            }
        }
        bodyMap.put('assignments', assignments);
        String reqBody = JSON.serialize(bodyMap);
        System.debug('createUploadRequest url: ' + url + ' body: ' + reqBody);

        HttpResponse res = NavigatorService.callPost(url, token, reqBody);
        System.debug('createUploadRequest response: ' + res.getStatusCode() + ' ' + res.getBody());
        if (res.getStatusCode() != 201) {
            throw new CalloutException('アップロードリクエスト作成失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    // Salesforce stores the numeric ID; API calls require the UUID form.
    // If workspaceId is numeric (no dashes), convert to UUID; otherwise pass through.
    private static String toApiId(String workspaceId) {
        if (String.isBlank(workspaceId) || workspaceId.contains('-')) return workspaceId;
        return numericIdToUuid(workspaceId);
    }

    // 1978028 → "001e2eac-0000-0000-0000-000000000000"
    private static String numericIdToUuid(String numericId) {
        Long val = Long.valueOf(numericId);
        String hexChars = '0123456789abcdef';
        String hex = '';
        Long remaining = val;
        while (remaining > 0) {
            Integer digit = (Integer) Math.mod(remaining, 16);
            hex = hexChars.substring(digit, digit + 1) + hex;
            remaining = remaining / 16;
        }
        while (hex.length() < 8) hex = '0' + hex;
        return hex + '-0000-0000-0000-000000000000';
    }

    // "001e2eac-0000-..." → "1978028"
    private static String uuidToNumericId(String uuid) {
        if (String.isBlank(uuid) || uuid.length() < 8) return uuid;
        String hex      = uuid.substring(0, 8).toLowerCase();
        String hexChars = '0123456789abcdef';
        Long val        = 0L;
        for (Integer i = 0; i < hex.length(); i++) {
            Integer digit = hexChars.indexOf(hex.substring(i, i + 1));
            if (digit < 0) return uuid;
            val = val * 16 + digit;
        }
        return String.valueOf(val);
    }

    private static Blob buildMultipartBody(Blob fileData, String fileName, String contentType) {
        String header = '--' + MULTIPART_BOUNDARY + '\r\n'
            + 'Content-Disposition: form-data; name="file"; filename="' + fileName + '"\r\n'
            + 'Content-Type: ' + contentType + '\r\n\r\n';
        String footer = '\r\n--' + MULTIPART_BOUNDARY + '--';

        // Use hex concatenation instead of base64 to avoid 3-byte alignment issues
        String hexBody = EncodingUtil.convertToHex(Blob.valueOf(header))
                       + EncodingUtil.convertToHex(fileData)
                       + EncodingUtil.convertToHex(Blob.valueOf(footer));
        return EncodingUtil.convertFromHex(hexBody);
    }

    private static String getContentType(String fileType) {
        if (fileType == 'PDF')  return 'application/pdf';
        if (fileType == 'WORD' || fileType == 'WORD_X') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (fileType == 'PNG')  return 'image/png';
        if (fileType == 'JPG' || fileType == 'JPEG') return 'image/jpeg';
        return 'application/octet-stream';
    }
}
