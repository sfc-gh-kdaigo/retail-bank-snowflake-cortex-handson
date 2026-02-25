-- =========================================================
-- リテールバンキング向け Snowflake Intelligence ハンズオン
-- 〜顧客・預金取引分析シナリオ〜
-- 
-- 03_sv_setup.sql - Semantic View設定（Cortex Analyst用）
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql          ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← Cortex AI Functions デモ
--    3. 03_sv_setup.sql          ← 本ファイル（Semantic View設定）
--    4. 04_rag_setup.sql         ← Cortex Search設定
--    5. 05_sproc_setup.sql       ← Stored Procedure
--    6. 06_agent_design.md       ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- ⚠️ 注意:
--    Semantic Viewは英語テーブル名・英語カラム名で作成することを推奨します。
--    日本語テーブル名・カラム名では動作が不安定になる場合があります。
--    本ファイルでは両方の例を記載しています。
--
-- =========================================================

-- =========================================================
-- Semantic Viewの作成（Cortex Analyst用）
-- =========================================================
-- 
-- ⚠️ Semantic ViewはSnowsight GUIで作成します
--    以下は設定時の参考情報です（GUI画面遷移順に記載）
-- 
-- ---------------------------------------------------------
-- Step 1: Semantic View基本情報
-- ---------------------------------------------------------
-- 
-- 【Semantic View名】
--   RETAIL_BANKING_ANALYSIS_SV
-- 
-- 【SVの説明（Description）】※コピペ用
/*
リテールバンキング向けの顧客・預金取引分析用Semantic Viewです。
顧客基本属性情報（顧客マスタ）、統合顧客インデクス（名寄せ）、
流動性預金取引データ（取引履歴）の3テーブルを統合し、
顧客数、取引金額、純資金流入額などのKPIを
自然言語で分析できるようにします。
営業担当者が顧客セグメント分析、取引パターン分析、
名寄せ分析を効率的に行うことを目的としています。
*/
-- 
-- ---------------------------------------------------------
-- Step 2: サンプルSQLクエリ（説明入力後に登録）
-- ---------------------------------------------------------
-- ※ Semantic Viewのドラフト作成および精度向上のため、以下のサンプルクエリを登録してください
-- ※ SQL部分は /* */ でくくっているので、そのままコピー＆ペーストできます
-- 
-- ⚠️ 日本語テーブル/カラム名では動作が不安定なため、英語版を使用してください
--

-- =========================================================
-- ❌ 日本語テーブル/カラム名の例（動作が不安定）
-- =========================================================
-- 以下は参考として残していますが、実際のSemantic View作成には使用しないでください

/*
-- ■ 日本語版クエリ1: 顧客属性分析
SELECT 
  CASE WHEN "人格コード" = 1 THEN '個人' 
       WHEN "人格コード" = 2 THEN '法人' 
       WHEN "人格コード" = 3 THEN '個人事業主'
       ELSE 'その他' END AS "顧客区分",
  COUNT(*) AS "顧客数",
  ROUND(AVG("年収"), 0) AS "平均年収_万円"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."顧客基本属性情報＿月次"
WHERE "元帳状態表示" = 0
GROUP BY "人格コード"
ORDER BY "顧客数" DESC;

-- ■ 日本語版クエリ2: 取引分析
SELECT 
  CASE 
    WHEN t."チャネル識別コード" = 1 THEN '窓口'
    WHEN t."チャネル識別コード" = 2 THEN 'ATM'
    WHEN t."チャネル識別コード" = 3 THEN 'オンライン'
    ELSE 'その他'
  END AS "チャネル",
  COUNT(*) AS "取引件数",
  SUM(t."取引金額") AS "総取引金額"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."流動性預金取引データ＿日次" t
WHERE t."取消取引表示" = 0
GROUP BY t."チャネル識別コード"
ORDER BY "取引件数" DESC;
*/

-- =========================================================
-- ✅ 英語テーブル/カラム名の例（推奨・安定動作）
-- =========================================================
-- 以下のクエリをSemantic View作成時に使用してください

-- ■ クエリ1: 顧客属性分析（使用テーブル: CUSTOMER_ATTRIBUTES_MONTHLY）
-- 質問: 支店別の顧客数を教えてください
/*
SELECT 
  BRANCH_CODE AS "支店コード",
  COUNT(*) AS "顧客数",
  SUM(CASE WHEN ENTITY_TYPE_CODE = 1 THEN 1 ELSE 0 END) AS "個人顧客数",
  SUM(CASE WHEN ENTITY_TYPE_CODE = 2 THEN 1 ELSE 0 END) AS "法人顧客数"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_EN.CUSTOMER_ATTRIBUTES_MONTHLY
WHERE ACCOUNT_STATUS = 0
GROUP BY BRANCH_CODE
ORDER BY "顧客数" DESC;
*/

