# 09: テクニカルアーキテクト Agent 設計書（追加シナリオ・デモ投影のみ）

## 🤖 基本情報


| 項目                | 値                      |
| ----------------- | ---------------------- |
| **作成先DB**         | `RETAIL_BANKING_DB`    |
| **作成先スキーマ**       | `AGENT`                |
| **エージェントオブジェクト名** | `TECH_ARCHITECT_AGENT` |


---

## 📝 エージェント説明

### 概要

```
Snowflake のテクニカルアーキテクトとして、技術調査・アーキテクチャ設計を支援する AI エージェントです。
Snowflake 公式ドキュメント（Marketplace CKE）と Web 検索（Zenn / Qiita / note 等）を
組み合わせて、公式情報とコミュニティの実践知を統合した回答を生成します。
```

### エージェント使用方法

```
このエージェントは以下の情報源を活用して質問に回答します：

1. 【公式ドキュメント】Snowflake Documentation（Marketplace CKE）
   → 機能仕様、SQL 構文、ベストプラクティス、設定手順など

2. 【Web 検索】Zenn / Qiita / note 等の日本語技術記事
   → 実装例、ユースケース事例、コミュニティの知見など

質問は自然な日本語で入力してください。
```

---

## 💬 サンプル質問

### 易しい質問（初・中級）— 基本機能の比較・設定方法

| #   | 質問                                                                                       | 使用ツール                |
| --- | ---------------------------------------------------------------------------------------- | -------------------- |
| 1   | Snowflake の一時テーブル（Temporary Table）と通常のテーブルの違いを教えてください                                     | CKE（公式ドキュメント）        |
| 2   | Snowflake のウェアハウスで AUTO_SUSPEND と AUTO_RESUME はどう設定すべきですか？                                 | CKE（公式ドキュメント）        |
| 3   | Snowflake の内部ステージと外部ステージの違いと使い分けを教えてください                                                  | CKE（公式ドキュメント）        |
| 4   | Snowflake の Time Travel 機能の使い方を日本語の記事で探して                                                  | Web Search           |
| 5   | Snowflake と Python の連携方法について、Qiita や Zenn の記事を探して                                          | Web Search           |
| 6   | Snowflake の View とマテリアライズドビューの違いについて、公式ドキュメントと日本語の解説記事の両方で教えてください | CKE + Web Search（複合） |

### 難しい質問（上級）— アーキテクチャ設計・複合的な技術判断

| #   | 質問                                                         | 使用ツール                |
| --- | ---------------------------------------------------------- | -------------------- |
| 1   | Dynamic Tables と Streams + Tasks の違いを教えてください。どちらを使うべきですか？  | CKE（公式ドキュメント）        |
| 2   | Snowflake で Iceberg Tables を使うメリットと設定手順を教えて                | CKE（公式ドキュメント）        |
| 3   | Snowflake の Dynamic Tables を使ったデータパイプラインの実装例を日本語で探して       | Web Search           |
| 4   | Cortex AI Functions の活用事例を Qiita や Zenn で検索して              | Web Search           |
| 5   | Iceberg Tables について、公式ドキュメントの仕様と日本語コミュニティでの実践事例の両方を教えてください | CKE + Web Search（複合） |
| 6   | Snowflake のコスト最適化について、公式ベストプラクティスと日本企業の事例を合わせてまとめてください     | CKE + Web Search（複合） |


---

## 🔄 オーケストレーション手順

```
1. ユーザーからの質問を受け取り、質問の意図を分析する

2. 質問の内容に応じて、適切なツールを選択する：
   - Snowflake の機能・構文・ベストプラクティスに関する質問
     → Snowflake_Documentation（Cortex Search / CKE）を使用
   - 日本語の技術記事・実装例・ユースケース事例の検索
     → Web_Search を使用

3. 複合的な質問の場合は、複数のツールを順次実行し、結果を統合する
   - 例：「Iceberg Tables の仕様と実践事例」
     → 公式ドキュメント検索 + Web 検索 を組み合わせ

4. 取得した情報を整理し、ユーザーにわかりやすい形式で回答を生成する
```

---

## 📋 応答手順

```
1. 質問に対する回答は必ず日本語で行うこと

2. 回答の構成：
   - まず結論を簡潔に述べる
   - 技術的な詳細・手順を説明する
   - コード例がある場合は SQL / Python のコードブロックで提示する
   - 注意事項・制限事項があれば明記する

3. 複数の選択肢がある場合：
   - 比較表を作成してトレードオフを明示する

4. 参考情報の記載：
   - 回答の末尾に【参考ドキュメント】セクションを設ける
   - 公式ドキュメントの URL を箇条書きで記載する
   - Web 検索結果を使用した場合は、記事のタイトルと URL を明記する

5. 情報が見つからない場合：
   - 「該当する情報が見つかりませんでした」と回答する
   - 関連する別の情報があれば提案する
```

---

## 🛠️ ツール一覧


| ツール名                        | 種別                 | 説明                   | オブジェクトパス                                                    |
| --------------------------- | ------------------ | -------------------- | ----------------------------------------------------------- |
| **Snowflake_Documentation** | Cortex Search（CKE） | Snowflake 公式ドキュメント検索 | `SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE` |
| **Web_Search**              | Web Search         | Web 上の技術記事検索         | （ビルトイン）                                                     |


