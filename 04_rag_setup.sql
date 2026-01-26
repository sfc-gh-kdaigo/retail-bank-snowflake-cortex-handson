-- =========================================================
-- リテールバンキング向け Snowflake Intelligence ハンズオン
-- 〜顧客・預金取引分析シナリオ〜
-- 
-- 04_rag_setup.sql - Cortex Search設定（RAG用）
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql          ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← Cortex AI Functions デモ
--    3. 03_sv_setup.sql          ← Semantic View設定
--    4. 04_rag_setup.sql         ← 本ファイル（Cortex Search設定）
--    5. 05_sproc_setup.sql       ← Stored Procedure
--    6. 06_agent_design.md       ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--    （スキーマ、ステージは01_db_setup.sqlで作成済み）
--
-- =========================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE WAREHOUSE RETAIL_BANKING_WH;
USE SCHEMA RETAIL_BANKING_DB.UNSTRUCTURED_DATA;


-- =========================================================
-- PDFファイルの準備
-- =========================================================

-- ---------------------------------------------------------
-- Step 1: PDFファイルのアップロード
-- ---------------------------------------------------------
-- 【事前準備】Snowsight または SnowSQL で以下を実行してPDFをアップロード
-- 
-- ■ Snowsightの場合:
--   1. Data > Databases > RETAIL_BANKING_DB > UNSTRUCTURED_DATA > Stages
--   2. document_stage ステージを選択
--   3. 「+ Files」ボタンをクリック
--   4. resources/sample_docs/ フォルダ内の以下PDFファイルをアップロード:
--      - 預金規定.pdf
--      - 本人確認マニュアル.pdf
--      - 住宅ローン商品説明書.pdf
--      - カードローン商品説明書.pdf
-- 
-- ■ SnowSQLの場合:
--   PUT file:///path/to/預金規定.pdf @document_stage;
--   PUT file:///path/to/本人確認マニュアル.pdf @document_stage;
--   PUT file:///path/to/住宅ローン商品説明書.pdf @document_stage;
--   PUT file:///path/to/カードローン商品説明書.pdf @document_stage;
-- 
-- ※ PDFファイルは resources/generate_sample_pdfs.py を実行して生成できます
-- ---------------------------------------------------------

-- ステージ内のファイル確認
LIST @document_stage;


-- =========================================================
-- PDFパースとチャンク化
-- =========================================================

-- ---------------------------------------------------------
-- Step 2: AI_PARSE_DOCUMENTでPDFからテキスト抽出
-- ---------------------------------------------------------
-- AI_PARSE_DOCUMENTを使用してPDFの全文テキストを抽出
-- 
-- 【モードの選択】
--   - OCR: 高速なテキスト抽出（本ハンズオンで使用）
--   - LAYOUT: テーブル・見出し等の構造を保持（処理時間が長い）
-- 
-- ※ LAYOUTモードを使用する場合は 'OCR' → 'LAYOUT' に変更

CREATE OR REPLACE TABLE PARSED_DOCUMENTS_RAW AS
SELECT 
    relative_path AS FILE_NAME,
    file_url AS FILE_URL,
    AI_PARSE_DOCUMENT(
        TO_FILE('@RETAIL_BANKING_DB.UNSTRUCTURED_DATA.document_stage', relative_path),
        {'mode': 'OCR', 'page_split': true}
    ) AS PARSED_CONTENT
FROM DIRECTORY(@RETAIL_BANKING_DB.UNSTRUCTURED_DATA.document_stage)
WHERE relative_path LIKE '%.pdf';

-- パース結果の確認
SELECT FILE_NAME, FILE_URL, PARSED_CONTENT FROM PARSED_DOCUMENTS_RAW;

-- ---------------------------------------------------------
-- Step 3: テキストのチャンク化（Cortex Search用）
-- ---------------------------------------------------------
-- SPLIT_TEXT_RECURSIVE_CHARACTERでチャンク分割
-- chunk_size: 512文字、overlap: 128文字

CREATE OR REPLACE TABLE DOCUMENT_CHUNKS AS
SELECT 
    FILE_NAME,
    FILE_URL,
    f.index AS PAGE_NUMBER,
    ROW_NUMBER() OVER (ORDER BY FILE_NAME, f.index, c.index) AS CHUNK_ID,
    c.value::TEXT AS CHUNK_TEXT
FROM PARSED_DOCUMENTS_RAW r,
    LATERAL FLATTEN(INPUT => r.PARSED_CONTENT:pages) f,
    LATERAL FLATTEN(INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
        f.value:content::TEXT,
        'markdown',
        512,
        128
    )) c;

-- チャンク化結果の確認
SELECT * FROM DOCUMENT_CHUNKS LIMIT 20;


-- =========================================================
-- Cortex Search Serviceの作成
-- =========================================================

-- ---------------------------------------------------------
-- Step 4: 内部規定・マニュアル用Cortex Search Service
-- ---------------------------------------------------------
-- 預金規定、本人確認マニュアル、商品説明書などのPDFドキュメントを
-- セマンティック検索可能にする

CREATE OR REPLACE CORTEX SEARCH SERVICE INTERNAL_DOCS_SEARCH
  ON CHUNK_TEXT
  ATTRIBUTES FILE_NAME, FILE_URL, PAGE_NUMBER
  WAREHOUSE = RETAIL_BANKING_WH
  TARGET_LAG = '1 day'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
    SELECT 
      CHUNK_ID,
      FILE_NAME,
      FILE_URL,
      PAGE_NUMBER,
      CHUNK_TEXT
    FROM DOCUMENT_CHUNKS
);


-- =========================================================
-- 動作確認
-- =========================================================

-- ---------------------------------------------------------
-- Step 5: Cortex Search動作確認
-- ---------------------------------------------------------
-- 
-- Snowsight の Playground で検索テストを行ってみましょう
-- 
-- 手順:
--   1. Snowsight > AI & ML > Search を開く
--   2. 作成した検索サービスを選択（INTERNAL_DOCS_SEARCH）
--   3. 「Playground」タブをクリック
--   4. 検索クエリを入力してテスト
-- 
-- サンプル質問（Playgroundで試してみてください）:
--   - 「定期預金の中途解約について教えてください」
--   - 「本人確認に必要な書類は何ですか？」
--   - 「住宅ローンの金利タイプの違いを教えてください」
--   - 「カードローンの返済方法を教えてください」
--   - 「法人の実質的支配者とは何ですか？」
--
-- ---------------------------------------------------------


-- =========================================================
-- 04_rag_setup.sql 完了
-- =========================================================
-- 
-- 作成されたオブジェクト:
-- 
-- [RETAIL_BANKING_DB.UNSTRUCTURED_DATA]
--   - PARSED_DOCUMENTS_RAW - AI_PARSE_DOCUMENTによるPDFパース結果
--   - DOCUMENT_CHUNKS - チャンク化されたドキュメント
--   - INTERNAL_DOCS_SEARCH（Cortex Search Service）- 内部規定・マニュアル検索
-- 
-- PDFファイル（要アップロード）:
--   - 預金規定.pdf
--   - 本人確認マニュアル.pdf
--   - 住宅ローン商品説明書.pdf
--   - カードローン商品説明書.pdf
-- 
-- 次のステップ:
--   → 05_sproc_setup.sql（Stored Procedure）
--   → 06_agent_design.md を参考にAgentを作成
-- 
-- =========================================================
