import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRecordFiles from '@salesforce/apex/NavigatorAgreementUploadController.getRecordFiles';
import uploadToNavigator from '@salesforce/apex/NavigatorAgreementUploadController.uploadToNavigator';

export default class NavigatorAgreementUploader extends LightningElement {
    @api recordId; // 配置先レコードID（自動的に渡される）

    @track fileOptions = [];
    @track selectedDocumentId;
    @track isLoading = false;
    @track successMessage = '';
    @track errorMessage = '';

    wiredFilesResult;

    @wire(getRecordFiles, { recordId: '$recordId' })
    wiredFiles(result) {
        this.wiredFilesResult = result;
        const { error, data } = result;

        if (data) {
            this.fileOptions = data.map(file => ({
                label: `${file.title}.${file.fileExtension} (${this.formatFileSize(file.fileSize)})`,
                value: file.documentId
            }));
            this.errorMessage = '';
        } else if (error) {
            this.errorMessage = 'ファイルの取得に失敗しました: ' + this.getErrorMessage(error);
            this.fileOptions = [];
        }
    }

    get hasFiles() {
        return this.fileOptions && this.fileOptions.length > 0;
    }

    get isButtonDisabled() {
        return !this.selectedDocumentId || this.isLoading;
    }

    handleFileChange(event) {
        this.selectedDocumentId = event.detail.value;
        this.clearMessages();
    }

    async handleUpload() {
        if (!this.selectedDocumentId) {
            this.errorMessage = 'アップロードするファイルを選択してください。';
            return;
        }

        this.isLoading = true;
        this.clearMessages();

        try {
            const jobId = await uploadToNavigator({
                recordId: this.recordId,
                contentDocumentId: this.selectedDocumentId
            });

            this.successMessage = `Navigatorへのアップロードを開始しました。ジョブID: ${jobId}`;
            this.showToast('アップロード完了', 'DocuSign Navigatorにドキュメントを登録しました', 'success');

            this.selectedDocumentId = null;
            await refreshApex(this.wiredFilesResult);

        } catch (error) {
            this.errorMessage = 'アップロードエラー: ' + this.getErrorMessage(error);
            this.showToast('エラー', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.selectedDocumentId = null;
        this.clearMessages();
    }

    clearMessages() {
        this.successMessage = '';
        this.errorMessage = '';
    }

    formatFileSize(bytes) {
        if (!bytes || bytes === 0) return '0 B';
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / 1048576).toFixed(1) + ' MB';
    }

    getErrorMessage(error) {
        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            }
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
        }
        return error.message || 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }
}
