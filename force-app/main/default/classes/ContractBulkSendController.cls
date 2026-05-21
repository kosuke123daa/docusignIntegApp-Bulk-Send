public with sharing class ContractBulkSendController {

    private static final String TEMPLATE_ID = '6eed9b4d-ef60-437f-beaa-f852d61e2ac7';
    private static final String TEMPLATE_NAME = '契約書テンプレート';
    private static final String SIGNER_ROLE = '契約者';

    @AuraEnabled(cacheable=true)
    public static List<ContractWrapper> getContracts() {
        List<Contract> contracts = [
            SELECT Id, ContractNumber, StartDate, EndDate, ContractTerm,
                   CustomerSignedId, CustomerSigned.Name, CustomerSigned.Email,
                   BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry, Status
            FROM Contract
            ORDER BY ContractNumber ASC
        ];

        Set<Id> contractIds = new Set<Id>();
        for (Contract c : contracts) {
            contractIds.add(c.Id);
        }

        Map<Id, dfsle.Envelope.Status> latestStatusMap = new Map<Id, dfsle.Envelope.Status>();
        if (!contractIds.isEmpty()) {
            try {
                List<dfsle.Envelope.Status> statuses = dfsle.StatusService.getStatus(
                    contractIds,
                    200
                );
                for (dfsle.Envelope.Status s : statuses) {
                    Id srcId = s.source != null ? s.source.id : null;
                    if (srcId != null && !latestStatusMap.containsKey(srcId)) {
                        latestStatusMap.put(srcId, s);
                    }
                }
            } catch (Exception ex) {
                // ステータス未取得でも一覧は表示する
            }
        }

        List<ContractWrapper> wrappers = new List<ContractWrapper>();
        for (Contract c : contracts) {
            ContractWrapper w = new ContractWrapper();
            w.Id            = c.Id;
            w.contractNumber = c.ContractNumber;
            w.startDate      = c.StartDate;
            w.endDate        = c.EndDate;
            w.contractTerm   = c.ContractTerm;
            w.signerName     = c.CustomerSigned != null ? c.CustomerSigned.Name  : '';
            w.signerEmail    = c.CustomerSigned != null ? c.CustomerSigned.Email : '';
            w.billingAddress = buildAddress(c);

            dfsle.Envelope.Status st = latestStatusMap.get(c.Id);
            w.envelopeStatus = st != null ? st.status : '未送信';
            w.envelopeSentDate = st != null ? st.sent : null;

            wrappers.add(w);
        }
        return wrappers;
    }

    @AuraEnabled
    public static List<SendResult> sendEnvelopes(List<Id> contractIds) {
        List<Contract> contracts = [
            SELECT Id, ContractNumber, StartDate, EndDate,
                   CustomerSignedId, CustomerSigned.Name, CustomerSigned.Email,
                   BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry
            FROM Contract
            WHERE Id IN :contractIds
        ];

        dfsle.UUID templateUUID = dfsle.UUID.parse(TEMPLATE_ID);
        List<SendResult> results = new List<SendResult>();

        for (Contract c : contracts) {
            SendResult r = new SendResult();
            r.contractId     = c.Id;
            r.contractNumber = c.ContractNumber;

            try {
                // (1) エンベロープ作成（契約レコードをソースとして紐付け）
                dfsle.Envelope myEnvelope = dfsle.EnvelopeService.getEmptyEnvelope(
                    new dfsle.Entity(c.Id)
                );

                // (2) テンプレートからドキュメント作成
                dfsle.Document myDocument = dfsle.Document.fromTemplate(
                    templateUUID,
                    TEMPLATE_NAME
                );
                myEnvelope = myEnvelope.withDocuments(
                    new List<dfsle.Document>{ myDocument }
                );

                // (3) テンプレートフィールドにSalesforceデータを差し込む（Tabとして受信者に設定）
                String billingAddress = buildAddress(c);
                String startDateStr   = c.StartDate != null ? String.valueOf(c.StartDate) : '';
                String endDateStr     = c.EndDate   != null ? String.valueOf(c.EndDate)   : '';

                dfsle.Tab addressTab  = new dfsle.TextTab().withValue(billingAddress);
                dfsle.Tab startDateTab = new dfsle.TextTab().withValue(startDateStr);
                dfsle.Tab endDateTab  = new dfsle.TextTab().withValue(endDateStr);

                // (4) 受信者（顧客調印者）を設定
                // fromSource: name, email, phone, roleName（テンプレートのロール名と一致させること）, entity
                dfsle.Recipient myRecipient = dfsle.Recipient.fromSource(
                    c.CustomerSigned != null ? c.CustomerSigned.Name  : '',
                    c.CustomerSigned != null ? c.CustomerSigned.Email : '',
                    null,
                    SIGNER_ROLE,
                    new dfsle.Entity(c.CustomerSignedId)
                ).withTabs(new List<dfsle.Tab>{ addressTab, startDateTab, endDateTab });

                myEnvelope = myEnvelope.withRecipients(
                    new List<dfsle.Recipient>{ myRecipient }
                );

                // (5) 即時送信
                myEnvelope = dfsle.EnvelopeService.sendEnvelope(myEnvelope, true);

                r.status     = 'Sent';
                r.envelopeId = myEnvelope.docuSignId != null
                    ? String.valueOf(myEnvelope.docuSignId)
                    : '';
            } catch (Exception ex) {
                r.status       = 'Error';
                r.errorMessage = ex.getMessage();
            }

            results.add(r);
        }

        return results;
    }

    @AuraEnabled
    public static List<StatusWrapper> getEnvelopeStatuses(List<Id> contractIds) {
        List<dfsle.Envelope.Status> statuses = dfsle.StatusService.getStatus(
            new Set<Id>(contractIds),
            contractIds.size() * 3
        );

        Map<Id, dfsle.Envelope.Status> latestByContract = new Map<Id, dfsle.Envelope.Status>();
        for (dfsle.Envelope.Status s : statuses) {
            Id srcId = s.source != null ? s.source.id : null;
            if (srcId != null && !latestByContract.containsKey(srcId)) {
                latestByContract.put(srcId, s);
            }
        }

        List<StatusWrapper> results = new List<StatusWrapper>();
        for (Id cId : latestByContract.keySet()) {
            dfsle.Envelope.Status s = latestByContract.get(cId);
            StatusWrapper sw = new StatusWrapper();
            sw.contractId     = cId;
            sw.envelopeStatus = s.status;
            sw.sentDate       = s.sent;
            sw.envelopeId     = s.docuSignId != null ? String.valueOf(s.docuSignId) : '';
            results.add(sw);
        }
        return results;
    }

    private static String buildAddress(Contract c) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(c.BillingPostalCode)) parts.add(c.BillingPostalCode);
        if (String.isNotBlank(c.BillingState))      parts.add(c.BillingState);
        if (String.isNotBlank(c.BillingCity))       parts.add(c.BillingCity);
        if (String.isNotBlank(c.BillingStreet))     parts.add(c.BillingStreet);
        if (String.isNotBlank(c.BillingCountry))    parts.add(c.BillingCountry);
        return String.join(parts, ' ');
    }

    public class ContractWrapper {
        @AuraEnabled public Id     Id              { get; set; }
        @AuraEnabled public String contractNumber  { get; set; }
        @AuraEnabled public Date   startDate       { get; set; }
        @AuraEnabled public Date   endDate         { get; set; }
        @AuraEnabled public Integer contractTerm   { get; set; }
        @AuraEnabled public String signerName      { get; set; }
        @AuraEnabled public String signerEmail     { get; set; }
        @AuraEnabled public String billingAddress  { get; set; }
        @AuraEnabled public String envelopeStatus  { get; set; }
        @AuraEnabled public Datetime envelopeSentDate { get; set; }
    }

    public class SendResult {
        @AuraEnabled public Id     contractId     { get; set; }
        @AuraEnabled public String contractNumber { get; set; }
        @AuraEnabled public String status         { get; set; }
        @AuraEnabled public String envelopeId     { get; set; }
        @AuraEnabled public String errorMessage   { get; set; }
    }

    public class StatusWrapper {
        @AuraEnabled public Id       contractId     { get; set; }
        @AuraEnabled public String   envelopeStatus { get; set; }
        @AuraEnabled public Datetime sentDate       { get; set; }
        @AuraEnabled public String   envelopeId     { get; set; }
    }
}
