declare module "@salesforce/apex/NavigatorController.searchAgreements" {
  export default function searchAgreements(param: {partyName: any, status: any, documentType: any, title: any, expirationDateFrom: any, expirationDateTo: any, effectiveDateFrom: any, effectiveDateTo: any, sourceName: any, maxResults: any}): Promise<any>;
}
declare module "@salesforce/apex/NavigatorController.getAgreementDetail" {
  export default function getAgreementDetail(param: {agreementId: any}): Promise<any>;
}
declare module "@salesforce/apex/NavigatorController.generateSummary" {
  export default function generateSummary(param: {agreementId: any}): Promise<any>;
}
