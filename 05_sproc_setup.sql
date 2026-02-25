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
-- =========================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE WAREHOUSE RETAIL_BANKING_WH;
USE SCHEMA RETAIL_BANKING_DB.AGENT;

-- =========================================================
-- 事前準備: Email Integration の作成
-- =========================================================
-- メール送信機能を使用するために、通知インテグレーションを作成

CREATE OR REPLACE NOTIFICATION INTEGRATION EMAIL_INTEGRATION
    TYPE = EMAIL
    ENABLED = TRUE;

-- Integration の確認
SHOW NOTIFICATION INTEGRATIONS;
-- DESC NOTIFICATION INTEGRATION EMAIL_CONNECTOR;

-- =========================================================
-- Stored Procedure 1: メール送信
-- =========================================================
-- 
-- 【用途】
--   Agent経由で「この内容を○○にメールで送って」に対応
--   商談サマリーや提案資料の情報を関係者にメール送信
-- 
-- 【パラメータ】
--   - RECIPIENT_EMAIL: 送信先メールアドレス
--   - SUBJECT: メール件名
--   - BODY: メール本文（HTML形式可）
-- 
-- 【使用例】
--   CALL SEND_EMAIL('staff@example.com', '顧客対応サマリー', '<h1>対応概要</h1><p>...</p>');
-- 
-- ---------------------------------------------------------

CREATE OR REPLACE PROCEDURE RETAIL_BANKING_DB.AGENT.SEND_EMAIL(
    "RECIPIENT_EMAIL" VARCHAR, 
    "SUBJECT" VARCHAR, 
    "BODY" VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
COMMENT = 'Agentからメールを送信するためのプロシージャ'
EXECUTE AS OWNER
AS '
def send_email(session, recipient_email, subject, body):
    try:
        # Escape single quotes in the body and subject
        escaped_body = body.replace("''", "''''")
        escaped_subject = subject.replace("''", "''''")
        
        # Execute the system procedure call
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                ''EMAIL_INTEGRATION'',
                ''{recipient_email}'',
                ''{escaped_subject}'',
                ''{escaped_body}'',
                ''text/html''
            )
        """).collect()
        
        return "メールを送信しました: " + recipient_email
    except Exception as e:
        return f"メール送信エラー: {str(e)}"
';

-- ---------------------------------------------------------
-- 動作確認: メール送信テスト
-- ---------------------------------------------------------
-- Step 1: 現在のユーザーのメールアドレスを変数に格納
SET my_email = (
    SELECT EMAIL 
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
    WHERE NAME = CURRENT_USER()
);

-- Step 2: 変数を使ってメール送信
CALL SEND_EMAIL(
    $my_email,
    'Snowflake Intelligence テストメール',
    '<h1>テストメール</h1><p>このメールはCortex Agentのテストです。</p><p>正常に受信できていれば、メール送信機能は正しく動作しています。</p>'
);


-- =========================================================
-- Sproc一覧取得
-- =========================================================
-- Stored Procedure の確認
SHOW PROCEDURES IN SCHEMA RETAIL_BANKING_DB.AGENT;

-- ---------------------------------------------------------

-- =========================================================
-- セットアップ完了
-- =========================================================
-- 
-- 作成されたオブジェクト:
-- 
-- [RETAIL_BANKING_DB.AGENT]
--   - SEND_EMAIL（メール送信プロシージャ）
-- 
-- Agentへのツール登録:
--   1. Snowsight > AI & ML > Snowflake Intelligence
--   2. RETAIL_BANKING_AGENT を編集
--   3. Tools > Add Tool > Stored Procedure
--   4. 上記プロシージャを追加
-- 
-- =========================================================