---

## 📊 ツール詳細

### 1. Snowflake_Documentation（Cortex Search / CKE）

**データソース：**

- Snowflake Marketplace「Cortex Knowledge Extension: Snowflake Documentation」

**ツール説明（Agent向け・コピペ用）：**

```
Snowflake 公式ドキュメントを検索します。機能の仕様、SQL 構文、ベストプラクティス、設定手順などの公式情報を取得できます。
```

**CKE 設定値：**


| 項目                    | 値                                                           |
| --------------------- | ----------------------------------------------------------- |
| Cortex Search Service | `SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE` |
| ID Column             | `SOURCE_URL`                                                |
| Title Column          | `DOCUMENT_TITLE`                                            |
| Max Results           | `5`                                                         |


**回答可能な質問例：**

- 「Dynamic Tables の TARGET_LAG の設定方法と推奨値を教えてください」
- 「Cortex Search Service の作成手順と必要な権限を教えて」
- 「Snowflake の Hybrid Tables とは何ですか？ユースケースを教えて」

### 2. Web_Search（Web Search）

**データソース：**

- Web 上の技術記事（Zenn、Qiita、note 等）

**ツール説明（Agent向け・コピペ用）：**

```
Web 上の技術記事（Zenn、Qiita、note 等）を検索します。日本語の実装例、ユースケース事例、コミュニティの知見を取得できます。
```

**回答可能な質問例：**

- 「Snowflake の Dynamic Tables を使ったデータパイプラインの実装例を日本語で探して」
- 「Snowflake Cortex AI Functions の活用事例を Qiita や Zenn で検索して」
- 「Snowflake と dbt の連携について、日本語の技術ブログを探して」

---

## 🔧 前提条件・セットアップ

### Step 1: Snowflake Documentation CKE の取得

1. Snowsight にログイン
2. 左メニュー → **Data Products** → **Marketplace**
3. 検索バーで **「Snowflake Documentation」** を検索
4. **「Cortex Knowledge Extension: Snowflake Documentation」**（提供元: Snowflake）をクリック
5. **「Get」** をクリックして取得

取得後に追加されるオブジェクト：


| オブジェクト                | パス                                                          |
| --------------------- | ----------------------------------------------------------- |
| データベース                | `SNOWFLAKE_DOCUMENTATION`                                   |
| スキーマ                  | `SNOWFLAKE_DOCUMENTATION.SHARED`                            |
| Cortex Search Service | `SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE` |


動作確認 SQL：

```sql
USE ROLE ACCOUNTADMIN;
DESCRIBE CORTEX SEARCH SERVICE SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE;

SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE',
    '{
        "query": "What is Dynamic Tables?",
        "columns": ["CHUNK", "DOCUMENT_TITLE", "SOURCE_URL"]
    }'
);
```

### Step 2: Web Search の有効化

```sql
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET WEB_SEARCH_ENABLED = TRUE;
```

> **注意**: Web Search は Cortex Agent のビルトインツールとして提供されており、外部 API キーなどの設定は不要。Agent に `web_search` タイプのツールを追加するだけで利用可能。

### Step 3: Agent の作成

上記の「基本情報」「エージェント説明」「サンプル質問」「オーケストレーション手順」「応答手順」「ツール詳細」の各セクション内のコードブロックを、Snowsight の GUI（AI & ML → Agents → Create agent）の対応する入力欄にコピペしてください。

### Step 4: 動作確認

1. Snowsight → **AI & ML** → **Snowflake Intelligence**
2. ドロップダウンから **「テクニカルアーキテクト」** を選択
3. サンプル質問を試す

---

## ⚠️ 注意事項

- **Web Search のコスト**: Web Search はクエリごとにクレジットを消費する。デモ時は必要なクエリに絞ること
- **Cross-region inference**: CKE が利用しているリージョンと異なるリージョンのアカウントの場合、以下の設定が必要

```sql
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

- **Web Search の利用可能リージョン**: Web Search は一部リージョンでのみ利用可能。利用できない場合は上記の Cross-region 設定を適用
- **デモ投影専用**: このシナリオはデモ投影用であり、本番環境への適用時は別途セキュリティ・ガバナンスの検討が必要
- **既存 Agent との共存**: `RETAIL_BANKING_AGENT`（既存）と `TECH_ARCHITECT_AGENT`（本シナリオ）は別の Agent オブジェクトとして共存可能。Snowflake Intelligence UI のドロップダウンで切り替えて使用する

---

## 📁 関連ファイル


| ファイル                                  | 説明                                |
| ------------------------------------- | --------------------------------- |
| `01_db_setup.sql`                     | 環境構築・データ投入SQL                     |
| `06_agent_design.md`                  | 既存 Agent（RETAIL_BANKING_AGENT）設計書 |
| `08_marketplace_weather_demo.md`      | Marketplace 天気デモ                  |
| `resources/99_Intelligence_setup.sql` | Snowflake Intelligence 公開設定       |


