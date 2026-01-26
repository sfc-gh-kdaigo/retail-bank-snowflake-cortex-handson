-- =========================================================
-- リテールバンキング向け Snowflake Intelligence ハンズオン
-- 〜顧客・預金取引分析シナリオ〜
-- 
-- 05_sproc_setup.sql - Stored Procedure（カスタムツール）※将来拡張
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql          ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← Cortex AI Functions デモ
--    3. 03_sv_setup.sql          ← Semantic View設定
--    4. 04_rag_setup.sql         ← Cortex Search設定
--    5. 05_sproc_setup.sql       ← 本ファイル（Stored Procedure）
--    6. 06_agent_design.md       ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- ⚠️ 本ファイルは将来拡張用のテンプレートです
--
-- =========================================================

USE DATABASE RETAIL_BANKING_DB;
USE WAREHOUSE RETAIL_BANKING_WH;
USE SCHEMA RETAIL_BANKING_DB.AGENT;

-- =========================================================
-- 将来拡張: Stored Procedure（カスタムツール）
-- =========================================================

-- ---------------------------------------------------------
-- SEND_EMAIL: メール送信
-- ---------------------------------------------------------
-- Agent経由で分析結果をメール送信する際に使用

/*
CREATE OR REPLACE PROCEDURE SEND_EMAIL(
    RECIPIENT_EMAIL VARCHAR,
    SUBJECT VARCHAR,
    BODY VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- メール送信ロジック
    -- ※ 実際の実装では、Snowflake Notificationや外部サービス連携が必要
    
    -- サンプル実装（ログ出力のみ）
    RETURN 'メールを送信しました: ' || RECIPIENT_EMAIL;
END;
$$;
*/

-- ---------------------------------------------------------
-- GET_CUSTOMER_SUMMARY: 顧客サマリー取得
-- ---------------------------------------------------------
-- 指定した顧客の取引サマリーを取得

/*
CREATE OR REPLACE PROCEDURE GET_CUSTOMER_SUMMARY(
    P_CUSTOMER_ID NUMBER
)
RETURNS TABLE (
    CUSTOMER_NAME VARCHAR,
    CUSTOMER_TYPE VARCHAR,
    TOTAL_DEPOSITS NUMBER,
    TOTAL_WITHDRAWALS NUMBER,
    NET_FLOW NUMBER,
    TRANSACTION_COUNT NUMBER
)
LANGUAGE SQL
AS
$$
BEGIN
    RETURN TABLE(
        SELECT 
            c."漢字氏名１" AS CUSTOMER_NAME,
            CASE WHEN c."人格コード" = 1 THEN '個人' 
                 WHEN c."人格コード" = 2 THEN '法人' 
                 ELSE '個人事業主' END AS CUSTOMER_TYPE,
            SUM(CASE WHEN t."入払区分" = 1 THEN t."取引金額" ELSE 0 END) AS TOTAL_DEPOSITS,
            SUM(CASE WHEN t."入払区分" = 2 THEN t."取引金額" ELSE 0 END) AS TOTAL_WITHDRAWALS,
            SUM(CASE WHEN t."入払区分" = 1 THEN t."取引金額" ELSE -t."取引金額" END) AS NET_FLOW,
            COUNT(*) AS TRANSACTION_COUNT
        FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."顧客基本属性情報＿月次" c
        LEFT JOIN RETAIL_BANKING_DB.RETAIL_BANKING_JP."流動性預金取引データ＿日次" t
            ON c."顧客番号" = t."顧客番号"
            AND t."取消取引表示" = 0
        WHERE c."顧客番号" = P_CUSTOMER_ID
        GROUP BY c."漢字氏名１", c."人格コード"
    );
END;
$$;
*/

-- ---------------------------------------------------------
-- GENERATE_MONTHLY_REPORT: 月次レポート生成
-- ---------------------------------------------------------
-- 指定月の取引レポートを生成

/*
CREATE OR REPLACE PROCEDURE GENERATE_MONTHLY_REPORT(
    P_YEAR NUMBER,
    P_MONTH NUMBER
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_total_customers NUMBER;
    v_new_customers NUMBER;
    v_total_transactions NUMBER;
    v_net_inflow NUMBER;
    v_report VARCHAR;
BEGIN
    -- 総顧客数
    SELECT COUNT(*) INTO v_total_customers
    FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."顧客基本属性情報＿月次"
    WHERE "元帳状態表示" = 0;
    
    -- 新規顧客数（当月開設）
    SELECT COUNT(*) INTO v_new_customers
    FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."顧客基本属性情報＿月次"
    WHERE FLOOR("取引開始日" / 100) = P_YEAR * 100 + P_MONTH;
    
    -- 取引件数
    SELECT COUNT(*) INTO v_total_transactions
    FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."流動性預金取引データ＿日次"
    WHERE "取消取引表示" = 0;
    
    -- 純資金流入額
    SELECT 
        SUM(CASE WHEN "入払区分" = 1 THEN "取引金額" ELSE 0 END) -
        SUM(CASE WHEN "入払区分" = 2 THEN "取引金額" ELSE 0 END)
    INTO v_net_inflow
    FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."流動性預金取引データ＿日次"
    WHERE "取消取引表示" = 0;
    
    v_report := '【月次レポート ' || P_YEAR || '年' || P_MONTH || '月】\n' ||
                '総顧客数: ' || v_total_customers || '名\n' ||
                '新規顧客数: ' || v_new_customers || '名\n' ||
                '総取引件数: ' || v_total_transactions || '件\n' ||
                '純資金流入額: ' || v_net_inflow || '円';
    
    RETURN v_report;
END;
$$;
*/


-- =========================================================
-- 05_sproc_setup.sql 完了
-- =========================================================
-- 
-- 本ファイルは将来拡張用のテンプレートです。
-- 実装する際は、コメントアウトを解除して使用してください。
-- 
-- 次のステップ:
--   → 06_agent_design.md（Agent設計書）
-- 
-- =========================================================
