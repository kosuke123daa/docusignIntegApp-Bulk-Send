# DocuSign × Salesforce 統合アプリ

Salesforce上でDocuSign IAM（Navigator / Workspaces）およびeSignatureをネイティブ連携するSalesforce DXプロジェクトです。Agentforce（AIエージェント）からの呼び出しにも対応しています。

---

## 実装機能一覧

### 1. DocuSign Navigator 連携

DocuSign Navigatorに格納された契約書（合意文書）をSalesforceから検索・参照・AI要約する機能です。

| コンポーネント | 種別 | 役割 |
|---|---|---|
| `NavigatorService` | Apexクラス | JWT認証・API共通呼び出し（GET/POST） |
| `NavigatorController` | Apexクラス | LWC向け `@AuraEnabled` メソッド群 |
| `NavigatorAgentAction` | Apexクラス | Agentforce向け `@InvocableMethod` |
| `navigatorExplorer` | LWC | 契約書一覧・詳細・AI要約のブラウザUI |

**主な機能：**
- 契約書一覧の検索（ステータス・取引先名・文書種別・タイトル・有効日・満了日・取込元でフィルタリング）
- 特定契約書の詳細表示（有効日・満了日・契約総額・更新タイプ・準拠法など主要条項）
- AI要約生成（`/ai/actions/summarize` エンドポイント使用）
- Agentforceから自然言語で呼び出し可能（「来月期限の契約書は？」「XX社のNDA一覧を見せて」など）

---

### 2. DocuSign eSignature 連携（Agentforce対応）

商談に添付されたPDFをDocuSignエンベロープとして署名依頼送信する機能です。

| コンポーネント | 種別 | 役割 |
|---|---|---|
| `DocuSignAgentAction` | Apexクラス | Agentforce向け `@InvocableMethod` |
| `DocuSignEnvelopeController` | Apexクラス | `docusignSenderComponent` LWC向けコントローラー |
| `GetEnvelopesAction` | Apexクラス | 商談紐づきエンベロープ一覧取得 Agentforceアクション |
| `GetRecordAttachmentsAction` | Apexクラス | レコード添付ファイル一覧取得 Agentforceアクション |
| `docusignSenderComponent` | LWC | 手動でのエンベロープ送信UI |

**主な機能：**
- 商談の添付PDFを指定してDocuSign署名依頼を送信（DocuSign for Salesforce パッケージの `dfsle` ライブラリ使用）
- `@future(callout=true)` による非同期送信でSalesforceのコールアウト制限を回避（Agentforce経由）
- 送信完了後に商談へタスクとして自動記録
- Agentforceから「〇〇さんに署名依頼を送って」で呼び出し可能
- 商談に紐づくエンベロープ一覧とDocuSign詳細URLをAgentforceから返答可能

---

### 3. DocuSign Workspaces 連携

商談ページ上でDocuSign Workspacesを管理するLWCコンポーネントです。Agentforceからの操作にも対応しています。

| コンポーネント | 種別 | 役割 |
|---|---|---|
| `WorkspaceService` | Apexクラス | Workspaces API全操作の共通サービス |
| `WorkspaceController` | Apexクラス | LWC向け `@AuraEnabled` メソッド群 |
| `workspaceManager` | LWC | ワークスペース管理UI（商談ページ配置） |
| `GetWorkspaceInfoAction` | Apexクラス | Agentforce向け：タスク・メンバー情報取得 |
| `CreateWorkspaceAction` | Apexクラス | Agentforce向け：ワークスペース作成 |
| `CreateWorkspaceUploadRequestAction` | Apexクラス | Agentforce向け：アップロードリクエスト作成 |
| `AddWorkspaceUserAction` | Apexクラス | Agentforce向け：ワークスペースユーザー追加 |
| `UploadWorkspaceDocumentAction` | Apexクラス | Agentforce向け：ドキュメントアップロード |

**主な機能（4タブ構成）：**

