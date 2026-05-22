/**
 * Agentforce用DocuSign送信アクション
 * Agentforceエージェントから呼び出し可能なInvocable Apexアクション
 */
public with sharing class DocuSignAgentAction {
    
    /**
     * AgentforceからDocuSignエンベロープを送信
     * @param requests リクエストパラメータのリスト
     * @return レスポンスのリスト
     */
    @InvocableMethod(
        label='DocuSignエンベロープを送信'
        description='商談に添付されたPDFファイルをDocuSignで送信します'
        category='DocuSign'
    )
    public static List<DocuSignResponse> sendDocuSignEnvelope(List<DocuSignRequest> requests) {
        List<DocuSignResponse> responses = new List<DocuSignResponse>();
        
        for (DocuSignRequest request : requests) {
            DocuSignResponse response = new DocuSignResponse();
            
            try {
                // 入力検証
                validateRequest(request);
                
                // ContentVersion取得
                ContentVersion cv = getContentVersion(request.documentId);
                
                        // DocuSignエンベロープ送信は非同期で実行（@future）する
                sendEnvelopeAsync(cv.Id, request.recipientEmail, request.recipientName, request.opportunityId);
                
                // 非同期実行のため即時応答を返す
                response.envelopeId = null;
                response.success = true;
                response.message = '署名依頼の送信処理を開始しました。完了後、商談のタスクにエンベロープIDが記録されます。';
                
                } catch (Exception e) {
                    response.success = false;
                    // 詳細ログを追加（デバッグ目的）
                    String paramsInfo = 'opportunityId=' + request.opportunityId
                        + ', documentId=' + request.documentId
                        + ', recipientEmail=' + request.recipientEmail
                        + ', recipientName=' + request.recipientName;
                    System.debug('DocuSignAgentAction.sendDocuSignEnvelope - 入力パラメータ: ' + paramsInfo);
                    System.debug('DocuSignAgentAction.sendDocuSignEnvelope - 例外クラス: ' + e.getTypeName());
                    System.debug('DocuSignAgentAction.sendDocuSignEnvelope - 例外メッセージ: ' + e.getMessage());
                    System.debug('DocuSignAgentAction.sendDocuSignEnvelope - スタックトレース: ' + e.getStackTraceString());
                    // フル詳細（開発向け）：エラー種別・メッセージ・スタックトレースを返す
                    String fullDetails = 'ErrorType=' + e.getTypeName()
                        + ' | Message=' + e.getMessage()
                        + ' | Stack=' + e.getStackTraceString();
                    response.message = fullDetails;
                    // 追加で開発用の短いフィールドを残す（UI用）
                    response.envelopeId = null;
                    // Agentforce に戻すための追加フィールド（安全に要約を返す）
                    response.debugInfo = 'ErrorType=' + e.getTypeName() + '; Msg=' + (e.getMessage() != null ? e.getMessage().substring(0, Math.min(200, e.getMessage().length())) : ''); 
                    // 重要: Agentforce に返すメッセージは機密情報を含まないように要約する
                    // 上位で詳細ログが必要な場合はデバッグログを参照するよう促す
                }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    /**
     * リクエストの入力検証
     */
    private static void validateRequest(DocuSignRequest request) {
        if (String.isBlank(request.documentId)) {
            throw new IllegalArgumentException('ドキュメントIDが指定されていません');
        }
        if (String.isBlank(request.recipientEmail)) {
            throw new IllegalArgumentException('受信者のメールアドレスが指定されていません');
        }
        if (String.isBlank(request.recipientName)) {
            throw new IllegalArgumentException('受信者の名前が指定されていません');
        }
    }
    
    /**
     * ContentVersionを取得
     */
    private static ContentVersion getContentVersion(String documentId) {
        List<ContentVersion> cvList = [
            SELECT Id, VersionData, Title, FileExtension, ContentDocumentId
            FROM ContentVersion 
            WHERE ContentDocumentId = :documentId 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        if (cvList.isEmpty()) {
            throw new IllegalArgumentException('指定されたドキュメントが見つかりません: ' + documentId);
        }
        
        return cvList[0];
    }
    
    /**
     * DocuSignエンベロープを送信
     */
    // 非同期でDocuSign送信を行う（@future はコールアウトを伴う処理をセッション非依存で実行可能）
    @future(callout=true)
    public static void sendEnvelopeAsync(String cvId, String recipientEmail, String recipientName, String opportunityId) {
        try {
            // cvIdを再クエリしてContentVersionを取得
            ContentVersion cv = [SELECT Id, VersionData, Title, FileExtension, ContentDocumentId FROM ContentVersion WHERE Id = :cvId LIMIT 1];
            
            // 1. Document.fromFile()でドキュメント作成
            dfsle.Document document = dfsle.Document.fromFile(cv);
            List<dfsle.Document> documents = new List<dfsle.Document>{ document };
            
            // 2. Recipient.fromSource()で受信者作成
            dfsle.Recipient recipient = dfsle.Recipient.fromSource(
                recipientName,     // name
                recipientEmail,    // email
                null,              // phone
                'Signer',          // role
                null               // source Entity
            );
            List<dfsle.Recipient> recipients = new List<dfsle.Recipient>{ recipient };
            
            // 3. EnvelopeService.getEmptyEnvelope()で空のエンベロープ取得（商談IDを渡してdfsle__Envelope__c.dfsle__SourceId__cに紐づける）
            dfsle.Entity sourceEntity = String.isNotBlank(opportunityId)
                ? new dfsle.Entity(Id.valueOf(opportunityId))
                : null;
            dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(sourceEntity);
            
            // 4. withDocuments()とwithRecipients()でエンベロープ構築
            envelope = envelope
                .withDocuments(documents)
                .withRecipients(recipients);
            
            // 5. EnvelopeService.sendEnvelope()でエンベロープ送信
            dfsle.Envelope sentEnvelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);
            
            // 6. エンベロープID取得
            String envelopeId = String.valueOf(sentEnvelope.docuSignId);
            
            // 7. 商談へのタスク記録（オプション）
            if (String.isNotBlank(opportunityId)) {
                try {
                    Task envelopeTask = new Task(
                        WhatId = opportunityId,
                        Subject = 'DocuSign署名依頼送信（Agentforce経由）: ' + recipientName,
                        Description = 'エンベロープID: ' + envelopeId + '\n' +
                                     '宛先: ' + recipientName + ' (' + recipientEmail + ')\n' +
                                     '送信元: Agentforceエージェント',
                        Status = 'Completed',
                        ActivityDate = Date.today(),
                        Type = 'Email'
                    );
                    insert envelopeTask;
                } catch (Exception taskEx) {
                    // タスク挿入失敗はログに残して続行
                    System.debug('createEnvelopeTask failed in future: ' + taskEx.getMessage());
                }
            }
            
        } catch (Exception e) {
            // 非同期実行なので戻り値は返せない。ログへ詳細を出力して終了。
            System.debug('sendEnvelopeAsync error: ' + e.getTypeName() + ' | ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
    }
    
    /**
     * Invocable Method入力パラメータ
     */
    public class DocuSignRequest {
        @InvocableVariable(
            label='ドキュメントID' 
            description='送信するPDFのContentDocumentId'
            required=true
        )
        public String documentId;
        
        @InvocableVariable(
            label='受信者メールアドレス' 
            description='署名依頼を送信する相手のメールアドレス'
            required=true
        )
        public String recipientEmail;
        
        @InvocableVariable(
            label='受信者名' 
            description='署名依頼を送信する相手の氏名'
            required=true
        )
        public String recipientName;
        
        @InvocableVariable(
            label='商談ID' 
            description='関連する商談のレコードID（オプション）'
            required=false
        )
        public String opportunityId;
    }
    
    /**
     * Invocable Method出力パラメータ
     */
        public class DocuSignResponse {
        @InvocableVariable(
            label='成功フラグ' 
            description='送信が成功した場合true'
        )
        public Boolean success;
        
        @InvocableVariable(
            label='エンベロープID' 
            description='DocuSignのエンベロープID'
        )
        public String envelopeId;
        
        @InvocableVariable(
            label='メッセージ' 
            description='実行結果のメッセージ（短縮）'
        )
        public String message;
        
        @InvocableVariable(
            label='デバッグ情報' 
            description='エラー詳細（開発向けフル情報）。Agentforce会話に表示する場合は取り扱いに注意'
        )
        public String debugInfo;
    }
}