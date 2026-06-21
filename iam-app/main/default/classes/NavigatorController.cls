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
        String category,
        String reviewStatus,
        String language,
        Integer maxResults
    ) {
        try {
            NavigatorService.Config cfg = NavigatorService.loadConfig();
            String accessToken          = NavigatorService.getAccessToken(cfg);
            String baseUrl              = NavigatorService.getAgreementsBaseUrl(cfg.accountId);

            Integer wantedResults = (maxResults != null) ? maxResults : 20;
            Boolean hasTextFilter = String.isNotBlank(partyName) || String.isNotBlank(documentType)
                || String.isNotBlank(title) || String.isNotBlank(sourceName)
                || String.isNotBlank(category) || String.isNotBlank(reviewStatus)
                || String.isNotBlank(language);

            // 部分一致検索のため、テキストフィルターが指定されている場合は多めに取得してから
            // Apex側で contains 判定を行う（Navigator APIの $filter は完全一致 / 前方一致のため）。
            NavigatorService.ListParams lp = new NavigatorService.ListParams();
            lp.status             = status;
            lp.expirationDateFrom = expirationDateFrom;
            lp.expirationDateTo   = expirationDateTo;
            lp.effectiveDateFrom  = effectiveDateFrom;
            lp.effectiveDateTo    = effectiveDateTo;
            lp.maxResults         = hasTextFilter ? Math.min(100, Math.max(wantedResults * 5, 50)) : wantedResults;

            HttpResponse res = NavigatorService.callGet(NavigatorService.buildListUrl(baseUrl, lp), accessToken);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new AuraHandledException(
                    'Navigator API エラー: HTTP ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }

            if (!hasTextFilter) {
                return res.getBody();
            }

            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> rawList     = (List<Object>) root.get('data');
            List<Object> filtered    = new List<Object>();

            if (rawList != null) {
                for (Object o : rawList) {
                    Map<String, Object> doc = (Map<String, Object>) o;
                    if (!matchesTitle(doc, title))                                       continue;
                    if (!containsIgnoreCase((String) doc.get('type'), documentType))    continue;
                    if (!containsIgnoreCase((String) doc.get('category'), category))    continue;
                    if (!containsIgnoreCase((String) doc.get('review_status'), reviewStatus)) continue;
                    if (!containsIgnoreCase((String) doc.get('source_name'), sourceName))     continue;
                    if (!matchesParty(doc, partyName))      continue;
                    if (!matchesLanguage(doc, language))    continue;

                    filtered.add(doc);
                    if (filtered.size() >= wantedResults) break;
                }
            }

            return JSON.serialize(new Map<String, Object>{ 'data' => filtered });
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static Boolean containsIgnoreCase(String value, String filter) {
        if (String.isBlank(filter)) return true;
        if (String.isBlank(value))  return false;
        return value.toLowerCase().contains(filter.toLowerCase());
    }

    private static Boolean matchesTitle(Map<String, Object> doc, String title) {
        if (String.isBlank(title)) return true;
        return containsIgnoreCase((String) doc.get('file_name'), title)
            || containsIgnoreCase((String) doc.get('title'), title);
    }

    private static Boolean matchesParty(Map<String, Object> doc, String partyName) {
        if (String.isBlank(partyName)) return true;
        List<Object> parties = (List<Object>) doc.get('parties');
        if (parties == null) return false;
        for (Object o : parties) {
            Map<String, Object> party = (Map<String, Object>) o;
            if (containsIgnoreCase((String) party.get('name_in_agreement'), partyName)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean matchesLanguage(Map<String, Object> doc, String language) {
        if (String.isBlank(language)) return true;
        List<Object> languages = (List<Object>) doc.get('languages');
        if (languages == null) return false;
        for (Object o : languages) {
            if (containsIgnoreCase((String) o, language)) {
                return true;
            }
        }
        return false;
    }

}
