# DocuSign統合 状況レポート

## 現在の状況

商談ページ上のLightning Webコンポーネントで、DocuSignと連携する方法を複数試しました。その結果をご報告します。

### インストール済みのDocuSignパッケージ
お使いの組織には、以下のDocuSignパッケージがインストールされています：
- **DocuSign eSignature for Salesforce** (`dsfs`名前空間、v7.12.3)
- **DocuSign Apps Launcher** (`dfsle`名前空間、v7.14.2)
- **DocuSign eSignature for Salesforce CPQ** (`dfscpq`名前空間、v2.2)

### 試した連携方法

#### 1. `dsfs`名前空間の使用（最初の試み）
- **試したこと:** `dsfs.DocuSignDocument`, `dsfs.DocuSignRecipient`クラスの使用
- **結果:** ❌ 失敗 - これらのクラスは内部用でカスタムコードからアクセスできません
- **エラー:** "Type is not visible: dsfs.DocuSignDocument"

#### 2. `dfsle`名前空間のビルダーパターン（2回目の試み）
- **試したこと:**
  ```apex
  dfsle.EnvelopeService.getEmptyEnvelope()
  dfsle.Recipient.fromSource()
  dfsle.DocumentService.getDocuments()
  ```
- **結果:** ❌ 失敗 - メソッドのシグネチャが一致しません
- **エラー:** "Method does not exist or incorrect signature"

#### 3. `dfsle.EnvelopeAPI`の使用（3回目の試み）
- **試したこと:** `dfsle.EnvelopeAPI.sendEnvelopeWithDocument()`
- **結果:** ❌ 失敗 - クラスは存在しますが、公開されていません
- **エラー:** "Type is not visible: dfsle.EnvelopeAPI"

#### 4. DocuSign REST APIの直接使用（検討のみ）
- **方法:** DocuSign REST APIへの直接HTTPコールアウト
- **状態:** 認証設定が複雑なため未実装
- **必要なもの:** OAuth認証を設定した名前付き資格情報

## 主な発見事項

1. **DocuSignのApexクラスはほぼ非公開**: インストール済みのDocuSignパッケージにはApexクラスが含まれていますが、ほとんどがプライベート/内部用でカスタムコードからアクセスできません。

2. **パッケージのUI機能は利用可能**: DocuSignパッケージは標準のUIコンポーネント（ボタン、アクション）を提供しており、それらは内部実装で動作します。

3. **ドキュメントとの不一致**: ドキュメントで見つけたサンプルコードが、実際にインストールされているパッケージの公開APIと一致しません。

## 推奨される解決策

### オプション1: DocuSignの標準機能を使用（推奨）
インストール済みのDocuSignパッケージが提供する標準の「DocuSignで送信」ボタンを商談ページレイアウトに追加します。これが公式にサポートされている方法です。

**メリット:**
- ✅ DocuSignの完全サポート
- ✅ カスタムコードのメンテナンス不要
- ✅ 認証が自動で処理される
- ✅ DocuSignの全機能が利用可能

**実装方法:**
1. 設定 → オブジェクトマネージャー → 商談 → ページレイアウト
2. 商談ページレイアウトを編集
3. DocuSignパッケージのDocuSignアクションボタンを追加
4. DocuSignの管理画面からボタン設定を構成

### オプション2: DocuSign REST APIでカスタム統合
DocuSignのREST APIを直接使用してカスタム統合を構築します。

**必要な設定:**
- OAuth 2.0認証の構成
- Salesforceで名前付き資格情報を設定
- リモートサイト設定の作成
- DocuSignアカウントIDとAPIキーの保存
- トークンリフレッシュロジックの処理

**メリット:**
- ✅ ユーザー体験を完全にコントロール
- ✅ カスタムUIが可能

**デメリット:**
- ❌ 複雑な認証設定が必要
- ❌ DocuSign APIの知識が必要
- ❌ メンテナンスするコードが増える
- ❌ APIレート制限への対応が必要
- ❌ APIバージョンアップへの対応が必要

### オプション3: DocuSignサポートに問い合わせ
DocuSignサポートに連絡して：
1. インストール済みパッケージバージョンで利用可能な公開APIを確認
2. 公開APIのドキュメントを要求
3. サポートされているカスタム統合パターンについて問い合わせ

## 現在のコンポーネント状況

### ✅ 完成したコンポーネント
1. **Lightning Webコンポーネント** - `docusignSenderComponent`
   - PDFファイルを選択するUI
   - 受信者名とメールアドレスの入力フィールド
   - 送信ボタン機能
   - 組織へのデプロイ成功

2. **Apexコントローラー** - `DocuSignEnvelopeController`
   - 商談からPDFファイルを取得するメソッド
   - エンベロープ送信の骨組み（APIアクセス問題により未動作）
   - 送信履歴を記録するタスク作成機能

3. **テストクラス** - `DocuSignEnvelopeControllerTest`
   - コントローラーメソッドの基本的なテストカバレッジ

### ❌ まだ動作していない機能
- 実際のDocuSignエンベロープ送信（APIアクセス制限のため）

## 次のステップ

### オプション1を選択する場合（推奨）:
1. カスタムコンポーネントをページから削除
2. 商談レイアウトにDocuSignの標準ボタンを追加
3. DocuSign管理画面からボタン設定を構成

### オプション2を選択する場合（カスタムREST API）:
1. DocuSign開発者アカウントを設定
2. インテグレーションキーを作成
3. SalesforceでOAuth認証を構成
4. 名前付き資格情報を作成
5. `DocuSignEnvelopeController`を更新してREST APIと適切な認証を使用
6. 十分にテスト

### オプション3を選択する場合（サポート問い合わせ）:
1. DocuSignサポートにケースを開く
2. パッケージバージョンを参照
3. 公開APIドキュメントを要求
4. カスタムApex統合のサンプルコードを要求

## 作成したファイル

- `force-app/main/default/lwc/docusignSenderComponent/` - Lightning Webコンポーネント
- `force-app/main/default/classes/DocuSignEnvelopeController.cls` - Apexコントローラー
- `force-app/main/default/classes/DocuSignEnvelopeControllerTest.cls` - テストクラス
- `DOCUSIGN_COMPONENT_README.md` - コンポーネントドキュメント（英語）
- `DOCUSIGN_統合状況レポート.md` - この状況レポート（日本語）

## 結論

DocuSign統合用のUIコンポーネントは正常に作成できましたが、実際のエンベロープ送信機能は以下のいずれかが必要です：

1. **DocuSignの標準UIコンポーネントを使用**（最も簡単で推奨）
2. **DocuSign REST APIの完全な認証設定**（複雑だが完全なコントロールが可能）
3. **DocuSignの公開Apex APIへのアクセス取得**（DocuSignサポートの支援が必要）

作成したカスタムコンポーネントはデプロイして正しく表示されますが、「送信」ボタンは上記のいずれかのアプローチがバックエンド統合に実装されるまで動作しません。

## 私からの提案

**最も簡単な方法：** オプション1（DocuSign標準ボタン）を使用することをお勧めします。理由：
- すぐに使える
- メンテナンス不要
- DocuSignの全機能が使える
- 認証の心配が不要

カスタムUIが絶対に必要な場合は、オプション2（REST API統合）を選択してください。ただし、OAuth設定や名前付き資格情報の構成が必要です。

どちらを進めたいですか？