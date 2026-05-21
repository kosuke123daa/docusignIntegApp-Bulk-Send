import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContracts from '@salesforce/apex/ContractBulkSendController.getContracts';
import sendEnvelopes from '@salesforce/apex/ContractBulkSendController.sendEnvelopes';
import getEnvelopeStatuses from '@salesforce/apex/ContractBulkSendController.getEnvelopeStatuses';

const COLUMNS = [
    { label: '契約番号',              fieldName: 'contractNumber',  type: 'text',    sortable: true },
    { label: '契約開始日',            fieldName: 'startDate',       type: 'date',
      typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' } },
    { label: '契約終了日',            fieldName: 'endDate',         type: 'date',
      typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' } },
    { label: '契約期間（月）',         fieldName: 'contractTerm',    type: 'number' },
    { label: '顧客調印者',            fieldName: 'signerName',      type: 'text' },
    { label: 'メール',               fieldName: 'signerEmail',     type: 'email' },
    { label: '請求先住所',            fieldName: 'billingAddress',  type: 'text' },
    {
        label: 'エンベロープステータス',
        fieldName: 'envelopeStatus',
        type: 'text',
        cellAttributes: { class: { fieldName: 'statusClass' } }
    },
    {
        label: '送信日時',
        fieldName: 'envelopeSentDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit',
                          hour: '2-digit', minute: '2-digit' }
    }
];

export default class ContractBulkSend extends LightningElement {
    @track tableData    = [];
    @track selectedRowIds = [];
    @track sendResults  = null;
    @track isLoading    = false;
    @track errorMessage = null;

    columns  = COLUMNS;
    maxRows  = 99;

    _rawData = [];

    @wire(getContracts)
    wiredContracts({ error, data }) {
        if (data) {
            this._rawData = data;
            this.tableData = data.map(row => this._addStatusClass(row));
        } else if (error) {
            this.errorMessage = this._extractError(error);
        }
    }

    _addStatusClass(row) {
        return Object.assign({}, row, {
            statusClass: this._calcStatusClass(row.envelopeStatus)
        });
    }

    _calcStatusClass(status) {
        if (!status || status === '未送信') return 'slds-text-color_weak';
        const s = (status || '').toLowerCase();
        if (s === 'completed')             return 'slds-text-color_success';
        if (s === 'sent' || s === 'delivered') return '';
        if (s === 'voided' || s === 'declined') return 'slds-text-color_error';
        return '';
    }

    handleRowSelection(event) {
        this.selectedRowIds = event.detail.selectedRows.map(r => r.Id);
        this.sendResults    = null;
        this.errorMessage   = null;
    }

    get selectedCount()  { return this.selectedRowIds.length; }
    get isSendDisabled() { return this.isLoading || this.selectedRowIds.length === 0; }
    get hasSendResults() { return this.sendResults && this.sendResults.length > 0; }

    async handleSend() {
        if (this.selectedRowIds.length === 0) return;
        this.isLoading    = true;
        this.sendResults  = null;
        this.errorMessage = null;

        try {
            const raw = await sendEnvelopes({ contractIds: this.selectedRowIds });
            this.sendResults = raw.map(r => ({
                contractId:     r.contractId,
                contractNumber: r.contractNumber,
                status:         r.status,
                detail:         r.envelopeId || r.errorMessage || '',
                statusClass:    r.status === 'Sent' ? 'slds-text-color_success' : 'slds-text-color_error'
            }));

            await this._refreshStatuses();

            this.dispatchEvent(new ShowToastEvent({
                title:   '送信完了',
                message: 'エンベロープの送信処理が完了しました。',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this._extractError(error);
            this.dispatchEvent(new ShowToastEvent({
                title:   '送信エラー',
                message: this.errorMessage,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefreshStatus() {
        this.isLoading    = true;
        this.errorMessage = null;
        try {
            await this._refreshStatuses();
        } finally {
            this.isLoading = false;
        }
    }

    async _refreshStatuses() {
        if (this._rawData.length === 0) return;
        const allIds = this._rawData.map(r => r.Id);
        try {
            const statuses = await getEnvelopeStatuses({ contractIds: allIds });
            const statusMap = {};
            statuses.forEach(s => { statusMap[s.contractId] = s; });

            this.tableData = this._rawData.map(row => {
                const st = statusMap[row.Id];
                const updated = Object.assign({}, row, {
                    envelopeStatus:   st ? st.envelopeStatus : (row.envelopeStatus || '未送信'),
                    envelopeSentDate: st ? st.sentDate       : row.envelopeSentDate
                });
                return this._addStatusClass(updated);
            });
            this._rawData = this.tableData.map(r => Object.assign({}, r));
        } catch (error) {
            this.errorMessage = this._extractError(error);
        }
    }

    _extractError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message)                    return error.message;
        return JSON.stringify(error);
    }
}
