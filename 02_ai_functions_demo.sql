-- =========================================================
-- リテールバンキング向け Snowflake Intelligence ハンズオン
-- 〜顧客・預金取引分析シナリオ〜
-- 
-- 02_ai_functions_demo.sql - Cortex AI Functions デモ
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql          ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← 本ファイル（Cortex AI Functions デモ）
--    3. 03_sv_setup.sql          ← Semantic View設定
--    4. 04_rag_setup.sql         ← Cortex Search設定（将来拡張）
--    5. 05_sproc_setup.sql       ← Stored Procedure（将来拡張）
--    6. 06_agent_design.md       ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- =========================================================

USE DATABASE RETAIL_BANKING_DB;
USE WAREHOUSE RETAIL_BANKING_WH;
USE SCHEMA RETAIL_BANKING_JP;

-- =========================================================
-- Cortex AI Functions デモ
-- =========================================================
-- 
-- Snowflake Cortex AI Functionsは、LLMの力をSQLから直接利用できる機能です。
-- 以下の3つの主要な関数をデモします：
-- 
--   1. AI_CLASSIFY: テキストを指定されたカテゴリに分類
--   2. AI_FILTER: 条件に一致する行をフィルタリング
--   3. AI_COMPLETE: テキストを生成・要約
-- 
-- =========================================================

-- ---------------------------------------------------------
-- AI_CLASSIFY: 顧客名から個人/法人を判定
-- ---------------------------------------------------------
-- 顧客名に「株式会社」「有限会社」等が含まれるかをAIが判定
--
-- ※AI_CLASSIFYは英語テキストに最適化されており、
--   日本語ラベルでは分類精度が不安定になる場合があります

-- Step 1: 日本語ラベルで分類（出力が不安定な例）
SELECT 
    "漢字氏名１" AS "顧客名",
    AI_CLASSIFY(
        "漢字氏名１",
        ['個人', '法人', 'フリーランス']
    ):labels[0]::VARCHAR AS "AI判定_日本語ラベル"
FROM "顧客基本属性情報＿月次"
WHERE "元帳状態表示" = 0;

-- Step 2: task_description + 英語ラベルで分類（安定した出力）
SELECT 
    "漢字氏名１" AS "顧客名",
    CASE AI_CLASSIFY(
        "漢字氏名１",
        ['individual', 'corporation', 'freelancer'],
        {'task_description': 'Classify Japanese customer names. 株式会社/有限会社/合同会社 = corporation, 個人事業主 in name = freelancer, personal names = individual'}
    ):labels[0]::VARCHAR
        WHEN 'individual' THEN '個人'
        WHEN 'corporation' THEN '法人'
        WHEN 'freelancer' THEN 'フリーランス'
    END AS "AI判定"
FROM "顧客基本属性情報＿月次"
WHERE "元帳状態表示" = 0;


-- ---------------------------------------------------------
-- AI_FILTER: 生活費関連の取引を抽出
-- ---------------------------------------------------------
-- 取引摘要から「生活費（公共料金・保険など）」に該当する取引を抽出
--
-- ※カタカナの摘要をそのまま渡すと判定精度が不安定になる場合があります
--   TRANSLATEで英語に変換してから判定すると精度が向上します

-- Step 1: カナ摘要をそのままAI_FILTERに渡す（結果が不安定な例）
SELECT 
    "カナ摘要",
    "取引金額",
    CASE WHEN "入払区分" = 1 THEN '入金' ELSE '出金' END AS "入出金区分"
FROM "流動性預金取引データ＿日次"
WHERE "取消取引表示" = 0
  AND AI_FILTER(
      PROMPT('Is "{0}" a living expense like utility bills or insurance?', "カナ摘要")
  );

-- Step 2: TRANSLATEで英語に変換してからAI_FILTERに渡してみる（こちらも不安定）
SELECT 
    "カナ摘要",
    SNOWFLAKE.CORTEX.TRANSLATE("カナ摘要", 'ja', 'en') AS "英語訳",
    "取引金額",
    CASE WHEN "入払区分" = 1 THEN '入金' ELSE '出金' END AS "入出金区分"
FROM "流動性預金取引データ＿日次"
WHERE "取消取引表示" = 0
  AND AI_FILTER(
      PROMPT('Is "{0}" a living expense like utility bills or insurance?',
             SNOWFLAKE.CORTEX.TRANSLATE("カナ摘要", 'ja', 'en'))
  );

-- ---------------------------------------------------------
-- AI_COMPLETE: テキスト生成・分類
-- ---------------------------------------------------------
-- AI_COMPLETEは日本語にも強く、様々な用途に使えます
--
-- Step 1: シンプルなテキスト生成
-- Step 2: カテゴリ分類
-- Step 3: 構造化出力（複数カラムを一度に生成）

-- Step 1: シンプルなテキスト生成
SELECT 
    "カナ摘要",
    "取引金額",
    AI_COMPLETE(
        'claude-3-5-sonnet',
        '「' || "カナ摘要" || '」という銀行取引を10文字以内で説明してください'
    ) AS "AI説明"
FROM "流動性預金取引データ＿日次"
WHERE "カナ摘要" IS NOT NULL AND "取消取引表示" = 0
LIMIT 10;

-- Step 2: カテゴリ分類
SELECT 
    "カナ摘要",
    "取引金額",
    AI_COMPLETE(
        'claude-3-5-sonnet',
        CONCAT(
            '「', "カナ摘要", '」を次のカテゴリから1つ選んでください: ',
            '給与収入, 現金引出, 公共料金, 振込, 売上, カード決済, その他。',
            '回答はカテゴリ名のみ。'
        )
    ) AS "分類"
FROM "流動性預金取引データ＿日次"
WHERE "カナ摘要" IS NOT NULL AND "取消取引表示" = 0
LIMIT 10;

-- Step 3: 構造化出力（response_formatでJSON形式の出力を指定）
SELECT 
    "カナ摘要",
    "取引金額",
    result:"category"::VARCHAR AS "カテゴリ",
    result:"description"::VARCHAR AS "説明"
FROM (
    SELECT 
        "カナ摘要",
        "取引金額",
        AI_COMPLETE(
            'claude-3-5-sonnet',
            '「' || "カナ摘要" || '」という銀行取引を分類し、説明してください',
            {},
            {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'category': {'type': 'string', 'description': '給与収入/現金引出/公共料金/振込/売上/カード決済/その他 のいずれか'},
                        'description': {'type': 'string', 'description': '10文字以内の説明'}
                    }
                }
            }
        ) AS result
    FROM "流動性預金取引データ＿日次"
    WHERE "カナ摘要" IS NOT NULL AND "取消取引表示" = 0
    LIMIT 10
);


-- =========================================================
-- 02_ai_functions_demo.sql 完了
-- =========================================================
-- 
-- 実行した機能:
--   - AI_CLASSIFY: 顧客名から個人/法人を判定
--   - AI_FILTER: 法人顧客の抽出
--   - AI_COMPLETE: 顧客サマリー生成、取引摘要の分類
-- 
-- 次のステップ:
--   → 03_sv_setup.sql（Semantic View設定）
-- 
-- =========================================================
