# docusignIntegApp-Bulk-Send

DocuSign × Salesforce 統合アプリのSalesforce DXプロジェクトです。  
契約レコードへの一括エンベロープ送信（`force-app`）と、DocuSign IAM連携（`iam-app`）の2つのアプリケーションで構成されています。

---

## リポジトリ構成

```
（リポジトリルート）
├── force-app/          ← 契約一括エンベロープ送信アプリ
├── iam-app/            ← DocuSign IAM（Navigator / Workspaces）連携アプリ
└── sfdx-project.json   ← 両アプリを一括管理
```

---

## アプリケーション概要

### force-app：契約一括エンベロープ送信

Salesforceの契約レコードを一覧表示し、複数選択して DocuSign エンベロープを一括送信する LWC コンポーネントです。

| コンポーネント | 種別 | 役割 |
|---|---|---|
| `ContractBulkSendController` | Apexクラス | 契約一覧取得・エンベロープ一括送信・ステータス取得 |
| `contractBulkSend` | LWC | 契約一覧・送信・ステータス管理UI |

**主な機能：**
- 契約レコードの一覧表示（契約番号・開始日・終了日・契約期間・顧客調印者・メール）
- チェックボックスで複数選択して一括送信（最大99件）
- DocuSign テンプレートを使用したエンベロープ送信
- エンベロープステータスのリアルタイム更新
- 送信済みエンベロープへの直リンク（DocuSign デモ環境対応）
- 全ステータスを未送信にリセットするボタン
- dfsle（eSignature for Salesforce）Apex Toolkit を使用

**使用技術：**
- DocuSign eSignature for Salesforce マネージドパッケージ（`dfsle` 名前空間）
- `dfsle.EnvelopeService.sendEnvelopes()`（複数一括送信）
- `dfsle.StatusService.getStatus()`（ステータス取得）

---

### iam-app：DocuSign IAM 連携

DocuSign IAM（Navigator / Workspaces）および eSignature を Salesforce からネイティブ連携するアプリです。Agentforce（AIエージェント）からの呼び出しにも対応しています。

詳細は [iam-app/README.md](iam-app/README.md) を参照してください。

**主な機能：**
- DocuSign Navigator 連携（契約書検索・詳細表示・AI要約）
- DocuSign eSignature 連携（商談添付PDFの署名依頼送信）
- DocuSign Workspaces 連携（ワークスペース管理UI・Agentforce操作）
- Agentforce（AIエージェント）からの自然言語呼び出し対応

---

## セットアップ

### 前提条件

- Salesforce Developer Org（または Sandbox）
- DocuSign Developer アカウント（デモ環境）
- DocuSign for Salesforce パッケージ（`dfsle` 名前空間）インストール済み
- Salesforce CLI（`sf`）

### デプロイ

```bash
# リポジトリのクローン
git clone https://github.com/kosuke123daa/docusignIntegApp-Bulk-Send.git
cd docusignIntegApp-Bulk-Send

# 全コンポーネントを一括デプロイ（force-app + iam-app）
sf project deploy start --source-dir force-app --source-dir iam-app --target-org <エイリアス>

# または個別にデプロイ
sf project deploy start --source-dir force-app --target-org <エイリアス>
sf project deploy start --source-dir iam-app --target-org <エイリアス>
```

### force-app のセットアップ

デプロイ後、Lightning App Builder でナビゲーションメニュータブに `contractBulkSend` コンポーネントを追加してください。

### iam-app のセットアップ

[iam-app/README.md のセットアップ手順](iam-app/README.md#セットアップ) を参照してください。  
カスタムメタデータ・外部ログイン情報・指定ログイン情報の設定が必要です。

---

## 対象環境

| 項目 | 値 |
|---|---|
| Salesforce API バージョン | 61.0 |
| DocuSign 環境 | デモ（Developer） |
| DocuSign eSignature URL | `https://apps-d.docusign.com` |
| DocuSign IAM API URL | `https://api-d.docusign.com` |