-- ■ クエリ2: 取引分析（使用テーブル: DEPOSIT_TRANSACTIONS_DAILY, CUSTOMER_ATTRIBUTES_MONTHLY）
-- 質問: チャネル別の取引件数と取引金額を教えてください
/*
SELECT 
  CASE 
    WHEN t.CHANNEL_CODE = 1 THEN '窓口'
    WHEN t.CHANNEL_CODE = 2 THEN 'ATM'
    WHEN t.CHANNEL_CODE = 3 THEN 'オンライン'
    ELSE 'その他'
  END AS "チャネル",
  COUNT(*) AS "取引件数",
  SUM(t.TXN_AMOUNT) AS "総取引金額"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_EN.DEPOSIT_TRANSACTIONS_DAILY t
WHERE t.IS_CANCELLED = 0
GROUP BY t.CHANNEL_CODE
ORDER BY "取引件数" DESC;
*/

-- ■ クエリ3: 名寄せ分析（使用テーブル: INTEGRATED_CUSTOMER_INDEX_MONTHLY, CUSTOMER_ATTRIBUTES_MONTHLY, DEPOSIT_TRANSACTIONS_DAILY）
-- 質問: 統合顧客単位で見た時、取引金額が多い顧客トップ5を教えてください
/*
SELECT 
  i.INTEGRATED_CUSTOMER_ID AS "統合顧客番号",
  MAX(c.CUSTOMER_NAME) AS "代表顧客名",
  COUNT(DISTINCT i.CUSTOMER_ID) AS "紐づき顧客数",
  SUM(t.TXN_AMOUNT) AS "総取引金額"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_EN.INTEGRATED_CUSTOMER_INDEX_MONTHLY i
JOIN RETAIL_BANKING_DB.RETAIL_BANKING_EN.CUSTOMER_ATTRIBUTES_MONTHLY c 
  ON i.BANK_CODE = c.BANK_CODE 
  AND i.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN RETAIL_BANKING_DB.RETAIL_BANKING_EN.DEPOSIT_TRANSACTIONS_DAILY t
  ON i.CUSTOMER_ID = t.CUSTOMER_ID
  AND t.IS_CANCELLED = 0
WHERE i.CUSTOMER_ID = i.PRIMARY_CUSTOMER_ID
GROUP BY i.INTEGRATED_CUSTOMER_ID
ORDER BY "総取引金額" DESC NULLS LAST
LIMIT 5;
*/

-- ■ クエリ4: KPI分析（使用テーブル: DEPOSIT_TRANSACTIONS_DAILY）
-- 質問: 純資金流入額を教えてください
/*
SELECT 
  SUM(CASE WHEN TXN_TYPE = 1 THEN TXN_AMOUNT ELSE 0 END) AS "総入金額",
  SUM(CASE WHEN TXN_TYPE = 2 THEN TXN_AMOUNT ELSE 0 END) AS "総出金額",
  SUM(CASE WHEN TXN_TYPE = 1 THEN TXN_AMOUNT ELSE 0 END) - 
  SUM(CASE WHEN TXN_TYPE = 2 THEN TXN_AMOUNT ELSE 0 END) AS "純資金流入額"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_EN.DEPOSIT_TRANSACTIONS_DAILY
WHERE IS_CANCELLED = 0;
*/

-- ■ クエリ5: 顧客増減分析（使用テーブル: CUSTOMER_ATTRIBUTES_MONTHLY）
-- 質問: 2026年1月の新規顧客数、解約顧客数、顧客純増数を教えてください
/*
SELECT 
  SUM(CASE WHEN ACCOUNT_OPEN_DATE BETWEEN 20260101 AND 20260131 THEN 1 ELSE 0 END) AS "新規顧客数",
  SUM(CASE WHEN ACCOUNT_CLOSE_DATE BETWEEN 20260101 AND 20260131 THEN 1 ELSE 0 END) AS "解約顧客数",
  SUM(CASE WHEN ACCOUNT_OPEN_DATE BETWEEN 20260101 AND 20260131 THEN 1 ELSE 0 END) -
  SUM(CASE WHEN ACCOUNT_CLOSE_DATE BETWEEN 20260101 AND 20260131 THEN 1 ELSE 0 END) AS "顧客純増数"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_EN.CUSTOMER_ATTRIBUTES_MONTHLY;
*/

-- ■ クエリ6: 総顧客数（使用テーブル: CUSTOMER_ATTRIBUTES_MONTHLY）
-- 質問: 活動中の総顧客数を教えてください
/*
SELECT 
  COUNT(*) AS "総顧客数",
  SUM(CASE WHEN ENTITY_TYPE_CODE = 1 THEN 1 ELSE 0 END) AS "個人顧客数",
  SUM(CASE WHEN ENTITY_TYPE_CODE = 2 THEN 1 ELSE 0 END) AS "法人顧客数",
  SUM(CASE WHEN ENTITY_TYPE_CODE = 3 THEN 1 ELSE 0 END) AS "個人事業主数"
FROM RETAIL_BANKING_DB.RETAIL_BANKING_EN.CUSTOMER_ATTRIBUTES_MONTHLY
WHERE ACCOUNT_STATUS = 0;
*/

