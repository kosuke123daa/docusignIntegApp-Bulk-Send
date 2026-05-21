import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContracts from '@salesforce/apex/ContractBulkSendController.getContracts';
import sendEnvelopes from '@salesforce/apex/ContractBulkSendController.sendEnvelopes';
import getEnvelopeStatuses from '@salesforce/apex/ContractBulkSendController.getEnvelopeStatuses';

const COLUMNS = [
    { label: '契約番号',   fieldName: 'ContractNumber', type: 'text', sortable: true },
    { label: '契約開始日', fieldName: 'StartDate',      type: 'date', typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' } },
    { label: '契約終了日', fieldName: 'EndDate',         type: 'date', typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' } },
    { label: '契約期間',   fieldName: 'ContractTerm',   type: 'number' },
    { label: '顧客調印者', fieldName: 'CustomerSignedName',  type: 'text' },
    { label: 'メール',     fieldName: 'CustomerSignedEmail', type: 'email' },
    { label: '請求先住所', fieldName: 'BillingAddressText',  type: 'text' },
    {
        label: 'エンベロープステータス',
        fieldName: 'envelopeStatus',
        type: 'text',
        cellAttributes: { class: { fieldName: 'statusClass' } }
    }
];

export default class ContractBulkSend extends LightningElement {
    @track tableData = [];
    @track selectedRowIds = [];
    @track sendResults = null;
    @track isLoading = false;
    @track errorMessage = null;

    columns = COLUMNS;
    hideCheckbox = false;
    draftValues = [];

    // Raw contract records from wire
    _contracts = [];
    // Envelope status map: contractId -> { envelopeStatus, envelopeId }
    _statusMap = {};

    @wire(getContracts)
    wiredContracts({ error, data }) {
        if (data) {
            this._contracts = data;
            this._buildTableData();
        } else if (error) {
            this.errorMessage = this._extractError(error);
        }
    }

    _buildTableData() {
        this.tableData = this._contracts.map(c => {
            const statusInfo = this._statusMap[c.Id] || {};
            const addressParts = [];
            if (c.BillingStreet)     addressParts.push(c.BillingStreet);
            if (c.BillingCity)       addressParts.push(c.BillingCity);
            if (c.BillingState)      addressParts.push(c.BillingState);
            if (c.BillingPostalCode) addressParts.push(c.BillingPostalCode);
            if (c.BillingCountry)    addressParts.push(c.BillingCountry);

            const status = statusInfo.envelopeStatus || '未送信';
            return {
                Id: c.Id,
                ContractNumber: c.ContractNumber,
                StartDate: c.StartDate,
                EndDate: c.EndDate,
                ContractTerm: c.ContractTerm,
                CustomerSignedName:  c.CustomerSigned ? c.CustomerSigned.Name  : '',
                CustomerSignedEmail: c.CustomerSigned ? c.CustomerSigned.Email : '',
                BillingAddressText: addressParts.join(', '),
                envelopeStatus: status,
                statusClass: this._statusClass(status)
            };
        });
    }

    _statusClass(status) {
        if (!status || status === '未送信') return 'slds-text-color_weak';
        const s = status.toLowerCase();
        if (s === 'completed') return 'slds-text-color_success';
        if (s === 'sent' || s === 'delivered') return 'slds-text-color_default';
        if (s === 'voided' || s === 'declined') return 'slds-text-color_error';
        return 'slds-text-color_default';
    }

    handleRowSelection(event) {
        this.selectedRowIds = event.detail.selectedRows.map(r => r.Id);
        this.sendResults = null;
    }

    get selectedCount() {
        return this.selectedRowIds.length;
    }

    get isSendDisabled() {
        return this.isLoading || this.selectedRowIds.length === 0;
    }

    async handleSend() {
        if (this.selectedRowIds.length === 0) return;
        this.isLoading = true;
        this.sendResults = null;
        this.errorMessage = null;

        try {
            const rawResults = await sendEnvelopes({ contractIds: this.selectedRowIds });
            this.sendResults = rawResults.map(r => ({
                contractId: r.contractId,
                contractNumber: r.contractNumber,
                status: r.status,
                detail: r.envelopeId || r.errorMessage || '',
                badgeClass: r.status === 'Sent' ? 'slds-badge_lightest' : 'slds-badge_error'
            }));

            // Refresh status after sending
            await this._loadStatuses();

            this.dispatchEvent(new ShowToastEvent({
                title: '送信完了',
                message: 'エンベロープの送信処理が完了しました。',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this._extractError(error);
            this.dispatchEvent(new ShowToastEvent({
                title: '送信エラー',
                message: this.errorMessage,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefreshStatus() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            await this._loadStatuses();
        } finally {
            this.isLoading = false;
        }
    }

    async _loadStatuses() {
        const allIds = this._contracts.map(c => c.Id);
        if (allIds.length === 0) return;
        try {
            const statuses = await getEnvelopeStatuses({ contractIds: allIds });
            this._statusMap = {};
            statuses.forEach(s => {
                this._statusMap[s.contractId] = s;
            });
            this._buildTableData();
        } catch (error) {
            this.errorMessage = this._extractError(error);
        }
    }

    _extractError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return JSON.stringify(error);
    }
}
