import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createWorkspace       from '@salesforce/apex/WorkspaceController.createWorkspace';
import getWorkspaceInfo      from '@salesforce/apex/WorkspaceController.getWorkspaceInfo';
import getSavedWorkspaceId   from '@salesforce/apex/WorkspaceController.getSavedWorkspaceId';
import getOpportunityFiles   from '@salesforce/apex/WorkspaceController.getOpportunityFiles';
import uploadDocument        from '@salesforce/apex/WorkspaceController.uploadDocument';
import getWorkspaceDocuments from '@salesforce/apex/WorkspaceController.getWorkspaceDocuments';
import getOpportunityContacts from '@salesforce/apex/WorkspaceController.getOpportunityContacts';
import getAssignableRoles    from '@salesforce/apex/WorkspaceController.getAssignableRoles';
import getWorkspaceUsers     from '@salesforce/apex/WorkspaceController.getWorkspaceUsers';
import addWorkspaceUser      from '@salesforce/apex/WorkspaceController.addWorkspaceUser';
import createEnvelope        from '@salesforce/apex/WorkspaceController.createEnvelope';
import getWorkspaceEnvelopes      from '@salesforce/apex/WorkspaceController.getWorkspaceEnvelopes';
import getWorkspaceUploadRequests from '@salesforce/apex/WorkspaceController.getWorkspaceUploadRequests';
import createUploadRequest        from '@salesforce/apex/WorkspaceController.createUploadRequest';
import saveWorkspaceId            from '@salesforce/apex/WorkspaceController.saveWorkspaceId';
import clearSavedWorkspaceId      from '@salesforce/apex/WorkspaceController.clearSavedWorkspaceId';
import LightningConfirm           from 'lightning/confirm';

const FILE_ICON_MAP = {
    pdf:  'doctype:pdf',
    doc:  'doctype:word',
    docx: 'doctype:word',
    png:  'doctype:image',
    jpg:  'doctype:image',
    jpeg: 'doctype:image'
};

export default class WorkspaceManager extends LightningElement {
    @api recordId;

    @track isLoading        = false;
    @track errorMessage     = '';
    @track successMessage   = '';
    @track activeTab        = 'workspace';

    // Workspace
    @track workspaceId         = '';
    @track workspaceName       = '';
    @track newWorkspaceName    = '';
    @track connectWorkspaceId  = '';

    // Documents
    @track opportunityFiles      = [];
    @track workspaceDocuments    = [];
    @track selectedDocumentIds   = new Set();

    // Users
    @track opportunityContacts = [];
    @track workspaceUsers      = [];
    @track assignableRoles     = [];
    @track newUserEmail        = '';
    @track selectedRoleId      = '';

    // Envelopes
    @track workspaceEnvelopes = [];
    @track newEnvelopeName    = '';

    // Tasks (upload requests)
    @track workspaceTasks = [];

    // Upload requests
    @track uploadRequestName           = '';
    @track uploadRequestDescription    = '';
    @track uploadRequestDueDate        = '';
    @track uploadRequestFirstName      = '';
    @track uploadRequestLastName       = '';
    @track uploadRequestEmail          = '';
    @track selectedUploadRequestUserId = '';

    connectedCallback() {
        this._init();
    }

