# DocuSign dfsle API 調査結果

## 現状

`dfsle`名前空間がglobalクラスとして公開されていることは確認できましたが、実際の公開メソッドのシグネチャを特定できていません。

## 試したアプローチと結果

### 1. 標準的なコンストラクタパターン
```apex
dfsle.Recipient recipient = new dfsle.Recipient();
recipient.Name = recipientName;
```
**エラー:** `Constructor not defined: [dfsle.Recipient].<Constructor>()`
**結果:** ❌ コンストラクタが公開されていない

### 2. ファクトリーメソッド fromSource()
```apex
dfsle.Recipient recipient = dfsle.Recipient.fromSource(name, email, phone, role, entity);
```
**エラー:** `Method does not exist or incorrect signature`
**結果:** ❌ メソッドシグネチャが不明

### 3. DocumentService.getDocuments()
```apex
List<dfsle.Document> documents = dfsle.DocumentService.getDocuments(contentVersionIds);
```
**エラー:** `Method does not exist or incorrect signature`
**結果:** ❌ メソッドシグネチャが不明

### 4. Document.fromSource()
```apex
dfsle.Document document = dfsle.Document.fromSource(cv.Id);
```
**エラー:** `Method does not exist or incorrect signature`
**結果:** ❌ メソッドシグネチャが不明

### 5. Envelope.getEnvelopeId()
```apex
return sentEnvelope.getEnvelopeId();
```
**エラー:** `Method does not exist or incorrect signature`
**結果:** ❌ メソッドが存在しない

## 問題点

1. **ドキュメント不足:** DocuSign Apps Launcher (`dfsle`名前空間) の公開APIドキュメントにアクセスできない
2. **クラス定義の非公開:** インストール済みパッケージのApexクラスのBodyが`(hidden)`で参照できない
3. **メソッドシグネチャの不一致:** ネット上で見つかるサンプルコードが実際のAPIと一致しない

## 確認できていること

✅ `dfsle`名前空間のクラスは存在する：
- `dfsle.Envelope`
- `dfsle.EnvelopeService`
- `dfsle.Document`
- `dfsle.DocumentService`
- `dfsle.Recipient`
- `dfsle.RecipientService`
- `dfsle.UUID`

❌ これらのクラスの公開メソッドとシグネチャが不明

## 推奨される次のステップ

### オプション1: DocuSignサポートに問い合わせ（最も確実）
DocuSignのサポートチームに以下を問い合わせる：
1. DocuSign Apps Launcher (v7.14.2) の`dfsle`名前空間APIドキュメント
2. カスタムApexからエンベロープを送信するサンプルコード
3. 公開されているメソッドとシグネチャの一覧

**問い合わせ先情報:**
- インストール済みパッケージ: DocuSign Apps Launcher (dfsle namespace, v7.14.2)
- 組織: MyAgentforceOrg (sc-demo-20250903.my.salesforce.com)
- 目的: カスタムLWCからDocuSignエンベロープを送信したい

### オプション2: Salesforce組織内でAPIを探索
組織の管理者権限で以下を確認：
1. Setup → Installed Packages → DocuSign Apps Launcher → View Components
2. Apex Classes タブで`dfsle`名前空間のクラスを開き、公開メソッドを確認
3. 既存のDocuSignボタンやアクションが使用しているApexコードを参照

### オプション3: DocuSign標準機能を使用（即時利用可能）
カスタム統合を諦めて、DocuSignパッケージ標準の「Send with DocuSign」機能を使用：
1. Setup → Object Manager → Opportunity → Page Layouts
2. DocuSignアクションボタンを追加
3. ユーザーは標準UIでDocuSign署名依頼を送信

## 作成済みコンポーネント

以下のコンポーネントは作成済みで、正しいAPIが判明すれば即座に動作可能：

✅ **Lightning Webコンポーネント** (`docusignSenderComponent`)
- UI完成、デプロイ済み
- PDFファイル選択、受信者入力、送信ボタン

✅ **Apexコントローラー** (`DocuSignEnvelopeController`)
- PDFファイル取得機能は動作
- エンベロープ送信メソッドは正しいAPIが必要

## 結論

`dfsle`名前空間がglobalクラスとして公開されていても、実際の公開メソッドのシグネチャが不明なため、現時点ではカスタムApexからの呼び出しができません。

DocuSignのサポートまたはドキュメントから正しいAPIの使用方法を入手する必要があります。

それまでの間は、DocuSignパッケージ標準の機能を使用することをお勧めします。