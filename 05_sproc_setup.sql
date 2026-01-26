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
-- Stored Procedure 2: ドキュメントダウンロードURL生成
-- =========================================================
-- 
-- 【用途】
--   Agent経由で「この資料をダウンロードしたい」に対応
--   ステージ内のPDFファイルに対して署名付きダウンロードURLを生成
-- 
-- 【パラメータ】
--   - relative_file_path: ファイル名（例: '預金規定.pdf'）
--   - expiration_mins: URLの有効期限（分）、デフォルト5分
-- 
-- 【使用例】
--   CALL GET_DOCUMENT_DOWNLOAD_URL('預金規定.pdf', 5);
-- 
-- 【対象ファイル】
--   - 預金規定.pdf（普通預金・定期預金の取引規定）
--   - 本人確認マニュアル.pdf（KYC手続きガイド）
--   - 住宅ローン商品説明書.pdf
--   - カードローン商品説明書.pdf
-- 
-- ---------------------------------------------------------

CREATE OR REPLACE PROCEDURE RETAIL_BANKING_DB.AGENT.GET_DOCUMENT_DOWNLOAD_URL(
    relative_file_path STRING, 
    expiration_mins INTEGER DEFAULT 5
)
RETURNS STRING
LANGUAGE SQL
COMMENT = '内部ステージのPDFファイル用に署名付きダウンロードURLを生成'
EXECUTE AS CALLER
AS
$$
DECLARE
    presigned_url STRING;
    sql_stmt STRING;
    expiration_seconds INTEGER;
    stage_name STRING DEFAULT '@RETAIL_BANKING_DB.UNSTRUCTURED_DATA.document_stage';
    file_count INTEGER;
    available_files STRING;
BEGIN
    expiration_seconds := expiration_mins * 60;
    
    -- ステージ内のファイル一覧を取得して、指定ファイルの存在を確認
    EXECUTE IMMEDIATE 'LIST ' || stage_name;
    
    -- 指定されたファイルがステージに存在するか確認（パスの末尾がファイル名と一致するかチェック）
    SELECT COUNT(*)
    INTO :file_count
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "name" LIKE '%' || :relative_file_path
       OR "name" LIKE '%/' || :relative_file_path;
    
    -- ファイルが存在しない場合、利用可能なファイル一覧を返す
    IF (file_count = 0) THEN
        -- ステージ内のファイル一覧を再取得
        EXECUTE IMMEDIATE 'LIST ' || stage_name;
        
        SELECT LISTAGG(SPLIT_PART("name", '/', -1), ', ') WITHIN GROUP (ORDER BY "name")
        INTO :available_files
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE "name" LIKE '%.pdf' OR "name" LIKE '%.PDF';
        
        IF (available_files IS NULL OR available_files = '') THEN
            RETURN 'エラー: ステージにPDFファイルが存在しません。先にPDFファイルをアップロードしてください。\n\nアップロード方法:\n1. Snowsight > Data > Databases > RETAIL_BANKING_DB > UNSTRUCTURED_DATA > Stages > document_stage\n2. 「+ Files」ボタンをクリック\n3. PDFファイルを選択してアップロード';
        ELSE
            RETURN 'エラー: 指定されたファイル「' || relative_file_path || '」がステージに見つかりません。\n\n利用可能なPDFファイル:\n' || available_files || '\n\n正しいファイル名を指定してください。';
        END IF;
    END IF;
    
    -- ファイルが存在する場合、署名付きURLを生成
    sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ''' || relative_file_path || ''', ' || expiration_seconds || ') AS url';
    EXECUTE IMMEDIATE :sql_stmt;

    SELECT "URL"
    INTO :presigned_url
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    RETURN presigned_url;
END;
$$;

-- ---------------------------------------------------------
-- 動作確認: ステージ内ファイル一覧確認
-- ---------------------------------------------------------
-- まずステージにファイルが存在するか確認
LIST @RETAIL_BANKING_DB.UNSTRUCTURED_DATA.document_stage;

-- ---------------------------------------------------------
-- 動作確認: ドキュメントダウンロードURL生成テスト
-- ---------------------------------------------------------
-- 預金規定PDFのダウンロードURL生成（有効期限5分）
-- ※ファイルがステージに存在しない場合は、利用可能なファイル一覧が表示されます
CALL GET_DOCUMENT_DOWNLOAD_URL('預金規定.pdf', 5);



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
--   - GET_DOCUMENT_DOWNLOAD_URL（ダウンロードURL生成プロシージャ）
-- 
-- Agentへのツール登録:
--   1. Snowsight > AI & ML > Snowflake Intelligence
--   2. RETAIL_BANKING_AGENT を編集
--   3. Tools > Add Tool > Stored Procedure
--   4. 上記プロシージャを追加
-- 
-- =========================================================
