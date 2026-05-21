public with sharing class ContractBulkSendController {

    private static final String TEMPLATE_ID = '6eed9b4d-ef60-437f-beaa-f852d61e2ac7';

    @AuraEnabled(cacheable=true)
    public static List<Contract> getContracts() {
        return [
            SELECT Id, ContractNumber, StartDate, EndDate, ContractTerm,
                   CustomerSignedId, CustomerSigned.Name, CustomerSigned.Email,
                   BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry, Status
            FROM Contract
            ORDER BY ContractNumber ASC
        ];
    }

    @AuraEnabled
    public static List<Map<String, Object>> sendEnvelopes(List<Id> contractIds) {
        List<Contract> contracts = [
            SELECT Id, ContractNumber, StartDate, EndDate,
                   CustomerSignedId, CustomerSigned.Name, CustomerSigned.Email,
                   BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry
            FROM Contract
            WHERE Id IN :contractIds
        ];

        List<Map<String, Object>> results = new List<Map<String, Object>>();

        for (Contract c : contracts) {
            Map<String, Object> result = new Map<String, Object>();
            result.put('contractId', c.Id);
            result.put('contractNumber', c.ContractNumber);

            try {
                dfsle.UUID templateUUID = dfsle.UUID.parse(TEMPLATE_ID);
                dfsle.Template tmpl = dfsle.Template.fromId(templateUUID);

                String billingAddress = buildAddress(c);
                String startDateStr = c.StartDate != null ? String.valueOf(c.StartDate) : '';
                String endDateStr   = c.EndDate   != null ? String.valueOf(c.EndDate)   : '';

                // Tab values to merge into template fields
                List<dfsle.Tab> tabs = new List<dfsle.Tab>{
                    new dfsle.Tab(null, null, 'Address',   billingAddress, null, null, null, null, null, null, null, null),
                    new dfsle.Tab(null, null, 'StartDate', startDateStr,   null, null, null, null, null, null, null, null),
                    new dfsle.Tab(null, null, 'EndDate',   endDateStr,     null, null, null, null, null, null, null, null)
                };

                dfsle.Recipient signer = dfsle.Recipient.newEmbeddedSigner()
                    .withName(c.CustomerSigned != null ? c.CustomerSigned.Name : '')
                    .withEmail(c.CustomerSigned != null ? c.CustomerSigned.Email : '')
                    .withTabs(tabs);

                dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(
                    new dfsle.Entity(c.Id)
                ).withTemplates(new List<dfsle.Template>{ tmpl })
                 .withRecipients(new List<dfsle.Recipient>{ signer });

                envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);

                result.put('status', 'Sent');
                result.put('envelopeId', String.valueOf(envelope.docuSignId));
            } catch (Exception e) {
                result.put('status', 'Error');
                result.put('errorMessage', e.getMessage());
            }

            results.add(result);
        }

        return results;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getEnvelopeStatuses(List<Id> contractIds) {
        List<dfsle__EnvelopeStatus__c> statuses = [
            SELECT Id, dfsle__SourceId__c, dfsle__Status__c,
                   dfsle__Sent__c, dfsle__DocuSignId__c
            FROM dfsle__EnvelopeStatus__c
            WHERE dfsle__SourceId__c IN :contractIds
            ORDER BY dfsle__Sent__c DESC
        ];

        // Keep only the latest status per contract
        Map<Id, dfsle__EnvelopeStatus__c> latestByContract = new Map<Id, dfsle__EnvelopeStatus__c>();
        for (dfsle__EnvelopeStatus__c s : statuses) {
            Id srcId = (Id) s.dfsle__SourceId__c;
            if (!latestByContract.containsKey(srcId)) {
                latestByContract.put(srcId, s);
            }
        }

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Id contractId : latestByContract.keySet()) {
            dfsle__EnvelopeStatus__c s = latestByContract.get(contractId);
            Map<String, Object> row = new Map<String, Object>();
            row.put('contractId', contractId);
            row.put('envelopeStatus', s.dfsle__Status__c);
            row.put('sentDate', s.dfsle__Sent__c);
            row.put('envelopeId', s.dfsle__DocuSignId__c);
            results.add(row);
        }

        return results;
    }

    private static String buildAddress(Contract c) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(c.BillingStreet))     parts.add(c.BillingStreet);
        if (String.isNotBlank(c.BillingCity))       parts.add(c.BillingCity);
        if (String.isNotBlank(c.BillingState))      parts.add(c.BillingState);
        if (String.isNotBlank(c.BillingPostalCode)) parts.add(c.BillingPostalCode);
        if (String.isNotBlank(c.BillingCountry))    parts.add(c.BillingCountry);
        return String.join(parts, ', ');
    }
}
