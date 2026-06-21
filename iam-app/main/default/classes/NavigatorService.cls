public with sharing class NavigatorService {

    public class Config {
        public String integrationKey;
        public String userId;
        public String privateKey;
        public String authServer;
        public String accountId;
    }

    public class ListParams {
        public String status;
        public String partyName;
        public String documentType;
        public String title;
        public String expirationDateFrom;
        public String expirationDateTo;
        public String effectiveDateFrom;
        public String effectiveDateTo;
        public String sourceName;
        public Integer maxResults;
    }

    public static Config loadConfig() {
        DocuSign_JWT_Config__mdt mdt = [
            SELECT Integration_Key__c, User_Id__c, Private_Key__c,
                   Auth_Server__c, Account_Id__c
            FROM DocuSign_JWT_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        Config cfg = new Config();
        cfg.integrationKey = mdt.Integration_Key__c;
        cfg.userId         = mdt.User_Id__c;
        cfg.privateKey     = mdt.Private_Key__c;
        cfg.authServer     = String.isNotBlank(mdt.Auth_Server__c)
                                ? mdt.Auth_Server__c
                                : 'https://account-d.docusign.com';
        cfg.accountId      = mdt.Account_Id__c;
        return cfg;
    }

    public static String getAccessToken(Config cfg) {
        Long nowSec = DateTime.now().getTime() / 1000;
        Long exp    = nowSec + 3600;

        Map<String, Object> headerMap = new Map<String, Object>{
            'alg' => 'RS256',
            'typ' => 'JWT'
        };
        Map<String, Object> payloadMap = new Map<String, Object>{
            'iss'   => cfg.integrationKey,
            'sub'   => cfg.userId,
            'aud'   => 'account-d.docusign.com',
            'iat'   => nowSec,
            'exp'   => exp,
            'scope' => 'signature adm_store_unified_repo_read dtr.rooms.write dtr.rooms.read dtr.company.read dtr.documents.write dtr.documents.read'
        };

        String signingInput = base64UrlEncode(Blob.valueOf(JSON.serialize(headerMap)))
            + '.' + base64UrlEncode(Blob.valueOf(JSON.serialize(payloadMap)));
        Blob privateKeyBlob = pemToPrivateKeyBlob(cfg.privateKey);
        Blob sig            = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);
        String jwt          = signingInput + '.' + base64UrlEncode(sig);

        HttpRequest tokenReq = new HttpRequest();
        tokenReq.setEndpoint(cfg.authServer + '/oauth/token');
        tokenReq.setMethod('POST');
        tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        tokenReq.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion='
            + EncodingUtil.urlEncode(jwt, 'UTF-8'));

        HttpResponse tokenRes = new Http().send(tokenReq);
        if (tokenRes.getStatusCode() < 200 || tokenRes.getStatusCode() >= 300) {
            throw new CalloutException('トークン取得失敗: HTTP '
                + tokenRes.getStatusCode() + ' ' + tokenRes.getBody());
        }
        Map<String, Object> tokenMap = (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody());
        if (!tokenMap.containsKey('access_token')) {
            throw new CalloutException('access_token がレスポンスに含まれていません: ' + tokenRes.getBody());
        }
        return (String) tokenMap.get('access_token');
    }

    public static String getESignBaseUrl(Config cfg) {
        // Demo auth server (account-d.docusign.com) → demo.docusign.net
        if (cfg.authServer != null && cfg.authServer.contains('-d.')) {
            return 'https://demo.docusign.net/restapi';
        }
        return 'https://www.docusign.net/restapi';
    }

    public static String getAgreementsBaseUrl(String accountId) {
        return 'callout:DocuSign_Navigator/v1/accounts/' + accountId + '/agreements';
    }

    public static String buildListUrl(String baseUrl, ListParams p) {
        Integer maxRes = (p != null && p.maxResults != null) ? p.maxResults : 20;
        List<String> params = new List<String>{ 'limit=' + maxRes };

        List<String> filters = new List<String>();
        if (p != null) {
            if (String.isNotBlank(p.status))              filters.add('status eq \'' + p.status + '\'');
            if (String.isNotBlank(p.documentType))        filters.add('type eq \'' + p.documentType + '\'');
            if (String.isNotBlank(p.title))               filters.add('title eq \'' + p.title + '\'');
            if (String.isNotBlank(p.expirationDateFrom))  filters.add('provisions/expiration_date ge ' + p.expirationDateFrom);
            if (String.isNotBlank(p.expirationDateTo))    filters.add('provisions/expiration_date le ' + p.expirationDateTo);
            if (String.isNotBlank(p.effectiveDateFrom))   filters.add('provisions/effective_date ge ' + p.effectiveDateFrom);
            if (String.isNotBlank(p.effectiveDateTo))     filters.add('provisions/effective_date le ' + p.effectiveDateTo);
            if (String.isNotBlank(p.sourceName))          filters.add('source_name eq \'' + p.sourceName + '\'');
            // parties は $filter OData式では非対応のため直接クエリパラメーターとして渡す
            if (String.isNotBlank(p.partyName))           params.add('parties.name_in_agreement=' + EncodingUtil.urlEncode(p.partyName, 'UTF-8'));
        }
        if (!filters.isEmpty()) {
            params.add('$filter=' + EncodingUtil.urlEncode(String.join(filters, ' and '), 'UTF-8'));
        }

        return baseUrl + '?' + String.join(params, '&');
    }

    public static HttpResponse callGet(String url, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');
        return new Http().send(req);
    }

    public static HttpResponse callPost(String url, String accessToken, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(body);
        return new Http().send(req);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static String base64UrlEncode(Blob input) {
        return EncodingUtil.base64Encode(input)
            .replace('=', '').replace('+', '-').replace('/', '_');
    }

    private static Blob pemToPrivateKeyBlob(String pem) {
        String cleaned = pem
            .replace('-----BEGIN RSA PRIVATE KEY-----', '')
            .replace('-----END RSA PRIVATE KEY-----', '')
            .replace('-----BEGIN PRIVATE KEY-----', '')
            .replace('-----END PRIVATE KEY-----', '')
            .replaceAll('\\s+', '');

        Blob keyBlob = EncodingUtil.base64Decode(cleaned);

        if (pem.contains('-----BEGIN PRIVATE KEY-----')) {
            return keyBlob;
        }

        String pkcs1Hex  = EncodingUtil.convertToHex(keyBlob);
        Integer pkcs1Len = keyBlob.size();
        String oidHex    = '300d06092a864886f70d0101010500';

        String octetHex;
        if (pkcs1Len < 128) {
            octetHex = '04' + intToHex2(pkcs1Len);
        } else if (pkcs1Len < 256) {
            octetHex = '0481' + intToHex2(pkcs1Len);
        } else {
            octetHex = '0482' + intToHex4(pkcs1Len);
        }

        String innerHex  = '020100' + oidHex + octetHex + pkcs1Hex;
        Integer innerLen = innerHex.length() / 2;

        String seqHex;
        if (innerLen < 128) {
            seqHex = '30' + intToHex2(innerLen);
        } else if (innerLen < 256) {
            seqHex = '3081' + intToHex2(innerLen);
        } else {
            seqHex = '3082' + intToHex4(innerLen);
        }

        return EncodingUtil.convertFromHex(seqHex + innerHex);
    }

    private static String intToHex2(Integer val) {
        String h = intToHex(val);
        while (h.length() < 2) h = '0' + h;
        return h;
    }

    private static String intToHex4(Integer val) {
        String h = intToHex(val);
        while (h.length() < 4) h = '0' + h;
        return h;
    }

    private static String intToHex(Integer val) {
        if (val == 0) return '0';
        String chars = '0123456789abcdef';
        String hex   = '';
        while (val > 0) {
            hex = chars.substring(Math.mod(val, 16), Math.mod(val, 16) + 1) + hex;
            val = val / 16;
        }
        return hex;
    }
}
