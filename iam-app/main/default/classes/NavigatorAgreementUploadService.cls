// Navigator Bulk Upload API (Data In) - uploads a document to Navigator's
// agreement repository and tags it with the Salesforce linked_data triplet
// (application_name/object_name/record_id) so it surfaces in the standard
// "Docusign Completed Agreements" component.
public with sharing class NavigatorAgreementUploadService {

    private static final String UPLOAD_BASE_URL = 'callout:DocuSign_Navigator/v1/accounts/';

    public class UploadResult {
        public String jobId;
        public String documentId;
        public String status;
    }

    // ── エンドツーエンドのアップロード（1ファイル） ────────────────────────────
    // ContentVersion を取得し、Bulk Job 作成 → Azure Blob へPUT → Job完了 までを実行する。
    public static UploadResult uploadAgreement(String contentDocumentId, String objectName, String recordId) {
        NavigatorService.Config cfg = NavigatorService.loadConfig();
        String token = NavigatorService.getAccessToken(cfg);

        ContentVersion cv = [
            SELECT VersionData, Title, FileExtension, FileType
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        String fileName    = cv.Title + (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : '');
        String contentType = getContentType(cv.FileExtension);

        Map<String, Object> job = createBulkUploadJob(cfg, token, 1);
        String jobId = (String) job.get('id');

        Map<String, Object> uploadDoc = extractFirstUploadDocument(job);
        String uploadUrl = uploadDoc != null ? (String) ((Map<String, Object>) uploadDoc.get('_actions')).get('upload_document') : null;
        if (String.isBlank(uploadUrl)) {
            throw new CalloutException('Bulk Jobレスポンスにupload_document URLが含まれていません: ' + JSON.serialize(job));
        }

        Map<String, Object> metadata = new Map<String, Object>{
            'linked_data' => new List<Object>{
                new Map<String, Object>{
                    'application_name' => 'Salesforce',
                    'object_name'      => objectName,
                    'record_id'        => recordId
                }
            }
        };

        uploadDocumentToBlob(uploadUrl, cv.VersionData, fileName, contentType, metadata);
        completeBulkJob(cfg, token, jobId);

        UploadResult result = new UploadResult();
        result.jobId      = jobId;
        result.documentId = uploadDoc != null ? (String) uploadDoc.get('id') : null;
        result.status     = 'uploaded';
        return result;
    }

    // ── Bulk Job作成 ──────────────────────────────────────────────────────────
    public static Map<String, Object> createBulkUploadJob(NavigatorService.Config cfg, String token, Integer expectedDocumentCount) {
        String url  = UPLOAD_BASE_URL + cfg.accountId + '/upload/jobs';
        String body = JSON.serialize(new Map<String, Object>{ 'expected_document_count' => expectedDocumentCount });

        HttpResponse res = NavigatorService.callPost(url, token, body);
        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CalloutException('Bulk Job作成失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // ── Job状況取得 ───────────────────────────────────────────────────────────
    public static Map<String, Object> getBulkJobStatus(NavigatorService.Config cfg, String token, String jobId) {
        String url = UPLOAD_BASE_URL + cfg.accountId + '/upload/jobs/' + jobId;
        HttpResponse res = NavigatorService.callGet(url, token);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Bulk Job状況取得失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // ── Job完了マーク ─────────────────────────────────────────────────────────
    public static void completeBulkJob(NavigatorService.Config cfg, String token, String jobId) {
        String url = UPLOAD_BASE_URL + cfg.accountId + '/upload/jobs/' + jobId + '/actions/complete';
        HttpResponse res = NavigatorService.callPost(url, token, '{}');
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Bulk Job完了失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    // ── Azure Blob Storageへの直接PUT ────────────────────────────────────────
    public static void uploadDocumentToBlob(String uploadUrl, Blob fileData, String fileName, String contentType, Map<String, Object> metadata) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(uploadUrl);
        req.setMethod('PUT');
        req.setHeader('x-ms-blob-type', 'BlockBlob');
        req.setHeader('x-ms-meta-filename', fileName);
        req.setHeader('Content-Type', contentType);
        if (metadata != null) {
            req.setHeader('x-ms-meta-metadata', JSON.serialize(metadata));
        }
        req.setBodyAsBlob(fileData);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Azure Blobアップロード失敗: HTTP ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static Map<String, Object> extractFirstUploadDocument(Map<String, Object> job) {
        Map<String, Object> embedded = (Map<String, Object>) job.get('_embedded');
        if (embedded == null) return null;
        List<Object> documents = (List<Object>) embedded.get('documents');
        if (documents == null || documents.isEmpty()) return null;
        return (Map<String, Object>) documents.get(0);
    }

    private static String getContentType(String fileExtension) {
        String ext = fileExtension != null ? fileExtension.toLowerCase() : '';
        if (ext == 'pdf')  return 'application/pdf';
        if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (ext == 'doc')  return 'application/msword';
        if (ext == 'png')  return 'image/png';
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        return 'application/octet-stream';
    }
}