    async _init() {
        this.isLoading = true;
        try {
            const wsId = await getSavedWorkspaceId({ opportunityId: this.recordId });
            if (wsId) {
                this.workspaceId = wsId;
                await this._loadWorkspaceData();
            }
            await this._loadOpportunityData();
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadWorkspaceData() {
        const [info, docs, envelopes, tasks] = await Promise.all([
            getWorkspaceInfo({ workspaceId: this.workspaceId }),
            getWorkspaceDocuments({ workspaceId: this.workspaceId }),
            getWorkspaceEnvelopes({ workspaceId: this.workspaceId }),
            getWorkspaceUploadRequests({ workspaceId: this.workspaceId })
        ]);
        this.workspaceName      = info.name || '';
        this.workspaceDocuments = Array.isArray(docs) ? docs : [];
        this.workspaceEnvelopes = Array.isArray(envelopes) ? envelopes : [];
        this.workspaceTasks     = this._mapTasks(Array.isArray(tasks) ? tasks : []);

        const [roles, users] = await Promise.all([
            getAssignableRoles({ workspaceId: this.workspaceId }),
            getWorkspaceUsers({ workspaceId: this.workspaceId })
        ]);
        this.assignableRoles = Array.isArray(roles) ? roles : [];
        this.workspaceUsers  = Array.isArray(users) ? users : [];
    }

    async _loadOpportunityData() {
        const [files, contacts] = await Promise.all([
            getOpportunityFiles({ opportunityId: this.recordId }),
            getOpportunityContacts({ opportunityId: this.recordId })
        ]);
        this.opportunityFiles = (Array.isArray(files) ? files : []).map(f => ({
            ...f,
            iconName: FILE_ICON_MAP[(f.fileExtension || '').toLowerCase()] || 'doctype:unknown'
        }));
        this.opportunityContacts = Array.isArray(contacts) ? contacts : [];
    }

    // ── Getters ──────────────────────────────────────────────────────────────

    get workspaceUrl() {
        return this.workspaceId
            ? 'https://apps-d.docusign.com/workspaces/' + this.workspaceId
            : '';
    }

    get roleOptions() {
        return [
            { label: 'デフォルト（参加）', value: '' },
            ...this.assignableRoles.map(r => ({ label: r.name || r.role_id, value: r.role_id }))
        ];
    }

    // ── Tab ───────────────────────────────────────────────────────────────────

    handleTabChange(evt) {
        this.activeTab = evt.target.value;
        this._clearMessages();
    }

    // ── Workspace tab ─────────────────────────────────────────────────────────

    handleWorkspaceNameChange(evt) {
        this.newWorkspaceName = evt.target.value;
    }

    handleConnectWorkspaceIdChange(evt) {
        this.connectWorkspaceId = evt.target.value;
    }

    async handleConnectWorkspace() {
        if (!this.connectWorkspaceId.trim()) {
            this._setError('ワークスペースIDを入力してください。');
            return;
        }
        this.isLoading = true;
        this._clearMessages();
        try {
            const info = await saveWorkspaceId({
                opportunityId: this.recordId,
                workspaceId:   this.connectWorkspaceId.trim()
            });
            this.workspaceId   = this.connectWorkspaceId.trim();
            this.workspaceName = info.name || '';
            this.connectWorkspaceId = '';
            this._setSuccess('ワークスペースに接続しました。');
            await this._loadWorkspaceData();
            await this._loadOpportunityData();
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateWorkspace() {
        if (!this.newWorkspaceName.trim()) {
            this._setError('ワークスペース名を入力してください。');
            return;
        }
        this.isLoading = true;
        this._clearMessages();
        try {
            const result = await createWorkspace({
                opportunityId: this.recordId,
                workspaceName: this.newWorkspaceName.trim()
            });
            this.workspaceId   = result.display_id || result.workspace_id;
            this.workspaceName = result.name || this.newWorkspaceName.trim();
            this._setSuccess('ワークスペースを作成しました。');
            await this._loadWorkspaceData();
            await this._loadOpportunityData();
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleUnlinkWorkspace() {
        const confirmed = await LightningConfirm.open({
            message: 'この商談とDocuSignワークスペースの紐付けを解除します。'
                + 'DocuSign側のワークスペース自体は削除されません。よろしいですか？',
            label: '紐付けの解除',
            variant: 'header',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        this.isLoading = true;
        this._clearMessages();
        try {
            await clearSavedWorkspaceId({ opportunityId: this.recordId });
            this._resetWorkspaceState();
            this._setSuccess('ワークスペースの紐付けを解除しました。');
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // 紐付け解除後、未接続状態に戻す
    _resetWorkspaceState() {
        this.workspaceId         = '';
        this.workspaceName       = '';
        this.connectWorkspaceId  = '';
        this.workspaceDocuments  = [];
        this.workspaceEnvelopes  = [];
        this.workspaceTasks      = [];
        this.workspaceUsers      = [];
        this.assignableRoles     = [];
        this.selectedDocumentIds = new Set();
    }

    async handleRefreshWorkspace() {
        this.isLoading = true;
        this._clearMessages();
        try {
            const info = await getWorkspaceInfo({ workspaceId: this.workspaceId });
            this.workspaceName = info.name || '';
            this._setSuccess('ワークスペース情報を更新しました。');
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Documents tab ─────────────────────────────────────────────────────────

    async handleUploadDocument(evt) {
        const contentDocumentId = evt.currentTarget.dataset.id;
        this.isLoading = true;
        this._clearMessages();
        try {
            await uploadDocument({ workspaceId: this.workspaceId, contentDocumentId });
            this._setSuccess('ドキュメントをアップロードしました。');
            const docs = await getWorkspaceDocuments({ workspaceId: this.workspaceId });
            this.workspaceDocuments = Array.isArray(docs) ? docs : [];
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefreshWorkspaceDocuments() {
        this.isLoading = true;
        this._clearMessages();
        try {
            const docs = await getWorkspaceDocuments({ workspaceId: this.workspaceId });
            this.workspaceDocuments = Array.isArray(docs) ? docs : [];
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Users tab ─────────────────────────────────────────────────────────────

    handleSelectContact(evt) {
        this.newUserEmail = evt.currentTarget.dataset.email;
        this._clearMessages();
    }

    handleUserEmailChange(evt) {
        this.newUserEmail = evt.target.value;
    }

    handleRoleChange(evt) {
        this.selectedRoleId = evt.detail.value;
    }

    async handleAddUser() {
        if (!this.newUserEmail.trim()) {
            this._setError('メールアドレスを入力してください。');
            return;
        }
        const emailToAdd = this.newUserEmail.trim();
        const alreadyMember = this.workspaceUsers.some(
            u => u.email && u.email.toLowerCase() === emailToAdd.toLowerCase()
        );
        if (alreadyMember) {
            this._setError(emailToAdd + ' はすでにワークスペースのメンバーです。');
            return;
        }
        this.isLoading = true;
        this._clearMessages();
        try {
            await addWorkspaceUser({
                workspaceId: this.workspaceId,
                email: emailToAdd,
                roleId: this.selectedRoleId || null
            });
            this._setSuccess(emailToAdd + ' をワークスペースに追加しました。');
            this.newUserEmail = '';
            const users = await getWorkspaceUsers({ workspaceId: this.workspaceId });
            this.workspaceUsers = Array.isArray(users) ? users : [];
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Envelopes tab ─────────────────────────────────────────────────────────

    handleEnvelopeNameChange(evt) {
        this.newEnvelopeName = evt.target.value;
    }

    handleDocumentCheckboxChange(evt) {
        const docId = evt.target.dataset.id;
        if (evt.target.checked) {
            this.selectedDocumentIds.add(docId);
        } else {
            this.selectedDocumentIds.delete(docId);
        }
    }

    async handleCreateEnvelope() {
        if (!this.newEnvelopeName.trim()) {
            this._setError('エンベロープ名を入力してください。');
            return;
        }
        this.isLoading = true;
        this._clearMessages();
        try {
            const docIds = [...this.selectedDocumentIds];
            await createEnvelope({
                workspaceId:  this.workspaceId,
                envelopeName: this.newEnvelopeName.trim(),
                documentIds:  docIds.length > 0 ? docIds : null
            });
            this._setSuccess('エンベロープドラフトを作成しました。');
            this.newEnvelopeName    = '';
            this.selectedDocumentIds = new Set();
            const envelopes = await getWorkspaceEnvelopes({ workspaceId: this.workspaceId });
            this.workspaceEnvelopes = Array.isArray(envelopes) ? envelopes : [];
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefreshEnvelopes() {
        this.isLoading = true;
        this._clearMessages();
        try {
            const envelopes = await getWorkspaceEnvelopes({ workspaceId: this.workspaceId });
            this.workspaceEnvelopes = Array.isArray(envelopes) ? envelopes : [];
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Upload requests tab ───────────────────────────────────────────────────

    handleUrNameChange(evt)        { this.uploadRequestName        = evt.target.value; }
    handleUrDescriptionChange(evt) { this.uploadRequestDescription = evt.target.value; }
    handleUrDueDateChange(evt)     { this.uploadRequestDueDate     = evt.target.value; }
    handleUrFirstNameChange(evt)   { this.uploadRequestFirstName   = evt.target.value; }
    handleUrLastNameChange(evt)    { this.uploadRequestLastName    = evt.target.value; }
    handleUrEmailChange(evt)       { this.uploadRequestEmail       = evt.target.value; }

    async handleCreateUploadRequest() {
        if (!this.uploadRequestName.trim()) {
            this._setError('リクエスト名を入力してください。');
            return;
        }
        if (!this.uploadRequestEmail.trim()) {
            this._setError('担当者のメールアドレスを入力してください。');
            return;
        }
        if (!this.uploadRequestFirstName.trim() || !this.uploadRequestLastName.trim()) {
            this._setError('担当者の姓・名を入力してください。');
            return;
        }
        this.isLoading = true;
        this._clearMessages();
        try {
            await createUploadRequest({
                workspaceId:        this.workspaceId,
                name:               this.uploadRequestName.trim(),
                description:        this.uploadRequestDescription.trim() || null,
                dueDate:            this.uploadRequestDueDate || null,
                assigneeFirstName:  this.uploadRequestFirstName.trim(),
                assigneeLastName:   this.uploadRequestLastName.trim(),
                assigneeEmail:      this.uploadRequestEmail.trim()
            });
            this._setSuccess('アップロードリクエストを作成しました。');
            this.uploadRequestName           = '';
            this.uploadRequestDescription    = '';
            this.uploadRequestDueDate        = '';
            this.uploadRequestFirstName      = '';
            this.uploadRequestLastName       = '';
            this.uploadRequestEmail          = '';
            this.selectedUploadRequestUserId = '';
            const updatedTasks = await getWorkspaceUploadRequests({ workspaceId: this.workspaceId });
            this.workspaceTasks = this._mapTasks(Array.isArray(updatedTasks) ? updatedTasks : []);
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Tasks (workspace tab) ─────────────────────────────────────────────────

    get combinedTaskList() {
        const STATUS_LABEL = {
            // upload request statuses
            draft:       'ドラフト',
            in_progress: '進行中',
            completed:   '完了',
            // envelope statuses (eSignature format)
            created:     'ドラフト',
            sent:        '送信済み',
            delivered:   '配信済み',
            signed:      '署名済み',
            voided:      '無効',
            // ProperCase variants returned by Workspace envelope API
            Created:     'ドラフト',
            Sent:        '送信済み',
            Delivered:   '配信済み',
            Signed:      '署名済み',
            Voided:      '無効',
            Completed:   '完了',
            WaitingForOthers: '他者待ち'
        };
        const uploadItems = this.workspaceTasks.map(t => {
            // assignee_user_id (UUID) → look up name from workspaceUsers
            const userById = {};
            (this.workspaceUsers || []).forEach(u => { if (u.user_id) userById[u.user_id] = u; });
            const assignments = Array.isArray(t.assignments) ? t.assignments : [];
            const assigneeEntry = assignments.find(a => a.upload_request_responsibility_type_id === 'assignee');
            let recipient = '未割り当て';
            if (assigneeEntry) {
                const user = assigneeEntry.assignee_user_id ? userById[assigneeEntry.assignee_user_id] : null;
                if (user) {
                    recipient = ((user.first_name || '') + ' ' + (user.last_name || '')).trim() || user.email || '未割り当て';
                } else if (assigneeEntry.email) {
                    recipient = assigneeEntry.email;
                }
            }
            return {
                id:           t.upload_request_id || t.id || '',
                iconName:     'utility:upload',
                typeLabel:    'アップロード依頼',
                name:         t.name || '',
                statusLabel:  STATUS_LABEL[t.status] || t.status || '',
                recipient,
                lastModified: this._formatDate(t.updated_date || t.created_date || t.updated_at || t.last_modified_date_time || t.created_at || '')
            };
        });
        const DRAFT_STATUSES = new Set(['created', 'Created', 'draft']);
        const envelopeItems = this.workspaceEnvelopes.map(e => {
            const envId = e.envelope_id || e.envelopeId || '';
            const isDraft = DRAFT_STATUSES.has(e.status);
            return {
                id:                envId,
                iconName:          'standard:email',
                typeLabel:         'エンベロープ',
                name:              e.email_subject || e.emailSubject || e.subject || e.name || e.envelope_name || '',
                statusLabel:       STATUS_LABEL[e.status] || e.status || '',
                recipient:         '未割り当て',
                lastModified:      this._formatDate(e.last_modified_date_time || e.lastModifiedDateTime || e.status_changed_date_time || e.statusChangedDateTime || e.created_date_time || e.createdDateTime || ''),
                isEditableEnvelope: isDraft,
                editUrl:           isDraft ? 'https://apps-d.docusign.com/send/documents/details/' + envId : ''
            };
        });
        return [...uploadItems, ...envelopeItems].sort((a, b) => {
            if (!a.lastModified && !b.lastModified) return 0;
            if (!a.lastModified) return 1;
            if (!b.lastModified) return -1;
            return b.lastModified.localeCompare(a.lastModified);
        });
    }

    get hasCombinedTasks() {
        return this.combinedTaskList.length > 0;
    }

    async handleRefreshTasks() {
        this.isLoading = true;
        this._clearMessages();
        try {
            const [tasks, envelopes] = await Promise.all([
                getWorkspaceUploadRequests({ workspaceId: this.workspaceId }),
                getWorkspaceEnvelopes({ workspaceId: this.workspaceId })
            ]);
            this.workspaceTasks     = this._mapTasks(Array.isArray(tasks) ? tasks : []);
            this.workspaceEnvelopes = Array.isArray(envelopes) ? envelopes : [];
        } catch (e) {
            this._setError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Upload request user selection ─────────────────────────────────────────

    get uploadRequestUserOptions() {
        const opts = [{ label: 'ワークスペースユーザーから選択...', value: '' }];
        (this.workspaceUsers || []).forEach(u => {
            const name = ((u.first_name || '') + ' ' + (u.last_name || '')).trim();
            opts.push({ label: name + (u.email ? '  (' + u.email + ')' : ''), value: u.user_id || '' });
        });
        return opts;
    }

    get isUploadRequestUserSelected() {
        return !!this.selectedUploadRequestUserId;
    }

    handleUploadRequestUserSelect(evt) {
        const userId = evt.detail.value;
        this.selectedUploadRequestUserId = userId;
        if (userId) {
            const user = (this.workspaceUsers || []).find(u => u.user_id === userId);
            if (user) {
                this.uploadRequestFirstName = user.first_name || '';
                this.uploadRequestLastName  = user.last_name  || '';
                this.uploadRequestEmail     = user.email      || '';
            }
        } else {
            this.uploadRequestFirstName = '';
            this.uploadRequestLastName  = '';
            this.uploadRequestEmail     = '';
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    _mapTasks(tasks) {
        return tasks.map(t => {
            const assignments = Array.isArray(t.assignments) ? t.assignments : [];
            const assignee = assignments.find(a => a.upload_request_responsibility_type_id === 'assignee');
            return {
                ...t,
                assigneeEmail:  assignee ? (assignee.email || '') : '',
                assigneeName:   assignee ? ((assignee.first_name || '') + ' ' + (assignee.last_name || '')).trim() : ''
            };
        });
    }

    _formatDate(dateStr) {
        if (!dateStr) return '';
        try {
            return new Date(dateStr).toLocaleString('ja-JP', {
                year: 'numeric', month: '2-digit', day: '2-digit',
                hour: '2-digit', minute: '2-digit'
            });
        } catch (e) {
            return dateStr;
        }
    }

    _clearMessages() {
        this.errorMessage   = '';
        this.successMessage = '';
    }

    _setSuccess(msg) {
        this.successMessage = msg;
        this.errorMessage   = '';
        this.dispatchEvent(new ShowToastEvent({ title: '成功', message: msg, variant: 'success' }));
    }

    _setError(errOrMsg) {
        const msg = typeof errOrMsg === 'string'
            ? errOrMsg
            : (errOrMsg?.body?.message || errOrMsg?.message || '不明なエラーが発生しました。');
        this.errorMessage   = msg;
        this.successMessage = '';
        this.dispatchEvent(new ShowToastEvent({ title: 'エラー', message: msg, variant: 'error' }));
    }
}