| タブ | 機能 |
|---|---|
| ワークスペース | 作成・情報表示・タスク一覧（アップロードリクエスト＋エンベロープ）・メンバー一覧 |
| ドキュメント | 商談添付ファイルのアップロード・ワークスペース内ドキュメント一覧 |
| ユーザー | 商談の関連コンタクトから選択して追加・メールアドレス直接入力・ロール指定 |
| エンベロープ | ドラフト作成フォーム |
| アップロードリクエスト | ワークスペースユーザーをプルダウン選択して書類提出依頼を作成 |

**タスク一覧の詳細（ワークスペースタブ）：**
- アップロードリクエストとエンベロープを統合表示し、最終更新日時で降順ソート
- エンベロープ名はWorkspaces APIだけでは取得できないため、eSignature API（`/v2.1/accounts/{accountId}/envelopes?envelope_ids=...`）で補完
- ステータスを日本語表示（`draft`→ドラフト、`sent`→送信済み、`completed`→完了 など）
- アップロードリクエストの担当者はワークスペースユーザー一覧とUUIDで照合して氏名を表示
- ドラフト状態のエンベロープには「編集」ボタンを表示し、DocuSign送信画面（`apps-d.docusign.com`）を別タブで開く

**Agentforce対応アクション：**

| アクション | label | 呼び出し例 |
|---|---|---|
| `GetWorkspaceInfoAction` | ワークスペース情報取得 | 「ワークスペースの状況を教えて」「タスクの進捗は？」 |
| `CreateWorkspaceAction` | ワークスペース作成 | 「ワークスペースを作って」「DocuSignのスペースを準備して」 |
| `CreateWorkspaceUploadRequestAction` | アップロードリクエスト作成 | 「見積書を提出するよう依頼して」「アップロードリクエストを作って」 |
| `AddWorkspaceUserAction` | ワークスペースユーザー追加 | 「〇〇さんをワークスペースに追加して」「メンバーを招待して」 |
| `UploadWorkspaceDocumentAction` | ワークスペースへドキュメントをアップロード | 「〇〇のファイルをワークスペースにアップロードして」（`GetRecordAttachmentsAction` と併用） |

**技術的な実装ポイント：**
- ワークスペースIDの変換：APIが返すUUID（`001e2eb1-0000-...`）と表示用数値ID（`1978028`）を相互変換
- ドキュメントアップロード：`multipart/form-data` をApexで構築（Hex連結方式でバイト境界問題を回避）
- 外部ユーザー対応：`CANNOT_ASSIGN_INTERNAL_ROLE_TO_EXTERNAL_USER` エラー時は `role_id` なしで自動リトライ
- 商談カスタム項目 `DocuSign_Workspace_Id__c` にワークスペースIDを保存して永続化
- eSignature API呼び出し用に Remote Site Setting（`DocuSign_Demo`）を追加（`https://demo.docusign.net`）
- `AddWorkspaceUserAction` は姓名省略時にSalesforceのContact・Userレコードから自動補完

---

## アーキテクチャ

```
Salesforce
├── LWC（UI）
│   ├── navigatorExplorer           ← 契約書ブラウザ
│   ├── workspaceManager            ← ワークスペース管理（商談ページ）
│   └── docusignSenderComponent     ← eSignature手動送信
│
├── Apex Controllers（@AuraEnabled）
│   ├── NavigatorController
│   ├── WorkspaceController
│   └── DocuSignEnvelopeController
│
├── Apex Services（API呼び出し）
│   ├── NavigatorService    ← JWT認証 + Navigator/Workspaces API共通
│   └── WorkspaceService    ← Workspaces API個別操作
│
└── Agentforce Invocable Actions（@InvocableMethod）
    ├── NavigatorAgentAction              ← 契約書検索・詳細・AI要約
    ├── DocuSignAgentAction               ← eSignature送信（非同期）
    ├── GetEnvelopesAction                ← エンベロープ一覧と詳細URL
    ├── GetRecordAttachmentsAction        ← 添付ファイル一覧
    ├── GetWorkspaceInfoAction             ← ワークスペースのタスク・メンバー取得
    ├── CreateWorkspaceAction              ← ワークスペース作成
    ├── CreateWorkspaceUploadRequestAction ← アップロードリクエスト作成
    ├── AddWorkspaceUserAction             ← ワークスペースユーザー追加
    └── UploadWorkspaceDocumentAction      ← ドキュメントアップロード
```

