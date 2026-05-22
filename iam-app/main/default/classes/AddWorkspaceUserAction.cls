public with sharing class AddWorkspaceUserAction {

    public class Request {
        @InvocableVariable(required=true label='商談ID' description='ユーザーを追加するワークスペースの商談ID')
        public String opportunityId;

        @InvocableVariable(required=true label='メールアドレス' description='追加するユーザーのメールアドレス')
        public String email;

        @InvocableVariable(required=false label='ロールID' description='割り当てるロールのID。省略した場合はデフォルトロールが適用される')
        public String roleId;

        @InvocableVariable(required=false label='名（ファーストネーム）' description='追加するユーザーの名。省略した場合はSalesforceのコンタクト・ユーザーから自動取得を試みる')
        public String firstName;

        @InvocableVariable(required=false label='姓（ラストネーム）' description='追加するユーザーの姓。省略した場合はSalesforceのコンタクト・ユーザーから自動取得を試みる')
        public String lastName;
    }

    public class Response {
        @InvocableVariable(label='成功フラグ' description='APIの呼び出しが成功した場合はtrue、失敗した場合はfalse')
        public Boolean success;
        @InvocableVariable(label='メッセージ' description='追加結果を日本語でまとめたテキスト。Agentforceはこの内容をユーザーへの回答に使用する')
        public String message;
    }

    @InvocableMethod(
        label='ワークスペースユーザー追加'
        description='DocuSignワークスペースにユーザーを追加する。「〇〇さんをワークスペースに追加して」「メンバーを招待して」「〇〇@example.comをワークスペースに入れて」などの指示に対応。姓名省略時はSalesforceのコンタクト情報から自動補完する。'
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

                String fName = req.firstName;
                String lName = req.lastName;

                // Auto-fill name from Salesforce Contact or User if not provided
                if (String.isBlank(fName) && String.isBlank(lName)) {
                    List<Contact> contacts = [SELECT FirstName, LastName FROM Contact WHERE Email = :req.email LIMIT 1];
                    if (!contacts.isEmpty()) {
                        fName = contacts[0].FirstName;
                        lName = contacts[0].LastName;
                    } else {
                        List<User> users = [SELECT FirstName, LastName FROM User WHERE Email = :req.email AND IsActive = true LIMIT 1];
                        if (!users.isEmpty()) {
                            fName = users[0].FirstName;
                            lName = users[0].LastName;
                        }
                    }
                }

                WorkspaceService.addWorkspaceUser(wsId, req.email, req.roleId, fName, lName);

                String displayName = ((fName != null ? fName : '') + ' ' + (lName != null ? lName : '')).trim();
                if (String.isBlank(displayName)) displayName = req.email;
                resp.message = displayName + '（' + req.email + '）をワークスペースに追加しました。';
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
