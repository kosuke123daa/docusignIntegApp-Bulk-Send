public with sharing class NavigatorController {

    @AuraEnabled(cacheable=false)
    public static String searchAgreements(
        String partyName,
        String status,
        String documentType,
        String title,
        String expirationDateFrom,
        String expirationDateTo,
        String effectiveDateFrom,
        String effectiveDateTo,
        String sourceName,
        Integer maxResults
    ) {
        try {
            NavigatorService.Config cfg = NavigatorService.loadConfig();
            String accessToken          = NavigatorService.getAccessToken(cfg);
            String baseUrl              = NavigatorService.getAgreementsBaseUrl(cfg.accountId);

            NavigatorService.ListParams lp = new NavigatorService.ListParams();
            lp.partyName          = partyName;
            lp.status             = status;
            lp.documentType       = documentType;
            lp.title              = title;
            lp.expirationDateFrom = expirationDateFrom;
            lp.expirationDateTo   = expirationDateTo;
            lp.effectiveDateFrom  = effectiveDateFrom;
            lp.effectiveDateTo    = effectiveDateTo;
            lp.sourceName         = sourceName;
            lp.maxResults         = maxResults;

            HttpResponse res = NavigatorService.callGet(NavigatorService.buildListUrl(baseUrl, lp), accessToken);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'Navigator API エラー: HTTP ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }
            return res.getBody();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getAgreementDetail(String agreementId) {
        try {
            NavigatorService.Config cfg = NavigatorService.loadConfig();
            String accessToken          = NavigatorService.getAccessToken(cfg);
            String baseUrl              = NavigatorService.getAgreementsBaseUrl(cfg.accountId);

            HttpResponse res = NavigatorService.callGet(baseUrl + '/' + agreementId, accessToken);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'Navigator API エラー: HTTP ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }
            return res.getBody();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String generateSummary(String agreementId) {
        try {
            NavigatorService.Config cfg = NavigatorService.loadConfig();
            String accessToken          = NavigatorService.getAccessToken(cfg);
            String baseUrl              = NavigatorService.getAgreementsBaseUrl(cfg.accountId);

            HttpResponse res = NavigatorService.callPost(
                baseUrl + '/' + agreementId + '/ai/actions/summarize', accessToken, '{}'
            );
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'AI要約生成エラー: HTTP ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }
            return res.getBody();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
