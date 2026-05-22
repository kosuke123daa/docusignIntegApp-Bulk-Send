/**
 * Agentforce用添付ファイル取得アクション
 * レコードに添付されているファイル（特にPDF）の一覧を取得
 */
public with sharing class GetRecordAttachmentsAction {
    
    /**
     * レコードに添付されているファイルを取得
     * @param requests リクエストパラメータのリスト
     * @return レスポンスのリスト
     */
    @InvocableMethod(
        label='レコードの添付ファイルを取得'
        description='レコードに添付されているファイル（PDF）の一覧を取得します'
        category='Files'
    )
    public static List<AttachmentResponse> getRecordAttachments(List<AttachmentRequest> requests) {
        List<AttachmentResponse> responses = new List<AttachmentResponse>();
        
        for (AttachmentRequest request : requests) {
            AttachmentResponse response = new AttachmentResponse();
            
            try {
                // 入力検証
                if (String.isBlank(request.recordId)) {
                    throw new IllegalArgumentException('レコードIDが指定されていません');
                }
                
                // ファイルタイプの指定（デフォルトはPDF）
                String fileExtension = String.isBlank(request.fileExtension) ? 'pdf' : request.fileExtension.toLowerCase();
                
                // ContentDocumentLink経由で添付ファイルを取得
                List<ContentDocumentLink> cdLinks = [
                    SELECT ContentDocumentId, 
                           ContentDocument.Title, 
                           ContentDocument.FileExtension, 
                           ContentDocument.ContentSize,
                           ContentDocument.CreatedDate,
                           ContentDocument.LastModifiedDate,
                           ContentDocument.LatestPublishedVersionId
                    FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :request.recordId 
                    AND ContentDocument.FileExtension = :fileExtension
                    ORDER BY ContentDocument.LastModifiedDate DESC
                ];
                
                // ファイル情報をJSON形式で構築
                List<FileInfo> fileList = new List<FileInfo>();
                for (ContentDocumentLink link : cdLinks) {
                    FileInfo fileInfo = new FileInfo();
                    fileInfo.documentId = link.ContentDocumentId;
                    fileInfo.title = link.ContentDocument.Title;
                    fileInfo.fileExtension = link.ContentDocument.FileExtension;
                    fileInfo.fileSizeKB = link.ContentDocument.ContentSize / 1024;
                    fileInfo.createdDate = link.ContentDocument.CreatedDate.format('yyyy-MM-dd HH:mm');
                    fileInfo.lastModifiedDate = link.ContentDocument.LastModifiedDate.format('yyyy-MM-dd HH:mm');
                    fileList.add(fileInfo);
                }
                
                // レスポンス設定
                response.success = true;
                response.fileCount = fileList.size();
                response.files = JSON.serialize(fileList);
                
                if (fileList.isEmpty()) {
                    response.message = fileExtension.toUpperCase() + 'ファイルは添付されていません';
                } else if (fileList.size() == 1) {
                    response.message = '1件の' + fileExtension.toUpperCase() + 'ファイルが見つかりました: ' + fileList[0].title;
                } else {
                    response.message = fileList.size() + '件の' + fileExtension.toUpperCase() + 'ファイルが見つかりました';
                }
                
            } catch (Exception e) {
                response.success = false;
                response.fileCount = 0;
                response.files = '[]';
                response.message = 'エラーが発生しました: ' + e.getMessage();
                System.debug('添付ファイル取得エラー: ' + e.getMessage());
                System.debug('スタックトレース: ' + e.getStackTraceString());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    /**
     * Invocable Method入力パラメータ
     */
    public class AttachmentRequest {
        @InvocableVariable(
            label='レコードID' 
            description='添付ファイルを取得するレコードのID（currentRecordIdを使用）'
            required=true
        )
        public String recordId;
        
        @InvocableVariable(
            label='ファイル拡張子' 
            description='取得するファイルの拡張子（例: pdf, docx, xlsx）。未指定の場合はpdf'
            required=false
        )
        public String fileExtension;
    }
    
    /**
     * Invocable Method出力パラメータ
     */
    public class AttachmentResponse {
        @InvocableVariable(
            label='成功フラグ' 
            description='取得が成功した場合true'
        )
        public Boolean success;
        
        @InvocableVariable(
            label='ファイル件数' 
            description='添付されているファイルの件数'
        )
        public Integer fileCount;
        
        @InvocableVariable(
            label='ファイル情報（JSON）' 
            description='ファイル情報のJSON配列'
        )
        public String files;
        
        @InvocableVariable(
            label='メッセージ' 
            description='実行結果のメッセージ'
        )
        public String message;
    }
    
    /**
     * ファイル情報を格納するクラス（JSON変換用）
     */
    public class FileInfo {
        public String documentId;
        public String title;
        public String fileExtension;
        public Long fileSizeKB;
        public String createdDate;
        public String lastModifiedDate;
    }
}