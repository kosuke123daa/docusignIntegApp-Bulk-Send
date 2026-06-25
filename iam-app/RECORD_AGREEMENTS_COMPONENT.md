# recordAgreements コンポーネント（レコード紐付け）

Opportunity レコードページに配置し、そのレコードに紐づく DocuSign Agreement Manager 文書を
アップロード / 一覧表示する。認証は既存 `NavigatorService`（JWT・PKCS#1→PKCS#8変換込み・
Named Credential `DocuSign_Navigator`）を流用する。

## 構成
| ファイル | 役割 |
|---|---|
| `classes/RecordAgreementsController.cls` | 一覧(linked_dataでフィルタ) / アップロード(bulk ingestion 3ステップ) |
| `classes/RecordAgreementsControllerTest.cls` | コールアウトモックによるテスト |
| `lwc/recordAgreements/*` | アップロードUI＋一覧datatable（ファイル名→AM UIリンク） |
| `classes/NavigatorService.cls` | `getAccessToken(cfg, scope)` 追加（既存呼び出しは非破壊） |

## 一覧（追加設定なしで動作）
- `GET callout:DocuSign_Navigator/v1/accounts/{id}/agreements?include_linked_data=true&limit=100`
- 各 agreement の `linked_data[].record_id` が開いているレコードIDと一致するものを表示。
- 既定スコープ `adm_store_unified_repo_read` は既存コンポーネントで consent 済み。
- ⚠ 一覧APIが `include_linked_data=true` で linked_data を返すことが前提。デプロイ後に
  1件実データで返却を確認すること（返らない場合は単票GETでの補完が必要）。

## アップロード（前提あり）
bulk ingestion: ジョブ作成 → プリサインドURL(Azure Blob)へ PUT → 完了通知。動作には次が必要：

1. **書き込みスコープの consent**：`adm_store_unified_repo_write`。未同意だとトークン取得が
   `consent_required` で失敗。Integration Key で一度だけ同意を取得すること。
2. **Azure Blob ホストの Remote Site Settings**：プリサインドURLのホスト
   （`https://<storage>.blob.core.windows.net`）はジョブ毎に払い出される。未登録だと PUT が
   コールアウト不可で失敗する。初回アップロードのエラーに表示される `URL=` のホストを
   リモートサイトに登録する（demo環境では概ね固定のため一度登録すれば再利用可）。
3. 完了通知のエンドポイントはジョブ作成レスポンスの `_actions`（HATEOAS）を優先し、
   無ければ `.../upload/jobs/{jobId}/actions/complete` にフォールバックする。実機の
   レスポンスで完了アクション名を確認すること。

## デプロイ
```bash
sf project deploy start \
  --metadata "ApexClass:NavigatorService" \
  --metadata "ApexClass:RecordAgreementsController" \
  --metadata "ApexClass:RecordAgreementsControllerTest" \
  --metadata "LightningComponentBundle:recordAgreements" \
  --target-org NakagawaOrg
```
配置：Opportunity の Lightning レコードページ編集 → `Agreement Manager 文書（レコード紐付け）` を追加。