-- ---------------------------------------------------------
-- Step 3: テーブル・リレーションシップ・メトリクス設定
-- ---------------------------------------------------------
-- 
-- ⚠️ サンプルクエリから自動的にテーブル/カラム選択、リレーションシップ定義されていることを確認してください。
-- 【対象テーブル】
--   - RETAIL_BANKING_DB.RETAIL_BANKING_EN.CUSTOMER_ATTRIBUTES_MONTHLY
--   - RETAIL_BANKING_DB.RETAIL_BANKING_EN.INTEGRATED_CUSTOMER_INDEX_MONTHLY
--   - RETAIL_BANKING_DB.RETAIL_BANKING_EN.DEPOSIT_TRANSACTIONS_DAILY
-- 
-- 【リレーションシップ】
--   - DEPOSIT_TRANSACTIONS_DAILY.CUSTOMER_ID → CUSTOMER_ATTRIBUTES_MONTHLY.CUSTOMER_ID (Many:1)
--   - INTEGRATED_CUSTOMER_INDEX_MONTHLY.CUSTOMER_ID → CUSTOMER_ATTRIBUTES_MONTHLY.CUSTOMER_ID (1:1)
--   - DEPOSIT_TRANSACTIONS_DAILY.CUSTOMER_ID → INTEGRATED_CUSTOMER_INDEX_MONTHLY.CUSTOMER_ID (Many:1)
--
-- ⚠️ 以下のメトリクス定義とシノニム設定はSnowsight GUIで行ってください。
-- 【定義するメトリクス（KPI）】
--   1. NET_FUND_INFLOW: SUM(CASE WHEN TXN_TYPE=1 THEN TXN_AMOUNT ELSE 0 END) - SUM(CASE WHEN TXN_TYPE=2 THEN TXN_AMOUNT ELSE 0 END)
--      - Synonyms: 純資金流入額, net fund inflow, fund inflow
--   2. TOTAL_TRANSACTION_AMOUNT: SUM(TXN_AMOUNT)
--      - Synonyms: 総取引金額, total transaction amount, transaction total
--   3. TOTAL_CUSTOMERS: COUNT(*) WHERE ACCOUNT_STATUS = 0
--      - Synonyms: 総顧客数, total customers, customer count
--   4. NEW_CUSTOMERS: SUM(CASE WHEN ACCOUNT_OPEN_DATE BETWEEN 当月初 AND 当月末 THEN 1 ELSE 0 END)
--      - Synonyms: 新規顧客数, new customers, new accounts
--   5. CHURNED_CUSTOMERS: SUM(CASE WHEN ACCOUNT_CLOSE_DATE BETWEEN 当月初 AND 当月末 THEN 1 ELSE 0 END)
--      - Synonyms: 解約顧客数, churned customers, closed accounts
--   6. NET_CUSTOMER_GROWTH: NEW_CUSTOMERS - CHURNED_CUSTOMERS
--      - Synonyms: 顧客純増数, net customer growth, customer net increase
-- 
-- 【テーブルのSynonyms】
--   - CUSTOMER_ATTRIBUTES_MONTHLY: 顧客マスタ, 顧客情報, customer master, customer info
--   - INTEGRATED_CUSTOMER_INDEX_MONTHLY: 名寄せ, 統合顧客, customer consolidation
--   - DEPOSIT_TRANSACTIONS_DAILY: 取引履歴, 預金取引, transaction history
-- 
-- 【カラムのSynonyms】
--   - CUSTOMER_NAME: 顧客名, 氏名, customer name, name
--   - ENTITY_TYPE_CODE: 顧客区分, 個人法人区分, customer type
--   - ANNUAL_INCOME: 年収, 年間収入, annual income
--   - TXN_AMOUNT: 取引金額, 金額, transaction amount, amount
--   - TXN_TYPE: 入出金区分, 入払区分, transaction type
--   - CHANNEL_CODE: チャネル, 取引チャネル, channel
-- 
-- ---------------------------------------------------------

-- =========================================================
-- 03_sv_setup.sql 完了
-- =========================================================
-- 
-- Semantic ViewはGUIで作成してください。
-- 本ファイルの情報を参考に設定を行ってください。
-- 
-- 💡 Tips:
--   - SVの説明（Description）は日本語でOK
--   - テーブル/カラム名は英語版スキーマを使用
--   - Synonymsは日本語・英語両方登録すると便利
-- 
-- 次のステップ:
--   → 04_rag_setup.sql（Cortex Search設定）※将来拡張
--   → 06_agent_design.md（Agent設計書）
-- 
-- =========================================================
