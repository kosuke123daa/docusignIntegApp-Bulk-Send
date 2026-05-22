public with sharing class GetWorkspaceInfoAction {

    public class Request {
        @InvocableVariable(required=true label='商談ID' description='ワークスペース情報を取得する商談のSalesforce ID')
        public String opportunityId;
    }

    public class Response {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='ワークスペースのタスク・メンバー情報を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
        @InvocableVariable(label='ワークスペースID' description='商談に紐づくワークスペースの数値ID')
        public String workspaceId;
        @InvocableVariable(label='タスクJSON' description='アップロードリクエストとエンベロープのJSONデータ')
        public String tasksJson;
        @InvocableVariable(label='メンバーJSON' description='ワークスペースメンバーのJSONデータ')
        public String membersJson;
        @InvocableVariable(label='ドキュメントJSON' description='ワークスペースにアップロード済みのドキュメントのJSONデータ')
        public String documentsJson;
        @InvocableVariable(label='タスク件数' description='アップロードリクエストとエンベロープの合計件数')
        public Integer taskCount;
        @InvocableVariable(label='メンバー件数' description='ワークスペースメンバーの件数')
        public Integer memberCount;
        @InvocableVariable(label='ドキュメント件数' description='ワークスペースにアップロード済みのドキュメント件数')
        public Integer documentCount;
    }

    @InvocableMethod(
        label='ワークスペース情報取得'
        description='商談に紐づくDocuSignワークスペースのタスク（アップロードリクエスト・エンベロープ）、ドキュメント、メンバー一覧を取得する。「ワークスペースの状況を教えて」「タスクの進捗は？」「メンバーは誰？」「書類の提出状況は？」「どんなファイルがある？」などの質問に対応。'
        category='DocuSign'
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response resp = new Response();
            resp.success       = false;
            resp.message       = '未実行';
            resp.taskCount     = 0;
            resp.memberCount   = 0;
            resp.documentCount = 0;
            resp.tasksJson     = '[]';
            resp.membersJson   = '[]';
            resp.documentsJson = '[]';
            try {
                Opportunity opp = [SELECT DocuSign_Workspace_Id__c, Name FROM Opportunity WHERE Id = :req.opportunityId LIMIT 1];
                String wsId = opp.DocuSign_Workspace_Id__c;
                if (String.isBlank(wsId)) {
                    resp.message = '商談「' + opp.Name + '」にはワークスペースが作成されていません。';
                    resp.success = true;
                    results.add(resp);
                    continue;
                }
                resp.workspaceId = wsId;

                List<Object> uploadReqs = WorkspaceService.getWorkspaceUploadRequests(wsId);
                List<Object> envelopes  = WorkspaceService.getWorkspaceEnvelopes(wsId);
                List<Object> members    = WorkspaceService.getWorkspaceUsers(wsId);
                List<Object> documents  = WorkspaceService.getWorkspaceDocuments(wsId);

                // Build user lookup map for resolving assignee names
                Map<String, Map<String, Object>> userById = new Map<String, Map<String, Object>>();
                for (Object u : members) {
                    Map<String, Object> um = (Map<String, Object>) u;
                    String uid = (String) um.get('user_id');
                    if (String.isNotBlank(uid)) userById.put(uid, um);
                }

                List<String> lines = new List<String>{ '【ワークスペース情報: ' + opp.Name + '】', '' };

                lines.add('▼ アップロードリクエスト (' + uploadReqs.size() + '件)');
                if (uploadReqs.isEmpty()) {
                    lines.add('  なし');
                } else {
                    Integer idx = 1;
                    for (Object obj : uploadReqs) {
                        Map<String, Object> t = (Map<String, Object>) obj;
                        String tName    = t.get('name')    != null ? String.valueOf(t.get('name'))    : '';
                        String tStatus  = t.get('status')  != null ? String.valueOf(t.get('status'))  : '';
                        String tUpdated = t.get('updated_date') != null
                            ? String.valueOf(t.get('updated_date'))
                            : (t.get('created_date') != null ? String.valueOf(t.get('created_date')) : '');
                        String assignee = '未割り当て';
                        if (t.get('assignments') instanceof List<Object>) {
                            for (Object a : (List<Object>) t.get('assignments')) {
                                Map<String, Object> am = (Map<String, Object>) a;
                                if ('assignee'.equals((String) am.get('upload_request_responsibility_type_id'))) {
                                    String uid = (String) am.get('assignee_user_id');
                                    Map<String, Object> user = userById.get(uid);
                                    if (user != null) {
                                        String fn = user.get('first_name') != null ? String.valueOf(user.get('first_name')) : '';
                                        String ln = user.get('last_name')  != null ? String.valueOf(user.get('last_name'))  : '';
                                        assignee = (fn + ' ' + ln).trim();
                                        if (String.isBlank(assignee) && user.get('email') != null) {
                                            assignee = String.valueOf(user.get('email'));
                                        }
                                    }
                                }
                            }
                        }
                        lines.add('  ' + idx + '. ' + tName + ' / ステータス:' + tStatus + ' / 担当:' + assignee + ' / 更新:' + tUpdated);
                        idx++;
                    }
                }

                lines.add('');
                lines.add('▼ エンベロープ (' + envelopes.size() + '件)');
                if (envelopes.isEmpty()) {
                    lines.add('  なし');
                } else {
                    Integer idx2 = 1;
                    for (Object obj : envelopes) {
                        Map<String, Object> e = (Map<String, Object>) obj;
                        String eName    = e.get('name') != null
                            ? String.valueOf(e.get('name'))
                            : (e.get('email_subject') != null ? String.valueOf(e.get('email_subject')) : '');
                        String eStatus  = e.get('status')                != null ? String.valueOf(e.get('status'))                : '';
                        String eUpdated = e.get('last_modified_date_time') != null ? String.valueOf(e.get('last_modified_date_time')) : '';
                        lines.add('  ' + idx2 + '. ' + eName + ' / ステータス:' + eStatus + ' / 更新:' + eUpdated);
                        idx2++;
                    }
                }

                lines.add('');
                lines.add('▼ ドキュメント (' + documents.size() + '件)');
                if (documents.isEmpty()) {
                    lines.add('  なし');
                } else {
                    Integer idxD = 1;
                    for (Object obj : documents) {
                        Map<String, Object> d = (Map<String, Object>) obj;
                        String dName    = d.get('name')         != null ? String.valueOf(d.get('name'))         : '';
                        String dType    = d.get('content_type') != null ? String.valueOf(d.get('content_type')) : '';
                        String dUpdated = d.get('updated_at')   != null ? String.valueOf(d.get('updated_at'))   :
                                         (d.get('created_at')  != null ? String.valueOf(d.get('created_at'))   : '');
                        lines.add('  ' + idxD + '. ' + dName + ' / 種別:' + dType + ' / 更新:' + dUpdated);
                        idxD++;
                    }
                }

                lines.add('');
                lines.add('▼ メンバー (' + members.size() + '件)');
                if (members.isEmpty()) {
                    lines.add('  なし');
                } else {
                    for (Object obj : members) {
                        Map<String, Object> m = (Map<String, Object>) obj;
                        String fn    = m.get('first_name') != null ? String.valueOf(m.get('first_name')) : '';
                        String ln    = m.get('last_name')  != null ? String.valueOf(m.get('last_name'))  : '';
                        String email = m.get('email')      != null ? String.valueOf(m.get('email'))      : '';
                        String role  = m.get('role_name')  != null ? String.valueOf(m.get('role_name'))  :
                                      (m.get('role')       != null ? String.valueOf(m.get('role'))       : '');
                        lines.add('  - ' + (fn + ' ' + ln).trim() + ' (' + email + ') / ロール:' + role);
                    }
                }

                resp.tasksJson     = JSON.serialize(new Map<String, Object>{ 'uploadRequests' => uploadReqs, 'envelopes' => envelopes });
                resp.membersJson   = JSON.serialize(members);
                resp.documentsJson = JSON.serialize(documents);
                resp.taskCount     = uploadReqs.size() + envelopes.size();
                resp.memberCount   = members.size();
                resp.documentCount = documents.size();
                resp.message     = String.join(lines, '\n');
                resp.success     = true;

            } catch (Exception e) {
                resp.success = false;
                resp.message = '例外: ' + e.getTypeName() + ' - ' + e.getMessage();
            }
            results.add(resp);
        }
        return results;
    }
}
