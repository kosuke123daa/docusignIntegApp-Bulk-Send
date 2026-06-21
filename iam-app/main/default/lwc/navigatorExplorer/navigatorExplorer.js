import { LightningElement, track } from 'lwc';
import searchAgreements from '@salesforce/apex/NavigatorController.searchAgreements';

const AGREEMENT_MANAGER_BASE_URL = 'https://apps-d.docusign.com/send/agreement-manager/agreements/';

const COLUMNS = [
    {
        label: 'タイトル',
        fieldName: 'agreementUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'title' }, target: '_blank' },
        wrapText: true
    },
    { label: '種別',       fieldName: 'type',            type: 'text' },
    { label: 'ステータス', fieldName: 'status',          type: 'text' },
    { label: '満了日',     fieldName: 'expirationDate',  type: 'text' },
    { label: '取引先',     fieldName: 'parties',         type: 'text', wrapText: true }
];

const STATUS_OPTIONS = [
    { label: '（全て）',  value: '' },
    { label: 'COMPLETE',  value: 'COMPLETE' },
    { label: 'PENDING',   value: 'PENDING' },
    { label: 'INACTIVE',  value: 'INACTIVE' }
];

export default class NavigatorExplorer extends LightningElement {
    // Search inputs
    partyName         = '';
    status            = '';
    documentType      = '';
    title             = '';
    expirationDateFrom = '';
    expirationDateTo   = '';
    effectiveDateFrom  = '';
    effectiveDateTo    = '';
    maxResults         = 20;

    // State
    @track tableRows          = [];
    isLoading                 = false;
    errorMessage              = '';
    searched                  = false;

    columns       = COLUMNS;
    statusOptions = STATUS_OPTIONS;

    // ── Getters ───────────────────────────────────────────────────────────────

    get hasResults()    { return this.tableRows.length > 0; }
    get showNoResults() { return this.searched && !this.isLoading && this.tableRows.length === 0 && !this.errorMessage; }
    get resultSummary() { return this.tableRows.length + '件の文書が見つかりました。'; }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleInputChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this[field] = field === 'maxResults' ? (parseInt(value, 10) || 20) : value;
    }

    async handleSearch() {
        this.isLoading    = true;
        this.errorMessage = '';
        this.tableRows    = [];
        this.searched     = false;

        try {
            const raw = await searchAgreements({
                partyName:          this.partyName          || null,
                status:             this.status             || null,
                documentType:       this.documentType       || null,
                title:              this.title              || null,
                expirationDateFrom: this.expirationDateFrom || null,
                expirationDateTo:   this.expirationDateTo   || null,
                effectiveDateFrom:  this.effectiveDateFrom  || null,
                effectiveDateTo:    this.effectiveDateTo    || null,
                sourceName:         null,
                maxResults:         this.maxResults
            });
            const data    = JSON.parse(raw);
            this.tableRows = this._flattenAgreements(data.data || []);
        } catch (e) {
            this.errorMessage = this._extractError(e);
        } finally {
            this.isLoading = false;
            this.searched  = true;
        }
    }

    handleClear() {
        this.partyName          = '';
        this.status             = '';
        this.documentType       = '';
        this.title              = '';
        this.expirationDateFrom = '';
        this.expirationDateTo   = '';
        this.effectiveDateFrom  = '';
        this.effectiveDateTo    = '';
        this.maxResults         = 20;
        this.tableRows          = [];
        this.errorMessage       = '';
        this.searched           = false;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    _flattenAgreements(rawList) {
        return rawList.map(doc => ({
            id:             doc.id    || '',
            title:          doc.title || doc.file_name || '（タイトルなし）',
            agreementUrl:   doc.id ? (AGREEMENT_MANAGER_BASE_URL + doc.id) : '',
            type:           doc.type  || '',
            status:         doc.status || '',
            expirationDate: (doc.provisions && doc.provisions.expiration_date) || '',
            parties:        (doc.parties || [])
                                .map(p => p.name_in_agreement)
                                .filter(Boolean)
                                .join(' / ')
        }));
    }

    _extractError(e) {
        if (e && e.body && e.body.message) return e.body.message;
        if (e && e.message)               return e.message;
        return '不明なエラーが発生しました。';
    }
}
