import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAgreementsForRecord from '@salesforce/apex/RecordAgreementsController.getAgreementsForRecord';
import uploadDocumentForRecord from '@salesforce/apex/RecordAgreementsController.uploadDocumentForRecord';

const AGREEMENT_MANAGER_BASE_URL = 'https://apps-d.docusign.com/send/agreement-manager/agreements/';
// LWC -> Apex の base64 受け渡しは Apex ヒープ(同期6MB)に依存するため実用上 5MB に制限。
const MAX_FILE_BYTES = 5 * 1024 * 1024;

const COLUMNS = [
    {
        label: 'ファイル名',
        fieldName: 'agreementUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'fileName' }, target: '_blank' },
        wrapText: true
    },
    { label: '種別',       fieldName: 'type',         type: 'text' },
    { label: 'ステータス', fieldName: 'status',       type: 'text' },
    { label: '審査状況',   fieldName: 'reviewStatus', type: 'text' },
    { label: '取込元',     fieldName: 'sourceName',   type: 'text' },
    {
        label: '作成日時',
        fieldName: 'createdAt',
        type: 'date',
        typeAttributes: {
            year: 'numeric', month: 'short', day: '2-digit',
            hour: '2-digit', minute: '2-digit'
        }
    }
];

export default class RecordAgreements extends LightningElement {
    @api recordId;
    @api objectApiName;

    columns = COLUMNS;
    @track rows = [];
    isLoading = false;
    isUploading = false;
    errorMessage = '';
    selectedFile;
    selectedFileName;
    loaded = false;

    connectedCallback() {
        this.loadAgreements();
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get showEmpty() {
        return this.loaded && !this.isLoading && this.rows.length === 0 && !this.errorMessage;
    }

    get isUploadDisabled() {
        return this.isUploading || !this.selectedFile;
    }

    async loadAgreements() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const raw = await getAgreementsForRecord({ recordId: this.recordId });
            const data = JSON.parse(raw);
            this.rows = this._flatten(data.data || []);
        } catch (e) {
            this.errorMessage = this._extractError(e);
        } finally {
            this.isLoading = false;
            this.loaded = true;
        }
    }

    handleRefresh() {
        this.loadAgreements();
    }

    handleFileChange(event) {
        const files = event.target.files;
        this.selectedFile = files && files.length ? files[0] : undefined;
        this.selectedFileName = this.selectedFile ? this.selectedFile.name : undefined;
    }

    async handleUpload() {
        if (!this.selectedFile) {
            return;
        }
        if (this.selectedFile.size > MAX_FILE_BYTES) {
            this._toast('ファイルサイズ超過', 'アップロード可能なファイルは 5MB までです。', 'error');
            return;
        }
        this.isUploading = true;
        try {
            const base64 = await this._toBase64(this.selectedFile);
            await uploadDocumentForRecord({
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                fileName: this.selectedFile.name,
                base64Data: base64
            });
            this._toast(
                'アップロード完了',
                'Agreement Manager に送信しました。AI抽出の完了後、一覧に表示されます。',
                'success'
            );
            this._resetFileInput();
            await this._delay(2000);
            await this.loadAgreements();
        } catch (e) {
            this._toast('アップロード失敗', this._extractError(e), 'error');
        } finally {
            this.isUploading = false;
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    _flatten(rawList) {
        return rawList.map((doc) => ({
            id: doc.id || '',
            fileName: doc.file_name || '（ファイル名なし）',
            agreementUrl: doc.id ? AGREEMENT_MANAGER_BASE_URL + doc.id : '',
            type: doc.type || '',
            status: doc.status || '',
            reviewStatus: doc.review_status || '',
            sourceName: doc.source_name || '',
            createdAt: (doc.metadata && doc.metadata.created_at) || null
        }));
    }

    _toBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result;
                resolve(result.substring(result.indexOf(',') + 1));
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    _resetFileInput() {
        this.selectedFile = undefined;
        this.selectedFileName = undefined;
        const input = this.template.querySelector('lightning-input[data-id="fileInput"]');
        if (input) {
            input.value = null;
        }
    }

    _delay(ms) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _extractError(e) {
        if (e && e.body && e.body.message) return e.body.message;
        if (e && e.message) return e.message;
        return '不明なエラーが発生しました。';
    }
}
