# DocuSign署名依頼コンポーネント

商談レコード画面から添付PDFファイルを使用してDocuSign署名依頼を送信するLightning Web Componentです。

## 📋 機能概要

- 商談レコードに添付されているPDFファイルを一覧表示
- 署名依頼先のメールアドレスと名前を入力
- DocuSignエンベロープを送信
- 送信履歴をタスクとして自動記録
- エラーハンドリングとバリデーション

## 🗂️ ファイル構成

```
force-app/main/default/
├── classes/
│   ├── DocuSignEnvelopeController.cls          # Apexコントローラー
│   ├── DocuSignEnvelopeController.cls-meta.xml
│   ├── DocuSignEnvelopeControllerTest.cls      # テストクラス
│   └── DocuSignEnvelopeControllerTest.cls-meta.xml
└── lwc/
    └── docusignSenderComponent/
        ├── docusignSenderComponent.html         # HTMLテンプレート
        ├── docusignSenderComponent.js           # JavaScriptコントローラー
        ├── docusignSenderComponent.css          # スタイルシート
        └── docusignSenderComponent.js-meta.xml  # メタデータ設定
```

## 🚀 デプロイ手順

### ステップ1: コードのデプロイ

Salesforce CLIを使用してメタデータをデプロイします。

```bash
# プロジェクトディレクトリに移動
cd /Users/kosuke.mima/docusignIntegApp

# デプロイ実行
sf project deploy start --source-dir force-app/main/default
```

### ステップ2: テスト実行（オプション）

```bash
# Apexテストを実行
sf apex run test --class-names DocuSignEnvelopeControllerTest --result-format human --code-coverage
```

### ステップ3: 商談レコードページにコンポーネントを追加

1. **Setup（設定）にアクセス**
   - 右上の歯車アイコン → Setup

2. **Lightning App Builderを開く**
   - Quick Find（クイック検索）で「Lightning App Builder」を検索
   - または：Object Manager → Opportunity → Lightning Record Pages

3. **商談レコードページを編集**
   - 既存のレコードページを選択（例: Opportunity Record Page）
   - または「New」をクリックして新規作成

4. **コンポーネントを追加**
   - 左側のコンポーネント一覧から「DocuSign Sender Component」を探す
   - 配置したいセクション（例：右サイドバー）にドラッグ&ドロップ

5. **保存してアクティベート**
   - 「Save」をクリック
   - 「Activate」をクリック
   - 適用先のレコードタイプやアプリケーションを選択
   - 「Save」で完了

### ステップ4: 権限設定

#### Apexクラスへのアクセス権限

1. **Setup → Permission Sets または Profiles**
2. 対象のPermission Set/Profileを開く
3. **Apex Class Access**に移動
4. 「Edit」をクリック
5. `DocuSignEnvelopeController`を「Enabled Apex Classes」に追加
6. 「Save」

#### DocuSign機能へのアクセス権限

既にDocuSign eSignature for Salesforceパッケージがインストールされているため、
必要に応じてDocuSign関連の権限を確認してください。

## 📝 使用方法

### 1. 商談レコードにPDFファイルをアップロード

- 商談レコードページの「Files」タブを開く
- 「Upload Files」をクリック
- PDFファイルを選択してアップロード

### 2. コンポーネントから署名依頼を送信

1. 商談レコードページで「DocuSign 署名依頼」コンポーネントを表示
2. ドロップダウンから送信するPDFファイルを選択
3. 受信者名を入力（例：山田 太郎）
4. 受信者メールアドレスを入力（例：example@example.com）
5. 「DocuSignで送信」ボタンをクリック

### 3. 送信結果の確認

- 成功した場合：緑色の成功メッセージとエンベロープIDが表示されます
- エラーの場合：赤色のエラーメッセージが表示されます
- 送信履歴は商談の「Activity」タブにタスクとして記録されます

## ⚙️ 技術仕様

### Apexコントローラー

**DocuSignEnvelopeController.cls**

- `getOpportunityPDFFiles(Id recordId)`: 商談に添付されたPDFファイルを取得
- `sendDocuSignEnvelope(...)`: DocuSignエンベロープを作成・送信
- DocuSign Toolkit (dsfs名前空間) を使用

### LWCコンポーネント

**docusignSenderComponent**

- 商談レコードページ専用コンポーネント
- リアクティブなフォームバリデーション
- メールアドレス形式チェック
- ローディング状態の管理
- エラーハンドリング

### DocuSign API統合

- **使用パッケージ**: DocuSign eSignature for Salesforce (dsfs名前空間)
- **バージョン**: 7.12.3
- **エンベロープ設定**:
  - 署名タブ: 自動配置（ページ1, 座標100,100）
  - 署名日付タブ: 自動配置（ページ1, 座標100,150）

## 🐛 トラブルシューティング

### エラー: "PDFファイルが添付されていません"

**原因**: 商談にPDFファイルが添付されていない

**解決方法**:
1. 商談レコードページの「Files」タブを開く
2. PDFファイルをアップロード
3. ページをリフレッシュ

### エラー: "dsfs名前空間が見つかりません"

**原因**: DocuSignパッケージが正しくインストールされていない

**解決方法**:
1. Setup → Installed Packages で「DocuSign eSignature for Salesforce」を確認
2. インストールされていない場合は、AppExchangeからインストール

### エラー: "Apex class access denied"

**原因**: ユーザーに適切な権限がない

**解決方法**:
1. Setup → Permission Sets
2. 対象のPermission Setに`DocuSignEnvelopeController`へのアクセス権限を追加

### コンポーネントが表示されない

**原因**: Lightning Record Pageに追加されていない

**解決方法**:
1. Setup → Lightning App Builder
2. 商談レコードページを編集
3. コンポーネントを追加

## 🔧 カスタマイズ

### 署名タブの位置を変更

`DocuSignEnvelopeController.cls`の`createAndSendEnvelope`メソッド内で、
以下の値を調整してください：

```apex
signTab.XPosition = '100';  // 横位置
signTab.YPosition = '100';  // 縦位置
```

### メール件名・本文をカスタマイズ

```apex
envelope.EmailSubject = '【署名依頼】 ' + cv.Title;
envelope.EmailBlurb = 'こちらの文書に署名をお願いいたします。';
```

### 複数の受信者に対応

現在は1名の署名者のみサポートしています。
複数受信者に対応する場合は、LWCとApexの両方を修正する必要があります。

## 📚 参考資料

- [DocuSign for Salesforce Developer Center](https://developers.docusign.com/docs/esign-rest-api/)
- [Salesforce Lightning Web Components Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [DocuSign Apex Toolkit Documentation](https://support.docusign.com/s/document-item?language=en_US&bundleId=ape1643226870854&topicId=waq1578456500716.html)

## ✅ チェックリスト

デプロイ前に以下を確認してください：

- [ ] DocuSign eSignature for Salesforceパッケージがインストール済み
- [ ] Salesforce CLIがインストール済み
- [ ] 接続先Orgにログイン済み（`sf org display`で確認）
- [ ] すべてのファイルがforce-app/main/defaultディレクトリに配置済み
- [ ] デプロイコマンドを実行（`sf project deploy start`）
- [ ] Lightning Record Pageにコンポーネントを追加
- [ ] 必要な権限を設定
- [ ] テスト用の商談にPDFファイルをアップロード
- [ ] 動作確認完了

## 📞 サポート

問題が発生した場合は、以下の情報を含めて報告してください：

1. エラーメッセージの全文
2. 実行した手順
3. Salesforce Orgの種類（本番/Sandbox/Developer Edition）
4. DocuSignパッケージのバージョン