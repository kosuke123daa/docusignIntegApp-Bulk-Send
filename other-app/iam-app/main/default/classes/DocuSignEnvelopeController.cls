public with sharing class DocuSignEnvelopeController {
    
    /**
     * 商談レコードに添付されているPDFファイルを取得
     * @param recordId 商談レコードID
     * @return PDFファイル情報のリスト
     */
    @AuraEnabled(cacheable=true)
    public static List<FileInfo> getOpportunityPDFFiles(Id recordId) {
        List<FileInfo> files = new List<FileInfo>();
        
        try {
            // ContentDocumentLink経由で添付ファイルを取得
            List<ContentDocumentLink> cdLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, 
                       ContentDocument.FileExtension, ContentDocument.ContentSize,
                       ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId 
                AND ContentDocument.FileExtension = 'pdf'
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
            
        } catch (Exception e) {
            throw new AuraHandledException('PDFファイルの取得エラー: ' + e.getMessage());
        }
        
        return files;
    }
    
    /**
     * DocuSign エンベロープを送信
     * @param recordId 商談レコードID
     * @param documentId ContentDocumentId
     * @param recipientEmail 受信者メールアドレス
     * @param recipientName 受信者名
     * @return エンベロープID
     */
    @AuraEnabled
    public static String sendDocuSignEnvelope(
        Id recordId, 
        Id documentId, 
        String recipientEmail, 
        String recipientName
    ) {
        try {
            // 入力検証
            if (String.isBlank(recipientEmail) || String.isBlank(recipientName)) {
                throw new IllegalArgumentException('受信者情報が不足しています');
            }
            
            // ContentVersion取得（PDFバイナリデータ）
            ContentVersion cv = [
                SELECT VersionData, Title, FileExtension, ContentDocumentId
                FROM ContentVersion 
                WHERE ContentDocumentId = :documentId 
                AND IsLatest = true 
                LIMIT 1
            ];
            
            // DocuSign Toolkitを使用してエンベロープを作成・送信
            // Note: dsfs名前空間のクラスを使用
            String envelopeId = createAndSendEnvelope(cv, recipientEmail, recipientName);
            
            // 送信履歴を商談に記録（オプション）
            createEnvelopeTask(recordId, envelopeId, recipientEmail, recipientName);
            
            return envelopeId;
            
        } catch (Exception e) {
            System.debug('DocuSign送信エラー: ' + e.getMessage());
            throw new AuraHandledException('エンベロープ送信エラー: ' + e.getMessage());
        }
    }
    
    /**
     * DocuSign Apps Launcher (dfsle名前空間) を使用してエンベロープを作成・送信
     * Note: 公式ドキュメントに基づく正しいAPI使用方法
     */
    private static String createAndSendEnvelope(
        ContentVersion cv, 
        String recipientEmail, 
        String recipientName
    ) {
        try {
            // 1. Document.fromFile()を使用してContentVersionからドキュメントを作成
            dfsle.Document document = dfsle.Document.fromFile(cv);
            List<dfsle.Document> documents = new List<dfsle.Document>{ document };
            
            // 2. Recipient.fromSource()を使用して受信者を作成
            dfsle.Recipient recipient = dfsle.Recipient.fromSource(
                recipientName,     // name
                recipientEmail,    // email
                null,              // phone
                'Signer',          // role
                null               // source Entity
            );
            
            List<dfsle.Recipient> recipients = new List<dfsle.Recipient>{ recipient };
            
            // 3. EnvelopeService.getEmptyEnvelope()で空のエンベロープを取得
            dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(null);
            
            // 4. withDocuments()とwithRecipients()でエンベロープを構築
            envelope = envelope
                .withDocuments(documents)
                .withRecipients(recipients);
            
            // 5. EnvelopeService.sendEnvelope()でエンベロープを送信
            // 第2引数のtrue = 即時送信（false = ドラフトとして保存）
            dfsle.Envelope sentEnvelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);
            
            // 6. 送信されたエンベロープのdocuSignIdプロパティからエンベロープIDを取得
            return String.valueOf(sentEnvelope.docuSignId);
            
        } catch (Exception e) {
            // 詳細ログを追加（デバッグ目的）
            System.debug('DocuSignEnvelopeController.createAndSendEnvelope - ContentVersion Id: ' + (cv != null ? cv.Id : 'null'));
            System.debug('DocuSignEnvelopeController.createAndSendEnvelope - recipientEmail: ' + recipientEmail + ', recipientName: ' + recipientName);
            System.debug('DocuSignEnvelopeController.createAndSendEnvelope - 例外クラス: ' + e.getTypeName());
            System.debug('DocuSignEnvelopeController.createAndSendEnvelope - 例外メッセージ: ' + e.getMessage());
            System.debug('DocuSignEnvelopeController.createAndSendEnvelope - スタックトレース: ' + e.getStackTraceString());
            throw new AuraHandledException(
                'DocuSign エンベロープの送信に失敗しました。' + 
                'エラー: ' + e.getTypeName() + ' - ' + e.getMessage()
            );
        }
    }
    
    /**
     * エンベロープ送信履歴をタスクとして記録
     */
    private static void createEnvelopeTask(
        Id opportunityId, 
        String envelopeId, 
        String recipientEmail,
        String recipientName
    ) {
        Task envelopeTask = new Task(
            WhatId = opportunityId,
            Subject = 'DocuSign署名依頼送信: ' + recipientName,
            Description = 'エンベロープID: ' + envelopeId + '\n' +
                         '宛先: ' + recipientName + ' (' + recipientEmail + ')',
            Status = 'Completed',
            ActivityDate = Date.today(),
            Type = 'Email'
        );
        
        insert envelopeTask;
    }
    
    /**
     * ファイル情報を格納するラッパークラス
     */
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
}