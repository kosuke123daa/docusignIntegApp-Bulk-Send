public with sharing class NavigatorAgreementUploadController {

    public class FileInfo {
        @AuraEnabled public String documentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public Integer fileSize;

        public FileInfo(String docId, String title, String ext, Integer size) {
            this.documentId = docId;
            this.title = title;
            this.fileExtension = ext;
            this.fileSize = size;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FileInfo> getRecordFiles(Id recordId) {
        List<FileInfo> files = new List<FileInfo>();
        List<ContentDocumentLink> cdLinks = [
            SELECT ContentDocumentId, ContentDocument.Title,
                   ContentDocument.FileExtension, ContentDocument.ContentSize
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.Title
        ];
        for (ContentDocumentLink link : cdLinks) {
            files.add(new FileInfo(
                link.ContentDocumentId,
                link.ContentDocument.Title,
                link.ContentDocument.FileExtension,
                link.ContentDocument.ContentSize
            ));
        }
        return files;
    }

    @AuraEnabled
    public static String uploadToNavigator(Id recordId, Id contentDocumentId) {
        try {
            String objectName = recordId.getSObjectType().getDescribe().getName();
            NavigatorAgreementUploadService.UploadResult result =
                NavigatorAgreementUploadService.uploadAgreement(contentDocumentId, objectName, recordId);
            return result.jobId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
