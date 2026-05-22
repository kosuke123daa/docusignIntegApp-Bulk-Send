import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOpportunityPDFFiles from '@salesforce/apex/DocuSignEnvelopeController.getOpportunityPDFFiles';
import sendDocuSignEnvelope from '@salesforce/apex/DocuSignEnvelopeController.sendDocuSignEnvelope';

export default class DocusignSenderComponent extends LightningElement {
    @api recordId; // 商談レコードID（自動的に渡される）
    
    @track fileOptions = [];
    @track selectedDocumentId;
    @track recipientName = '';
    @track recipientEmail = '';
    @track isLoading = false;
    @track successMessage = '';
    @track errorMessage = '';
    
    wiredFilesResult;
    
    /**
     * 商談に添付されているPDFファイル一覧を取得
     */
    @wire(getOpportunityPDFFiles, { recordId: '$recordId' })
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
            this.errorMessage = 'PDFファイルの取得に失敗しました: ' + this.getErrorMessage(error);
            this.fileOptions = [];
        }
    }
    
    /**
     * PDFファイルが存在するかチェック
     */
    get hasPDFFiles() {
        return this.fileOptions && this.fileOptions.length > 0;
    }
    
    /**
     * 送信ボタンの有効/無効判定
     */
    get isButtonDisabled() {
        return !this.selectedDocumentId || 
               !this.recipientName || 
               !this.recipientEmail || 
               this.isLoading ||
               !this.isValidEmail(this.recipientEmail);
    }
    
    /**
     * PDFファイル選択時のハンドラー
     */
    handleFileChange(event) {
        this.selectedDocumentId = event.detail.value;
        this.clearMessages();
    }
    
    /**
     * 受信者名入力時のハンドラー
     */
    handleNameChange(event) {
        this.recipientName = event.detail.value;
        this.clearMessages();
    }
    
    /**
     * 受信者メールアドレス入力時のハンドラー
     */
    handleEmailChange(event) {
        this.recipientEmail = event.detail.value;
        this.clearMessages();
    }
    
    /**
     * DocuSignエンベロープ送信処理
     */
    async handleSendEnvelope() {
        // バリデーション
        if (!this.validateInputs()) {
            return;
        }
        
        this.isLoading = true;
        this.clearMessages();
        
        try {
            const envelopeId = await sendDocuSignEnvelope({
                recordId: this.recordId,
                documentId: this.selectedDocumentId,
                recipientEmail: this.recipientEmail,
                recipientName: this.recipientName
            });
            
            // 成功メッセージ
            this.successMessage = `DocuSign署名依頼を送信しました！\nエンベロープID: ${envelopeId}`;
            
            // トーストメッセージ表示
            this.showToast(
                '送信完了',
                `${this.recipientName} 様に署名依頼を送信しました`,
                'success'
            );
            
            // フォームをリセット
            this.resetForm();
            
            // PDFファイル一覧を再読み込み
            await refreshApex(this.wiredFilesResult);
            
        } catch (error) {
            this.errorMessage = 'エンベロープ送信エラー: ' + this.getErrorMessage(error);
            
            this.showToast(
                'エラー',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * キャンセルボタンのハンドラー
     */
    handleCancel() {
        this.resetForm();
        this.clearMessages();
    }
    
    /**
     * 入力値のバリデーション
     */
    validateInputs() {
        if (!this.selectedDocumentId) {
            this.errorMessage = 'PDFファイルを選択してください。';
            return false;
        }
        
        if (!this.recipientName || this.recipientName.trim().length === 0) {
            this.errorMessage = '受信者名を入力してください。';
            return false;
        }
        
        if (!this.recipientEmail || !this.isValidEmail(this.recipientEmail)) {
            this.errorMessage = '有効なメールアドレスを入力してください。';
            return false;
        }
        
        return true;
    }
    
    /**
     * メールアドレス形式チェック
     */
    isValidEmail(email) {
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailPattern.test(email);
    }
    
    /**
     * フォームをリセット
     */
    resetForm() {
        this.selectedDocumentId = null;
        this.recipientName = '';
        this.recipientEmail = '';
    }
    
    /**
     * メッセージをクリア
     */
    clearMessages() {
        this.successMessage = '';
        this.errorMessage = '';
    }
    
    /**
     * ファイルサイズを読みやすい形式に変換
     */
    formatFileSize(bytes) {
        if (!bytes || bytes === 0) return '0 B';
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / 1048576).toFixed(1) + ' MB';
    }
    
    /**
     * エラーメッセージを取得
     */
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
    
    /**
     * トーストメッセージを表示
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}