**認証フロー（Navigator / Workspaces API）：**
```
Salesforce Apex
  → JWT生成（RS256署名、秘密鍵はカスタムメタデータに保存）
  → DocuSign OAuth2.0トークンエンドポイント（account-d.docusign.com）
  → アクセストークン取得
  → Named Credential（DocuSign_Navigator）経由でAPI呼び出し
```

---

## セットアップ

### 前提条件

- Salesforce Developer Org（または Sandbox）
- DocuSign Developer アカウント（IAM / Navigator / Workspaces 有効化済み）
- DocuSign for Salesforce パッケージ（eSignature連携に必要、`dfsle` 名前空間）
- Salesforce CLI（`sf`）

### 1. カスタムメタデータの設定

設定 → カスタムメタデータ型 → `DocuSign JWT Config` → `Default` レコードに以下を入力：

| 項目 | 値 |
|---|---|
| Integration Key | DocuSignアプリのClient ID（GUID） |
| User ID | DocuSignアカウントのUser ID（GUID） |
| Private Key | RSA秘密鍵（PEM形式、`-----BEGIN RSA PRIVATE KEY-----` ヘッダーごと） |
| Account ID | DocuSignアカウントID（GUID形式） |
| Auth Server | `https://account-d.docusign.com`（本番は `https://account.docusign.com`） |

### 2. 指定ログイン情報のデプロイ

指定ログイン情報（`DocuSign_Navigator`）はソースに含まれているため、デプロイするだけで自動作成されます。手動設定は不要です。

### 3. DocuSign コンセント（JWT認証の事前同意）

JWT認証でImpersonationを使用するため、DocuSign側でユーザーの同意が必要です。**以下のURLをブラウザで開き、DocuSignアカウントでログインして承認**してください：

```
https://account-d.docusign.com/oauth/auth?response_type=code&scope=signature%20adm_store_unified_repo_read%20dtr.rooms.write%20dtr.rooms.read%20dtr.company.read%20dtr.documents.write%20dtr.documents.read&client_id=YOUR_INTEGRATION_KEY&redirect_uri=https://www.docusign.com
```

`YOUR_INTEGRATION_KEY` をカスタムメタデータに設定したIntegration Keyに置き換えてください。

**重要:** 承認後にDocuSignのトップページにリダイレクトされれば成功です。

**注意事項:**
- `signature` スコープのみでコンセントした場合、残りのスコープが未承認となり `consent_required` エラーが発生します
- コンセントはIntegration Keyとユーザー（User ID）の組み合わせに紐づくため、User IDを変更した場合は再度コンセントが必要です
- コンセントはDocuSignのデモ環境（`account-d.docusign.com`）と本番環境で別々に必要です

### 4. デプロイ

```bash
# 全コンポーネントをデプロイ
sf project deploy start --source-dir force-app --ignore-conflicts

# 特定ファイルのみデプロイ
sf project deploy start --source-dir force-app/main/default/classes/WorkspaceService.cls --ignore-conflicts
```

### 5. 商談ページへの配置

Lightning App Builder で商談レコードページに以下のコンポーネントを追加：

- `workspaceManager`：Workspaces管理パネル
- `docusignSenderComponent`：eSignature手動送信パネル

---

## API エンドポイント（開発環境）

| API | ベースURL |
|---|---|
| Navigator（契約書） | `https://api-d.docusign.com/v1/accounts/{accountId}/agreements` |
| Workspaces | `https://api-d.docusign.com/v1/accounts/{accountId}/workspaces` |
| eSignature（REST API） | `https://demo.docusign.net/restapi`（本番: `https://www.docusign.net/restapi`） |
| eSignature（パッケージ） | DocuSign for Salesforce パッケージ（`dfsle`）経由 |
