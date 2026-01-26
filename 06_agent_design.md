# Snowflake Intelligence向けAgent 設計書

## 🤖 基本情報

| 項目 | 値 |
|------|-----|
| **作成先DB** | `RETAIL_BANKING_DB` |
| **作成先スキーマ** | `AGENT` |
| **エージェントオブジェクト名** | `RETAIL_BANKING_AGENT` |

---

## 📝 エージェント説明

### 概要

```
リテールバンキング向けの顧客・預金取引分析を支援するAIエージェントです。
顧客属性情報（氏名、住所、年収、業種等）、名寄せデータ（統合顧客番号）、
流動性預金取引データ（入出金、残高）を横断的に分析し、
営業担当者・渉外担当者の意思決定をサポートします。
```

### エージェント使用方法

```
このエージェントは以下の情報源を活用して質問に回答します：

1. 【構造化データ】顧客基本属性情報、統合顧客インデクス、流動性預金取引データ
   → 顧客数、取引金額、純資金流入額、顧客セグメント分析など

質問は自然な日本語で入力してください。

【将来拡張予定】
2. 【内部規定】預金規定、マニュアル、商品説明書
3. 【顧客対応履歴】コールセンター対応記録、窓口相談メモ
```

---

## 💬 サンプル質問（6つ）

| # | 質問 | 使用ツール |
|---|------|-----------|
| 1 | 今月の総顧客数と新規顧客数を教えてください | Cortex Analyst |
| 2 | 純資金流入額はいくらですか？ | Cortex Analyst |
| 3 | チャネル別の取引件数を比較してください | Cortex Analyst |
| 4 | 年収1000万円以上の個人顧客は何名いますか？ | Cortex Analyst |
| 5 | 統合顧客番号単位で取引金額が多い顧客トップ5は？ | Cortex Analyst |
| 6 | 法人顧客の業種別取引金額を教えてください | Cortex Analyst |

---

## 🔄 オーケストレーション手順

```
1. ユーザーからの質問を受け取り、質問の意図を分析する

2. 質問の内容に応じて、適切なツールを選択する：
   - 顧客情報・取引データに関する質問
     → RETAIL_BANKING_ANALYSIS_SV（Cortex Analyst）を使用
   - （将来拡張）内部規定・マニュアルに関する質問
     → INTERNAL_DOCS_SEARCH（Cortex Search）を使用
   - （将来拡張）顧客対応履歴に関する質問
     → CUSTOMER_INTERACTION_SEARCH（Cortex Search）を使用

3. 取得した情報を整理し、ユーザーにわかりやすい形式で回答を生成する
```

---

## 📋 応答手順

```
1. 質問に対する回答は必ず日本語で行うこと

2. 回答の構成：
   - まず結論を簡潔に述べる
   - 必要に応じて詳細データ（表形式）を提示する
   - 情報の出典（テーブル名）を明記する

3. 数値データを含む場合：
   - 単位（円、万円、名など）を明記する
   - 基準日を明記する

4. 情報が見つからない場合：
   - 「該当する情報が見つかりませんでした」と回答する
   - 関連する別の情報があれば提案する
```

---

## 🛠️ ツール一覧

| ツール名 | 種別 | 説明 | オブジェクトパス |
|---------|------|------|-----------------|
| **RETAIL_BANKING_ANALYSIS_SV** | Semantic View | 顧客・取引の構造化データ分析 | `RETAIL_BANKING_DB.ANALYTICS.RETAIL_BANKING_ANALYSIS_SV` |
| **INTERNAL_DOCS_SEARCH** | Cortex Search | 内部規定・マニュアル検索（将来拡張） | `RETAIL_BANKING_DB.UNSTRUCTURED_DATA.INTERNAL_DOCS_SEARCH` |
| **CUSTOMER_INTERACTION_SEARCH** | Cortex Search | 顧客対応履歴検索（将来拡張） | `RETAIL_BANKING_DB.UNSTRUCTURED_DATA.CUSTOMER_INTERACTION_SEARCH` |
| **SEND_EMAIL** | Stored Procedure | メール送信（将来拡張） | `RETAIL_BANKING_DB.AGENT.SEND_EMAIL` |
| **GET_CUSTOMER_SUMMARY** | Stored Procedure | 顧客サマリー取得（将来拡張） | `RETAIL_BANKING_DB.AGENT.GET_CUSTOMER_SUMMARY` |

---

## 📊 ツール詳細

### 1. RETAIL_BANKING_ANALYSIS_SV（Cortex Analyst）

**対象テーブル：**
- 顧客基本属性情報＿月次（顧客マスタ）
- 統合顧客＿インデクス＿月次（名寄せ）
- 流動性預金取引データ＿日次（取引履歴）

**回答可能な質問例：**
- 顧客数（総顧客数、新規顧客数、解約顧客数）
- 顧客セグメント分析（年収別、業種別、年齢層別）
- 取引分析（入出金、チャネル別、摘要別）
- 名寄せ分析（統合顧客単位の集計）
- KPI（純資金流入額、総取引金額）

### 2. INTERNAL_DOCS_SEARCH（将来拡張）

**検索対象（予定）：**
- 預金規定、為替取引規定
- 本人確認マニュアル
- 商品パンフレット（住宅ローン、カードローン等）

**回答可能な質問例：**
- 「普通預金の解約手続きは？」
- 「本人確認書類として使えるものは？」
- 「住宅ローンの金利優遇条件は？」

### 3. CUSTOMER_INTERACTION_SEARCH（将来拡張）

**検索対象（予定）：**
- コールセンター対応記録
- 窓口相談メモ
- クレーム対応履歴

**回答可能な質問例：**
- 「この顧客との過去のやり取りは？」
- 「住所変更に関する問い合わせ対応事例は？」

---

## 📁 関連ファイル

| ファイル | 説明 |
|---------|------|
| `01_db_setup.sql` | 環境構築・データ投入SQL |
| `02_ai_functions_demo.sql` | Cortex AI Functions デモ |
| `03_sv_setup.sql` | Semantic View設定（GUI参照用） |
| `04_rag_setup.sql` | Cortex Search設定（将来拡張テンプレート） |
| `05_sproc_setup.sql` | Stored Procedure（将来拡張テンプレート） |
| `resources/99_Intelligence_setup.sql` | Snowflake Intelligence公開設定 |

---

## 🔧 Snowflake Intelligenceへのエージェント公開

GUIでエージェントを作成した後、Snowflake Intelligenceインターフェースに公開するには `resources/99_Intelligence_setup.sql` を実行してください。

詳細は [Snowflake公式ドキュメント](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence) を参照。
