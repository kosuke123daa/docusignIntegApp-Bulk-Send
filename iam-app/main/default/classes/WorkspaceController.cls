public with sharing class WorkspaceController {

    // ── ワークスペース作成 & Opportunity へ保存 ────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> createWorkspace(String opportunityId, String workspaceName) {
        Map<String, Object> result = WorkspaceService.createWorkspace(workspaceName);

        if (String.isNotBlank(opportunityId)) {
            // Use numeric 'display_id' (e.g. 1978028) for Salesforce field and browser URL
            String wsId = (String) result.get('display_id');
            if (String.isNotBlank(wsId)) {
                Opportunity opp = new Opportunity(Id = opportunityId, DocuSign_Workspace_Id__c = wsId);
                update opp;
            }
        }
        return result;
    }

    // ── ワークスペース情報取得 ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getWorkspaceInfo(String workspaceId) {
        return WorkspaceService.getWorkspace(workspaceId);
    }

    // ── 商談に保存されたワークスペースIDを取得 ─────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static String getSavedWorkspaceId(String opportunityId) {
        Opportunity opp = [SELECT DocuSign_Workspace_Id__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        return opp.DocuSign_Workspace_Id__c;
    }

    // ── 商談添付ファイル一覧取得 ──────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getOpportunityFiles(String opportunityId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.FileType, ContentDocument.ContentSize, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            AND ContentDocument.FileType IN ('PDF', 'WORD', 'WORD_X', 'PNG', 'JPG', 'JPEG')
            ORDER BY ContentDocument.LastModifiedDate DESC
        ];

        List<Map<String, Object>> files = new List<Map<String, Object>>();
        for (ContentDocumentLink link : links) {
            files.add(new Map<String, Object>{
                'contentDocumentId' => link.ContentDocumentId,
                'title'             => link.ContentDocument.Title,
                'fileExtension'     => link.ContentDocument.FileExtension,
                'fileType'          => link.ContentDocument.FileType,
                'contentSize'       => link.ContentDocument.ContentSize,
                'lastModifiedDate'  => String.valueOf(link.ContentDocument.LastModifiedDate)
            });
        }
        return files;
    }

    // ── ドキュメントアップロード ───────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> uploadDocument(String workspaceId, String contentDocumentId) {
        return WorkspaceService.uploadDocument(workspaceId, contentDocumentId);
    }

    // ── ワークスペースドキュメント一覧取得 ────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Object> getWorkspaceDocuments(String workspaceId) {
        return WorkspaceService.getWorkspaceDocuments(workspaceId);
    }

    // ── 商談の関連コンタクト取得 ──────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getOpportunityContacts(String opportunityId) {
        List<OpportunityContactRole> roles = [
            SELECT Contact.Id, Contact.Name, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            AND Contact.Email != null
            ORDER BY IsPrimary DESC, Contact.Name ASC
        ];

        List<Map<String, Object>> contacts = new List<Map<String, Object>>();
        for (OpportunityContactRole ocr : roles) {
            contacts.add(new Map<String, Object>{
                'contactId' => ocr.Contact.Id,
                'name'      => ocr.Contact.Name,
                'email'     => ocr.Contact.Email
            });
        }
        return contacts;
    }

    // ── 割り当て可能なロール一覧 ──────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Object> getAssignableRoles(String workspaceId) {
        return WorkspaceService.getAssignableRoles(workspaceId);
    }

    // ── ワークスペースユーザー一覧取得 ────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Object> getWorkspaceUsers(String workspaceId) {
        return WorkspaceService.getWorkspaceUsers(workspaceId);
    }

    // ── ユーザー追加 ──────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static void addWorkspaceUser(String workspaceId, String email, String roleId) {
        String firstName = '';
        String lastName  = '';
        List<Contact> contacts = [SELECT FirstName, LastName FROM Contact WHERE Email = :email LIMIT 1];
        if (!contacts.isEmpty()) {
            firstName = contacts[0].FirstName != null ? contacts[0].FirstName : '';
            lastName  = contacts[0].LastName  != null ? contacts[0].LastName  : '';
        } else {
            List<User> users = [SELECT FirstName, LastName FROM User WHERE Email = :email AND IsActive = true LIMIT 1];
            if (!users.isEmpty()) {
                firstName = users[0].FirstName != null ? users[0].FirstName : '';
                lastName  = users[0].LastName  != null ? users[0].LastName  : '';
            }
        }
        WorkspaceService.addWorkspaceUser(workspaceId, email, roleId, firstName, lastName);
    }

    // ── エンベロープドラフト作成 ──────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> createEnvelope(String workspaceId, String envelopeName, List<String> documentIds) {
        return WorkspaceService.createEnvelope(workspaceId, envelopeName, documentIds);
    }

    // ── エンベロープ一覧取得 ──────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Object> getWorkspaceEnvelopes(String workspaceId) {
        return WorkspaceService.getWorkspaceEnvelopes(workspaceId);
    }

    // ── アップロードリクエスト一覧取得 ───────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Object> getWorkspaceUploadRequests(String workspaceId) {
        return WorkspaceService.getWorkspaceUploadRequests(workspaceId);
    }

    // ── アップロードリクエスト作成 ────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> createUploadRequest(
        String workspaceId, String name, String description, String dueDate,
        String assigneeFirstName, String assigneeLastName, String assigneeEmail
    ) {
        List<Map<String, String>> assignees = new List<Map<String, String>>();
        if (String.isNotBlank(assigneeEmail)) {
            assignees.add(new Map<String, String>{
                'email'     => assigneeEmail,
                'firstName' => assigneeFirstName != null ? assigneeFirstName : '',
                'lastName'  => assigneeLastName  != null ? assigneeLastName  : ''
            });
        }
        return WorkspaceService.createUploadRequest(workspaceId, name, description, dueDate, assignees);
    }
}
