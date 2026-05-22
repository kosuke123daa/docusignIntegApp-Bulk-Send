import { LightningElement, track } from 'lwc';
import searchAgreements from '@salesforce/apex/NavigatorController.searchAgreements';
import getAgreementDetail from '@salesforce/apex/NavigatorController.getAgreementDetail';
import generateSummary from '@salesforce/apex/NavigatorController.generateSummary';

const COLUMNS = [
    { label: 'タイトル',   fieldName: 'title',          type: 'text', wrapText: true },
    { label: '種別',       fieldName: 'type',            type: 'text' },
    { label: 'ステータス', fieldName: 'status',          type: 'text' },
    { label: '満了日',     fieldName: 'expirationDate',  type: 'text' },
    { label: '取引先',     fieldName: 'parties',         type: 'text', wrapText: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: '詳細を表示', name: 'view_detail' }]
        }
    }
];

const STATUS_OPTIONS = [
    { label: '（全て）',  value: '' },
    { label: 'COMPLETE',  value: 'COMPLETE' },
    { label: 'PENDING',   value: 'PENDING' },
    { label: 'INACTIVE',  value: 'INACTIVE' }
];

const PROVISION_LABELS = [
    { key: 'effective_date',                     label: '有効日' },
    { key: 'expiration_date',                    label: '満了日' },
    { key: 'execution_date',                     label: '締結日' },
    { key: 'term_length',                        label: '契約期間' },
    { key: 'total_agreement_value',              label: '契約総額' },
    { key: 'annual_agreement_value',             label: '年間契約額' },
    { key: 'renewal_type',                       label: '更新タイプ' },
    { key: 'renewal_notice_date',                label: '更新通知日' },
    { key: 'renewal_notice_period',              label: '更新通知期間' },
    { key: 'auto_renewal_term_length',           label: '自動更新期間' },
    { key: 'governing_law',                      label: '準拠法' },
    { key: 'jurisdiction',                       label: '裁判管轄' },
    { key: 'payment_terms_due_date',             label: '支払期限' },
    { key: 'liability_cap_fixed_amount',         label: '責任制限額' },
    { key: 'assignment_type',                    label: '譲渡タイプ' },
    { key: 'termination_period_for_cause',       label: '有因解除期間' },
    { key: 'termination_period_for_convenience', label: '便宜解除期間' }
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
    @track selectedAgreement  = null;
    isLoading                 = false;
    isSummaryLoading          = false;
    errorMessage              = '';
    summary                   = '';
    searched                  = false;

    columns       = COLUMNS;
    statusOptions = STATUS_OPTIONS;

    // ── Getters ───────────────────────────────────────────────────────────────

    get hasResults()    { return this.tableRows.length > 0; }
    get showNoResults() { return this.searched && !this.isLoading && this.tableRows.length === 0 && !this.errorMessage; }
    get resultSummary() { return this.tableRows.length + '件の文書が見つかりました。'; }

    get detailTopFields() {
        if (!this.selectedAgreement) return [];
        const doc = this.selectedAgreement;
        return [
            { label: 'タイトル',   value: doc.title       || '' },
            { label: '種別',       value: doc.type        || '' },
            { label: 'カテゴリ',   value: doc.category    || '' },
            { label: 'ステータス', value: doc.status      || '' },
            { label: '取込元',     value: doc.source_name || '' },
            { label: '文書ID',     value: doc.id          || '' }
        ].filter(f => f.value !== '');
    }

    get detailParties() {
        if (!this.selectedAgreement) return [];
        return (this.selectedAgreement.parties || []).map(p => ({
            name: p.name_in_agreement || '',
            role: p.role              || '',
            type: p.party_type        || ''
        }));
    }

    get detailProvisions() {
        if (!this.selectedAgreement || !this.selectedAgreement.provisions) return [];
        const prov = this.selectedAgreement.provisions;
        return PROVISION_LABELS
            .filter(f => prov[f.key] != null && prov[f.key] !== '')
            .map(f    => ({ label: f.label, value: String(prov[f.key]) }));
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleInputChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this[field] = field === 'maxResults' ? (parseInt(value, 10) || 20) : value;
    }

    async handleSearch() {
        this.isLoading        = true;
        this.errorMessage     = '';
        this.tableRows        = [];
        this.selectedAgreement = null;
        this.summary           = '';
        this.searched          = false;

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
        this.selectedAgreement  = null;
        this.summary            = '';
        this.errorMessage       = '';
        this.searched           = false;
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'view_detail') return;
        const agreementId = event.detail.row.id;

        this.isLoading        = true;
        this.errorMessage     = '';
        this.selectedAgreement = null;
        this.summary           = '';

        try {
            const raw              = await getAgreementDetail({ agreementId });
            this.selectedAgreement = JSON.parse(raw);
        } catch (e) {
            this.errorMessage = this._extractError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateSummary() {
        if (!this.selectedAgreement) return;
        this.isSummaryLoading = true;
        this.errorMessage     = '';
        this.summary          = '';

        try {
            const raw  = await generateSummary({ agreementId: this.selectedAgreement.id });
            const data = JSON.parse(raw);
            this.summary = data.summary || raw;
        } catch (e) {
            this.errorMessage = this._extractError(e);
        } finally {
            this.isSummaryLoading = false;
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    _flattenAgreements(rawList) {
        return rawList.map(doc => ({
            id:             doc.id    || '',
            title:          doc.title || '（タイトルなし）',
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
