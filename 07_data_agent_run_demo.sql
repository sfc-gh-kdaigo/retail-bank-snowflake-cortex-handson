-- =========================================================
-- リテールバンキング向け Snowflake Intelligence ハンズオン
-- 〜顧客・預金取引分析シナリオ〜
-- 
-- 07_data_agent_run_demo.sql - DATA_AGENT_RUN によるSQL内Agent実行
-- =========================================================
-- 作成日: 2026/02
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql          ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← Cortex AI Functions デモ
--    3. 03_sv_setup.sql          ← Semantic View設定
--    4. 04_rag_setup.sql         ← Cortex Search設定
--    5. 05_sproc_setup.sql       ← Stored Procedure（カスタムツール）
--    6. 06_agent_design.md       ← Agent設計書
--    7. 07_data_agent_run_demo.sql ← 本ファイル（DATA_AGENT_RUN デモ）
--
-- ⚠️ 前提条件:
--    - 01_db_setup.sql 〜 05_sproc_setup.sql を実行済みであること
--    - 06_agent_design.md に基づき RETAIL_BANKING_AGENT を作成済みであること
--    - エージェントに Cortex Analyst / Cortex Search ツールが登録済みであること
--
-- 💡 DATA_AGENT_RUN とは:
--    SNOWFLAKE.CORTEX.DATA_AGENT_RUN は、Cortex Agent を SQL から直接実行し、
--    結果を JSON で返す関数です。REST API のラッパーとして機能し、
--    SQL ワークフロー（Task, Stream, Dynamic Table 等）への組み込みが可能です。
--
--    公式ドキュメント:
--    https://docs.snowflake.com/en/sql-reference/functions/data_agent_run-snowflake-cortex
--
-- =========================================================


USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE WAREHOUSE RETAIL_BANKING_WH;
USE SCHEMA RETAIL_BANKING_DB.AGENT;


-- =========================================================
-- シナリオ1: DATA_AGENT_RUN の基本実行
-- =========================================================
-- 
-- 【概要】
--   RETAIL_BANKING_AGENT を SQL から直接呼び出し、
--   自然言語の質問に対するエージェントの応答を取得する基本パターン
-- 
-- 【ポイント】
--   - 戻り値は JSON 文字列のため TRY_PARSE_JSON で VARIANT に変換
--   - stream フィールドは無視され、常に非ストリーミング応答が返る
--   - thread_id / parent_message_id で会話の文脈を管理可能
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 1-1: 基本的な構造化データへの質問（Cortex Analyst 経由）
-- ---------------------------------------------------------
-- 顧客数や取引金額など、Semantic View を通じて回答可能な質問

SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
        $${
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "今月の総顧客数と新規顧客数を教えてください"
                        }
                    ]
                }
            ],
            "stream": false
        }$$
    )
) AS agent_response;

-- ---------------------------------------------------------
-- Step 1-2: 非構造化データへの質問（Cortex Search 経由）
-- ---------------------------------------------------------
-- 内部規定やマニュアルのPDFを検索して回答

SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
        $${
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "住宅ローンの金利タイプの違いを教えてください"
                        }
                    ]
                }
            ],
            "stream": false
        }$$
    )
) AS agent_response;

-- ---------------------------------------------------------
-- Step 1-3: 構造化 + 非構造化の複合質問
-- ---------------------------------------------------------
-- エージェントが Cortex Analyst と Cortex Search の両方を使い分けて回答

SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
        $${
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "年収1000万円以上の顧客一覧と、住宅ローンの商品概要を教えてください"
                        }
                    ]
                }
            ],
            "stream": false
        }$$
    )
) AS agent_response;


-- =========================================================
-- シナリオ2: レスポンス JSON の解析パターン
-- =========================================================
-- 
-- 【概要】
--   DATA_AGENT_RUN の戻り値（JSON）から必要な情報を抽出する
--   実用的なクエリパターン集
-- 
-- 【レスポンス構造】
--   {
--     "role": "assistant",
--     "content": [
--       { "type": "thinking", "thinking": { "text": "..." } },
--       { "type": "tool_use", "tool_use": { "name": "...", ... } },
--       { "type": "text", "text": "回答テキスト" }
--     ],
--     "metadata": { "run_id": "..." }
--   }
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 2-1: 回答テキストのみを抽出
-- ---------------------------------------------------------
-- content 配列から type='text' の要素を取得

WITH agent_result AS (
    SELECT TRY_PARSE_JSON(
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
            'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
            $${
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": "支店101の顧客数を教えてください"
                            }
                        ]
                    }
                ],
                "stream": false
            }$$
        )
    ) AS resp
)
SELECT
    resp:role::STRING AS role,
    resp:metadata:run_id::STRING AS run_id,
    c.value:text::STRING AS answer_text
FROM agent_result,
     LATERAL FLATTEN(input => resp:content) c
WHERE c.value:type::STRING = 'text';

-- ---------------------------------------------------------
-- Step 2-2: 使用されたツール情報の抽出
-- ---------------------------------------------------------
-- エージェントがどのツール（Analyst / Search）を使ったかを確認

WITH agent_result AS (
    SELECT TRY_PARSE_JSON(
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
            'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
            $${
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": "法人顧客の取引金額上位5社を教えてください"
                            }
                        ]
                    }
                ],
                "stream": false
            }$$
        )
    ) AS resp
)
SELECT
    c.value:type::STRING AS content_type,
    c.value:tool_use:name::STRING AS tool_name,
    c.value:tool_use:type::STRING AS tool_type,
    c.value:text::STRING AS text_content,
    c.value:thinking:text::STRING AS thinking_content
FROM agent_result,
     LATERAL FLATTEN(input => resp:content) c;


-- =========================================================
-- シナリオ3: 支店別顧客サマリーの生成
-- =========================================================
-- 
-- 【概要】
--   特定の支店に対してエージェントを実行し、
--   支店別の顧客サマリーレポートを取得する
-- 
-- 【金融ユースケース】
--   - 経営層向けの支店別パフォーマンスレポート生成
--   - 営業会議用の支店KPIサマリー
-- 
-- 【ポイント】
--   DATA_AGENT_RUN の第2引数（request_body）は $$...$$ リテラルで
--   渡す必要があります。動的に構築する場合は EXECUTE IMMEDIATE が
--   必要になりますが、エスケープ処理が複雑になるため、
--   ここではデモの安定性を優先して固定質問パターンで示します。
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 3-1: サマリー格納テーブルの作成
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS (
    report_id NUMBER AUTOINCREMENT,
    branch_code NUMBER(4,0) COMMENT '支店番号',
    report_date DATE COMMENT 'レポート生成日',
    agent_response VARIANT COMMENT 'エージェントの応答（JSON全体）',
    answer_text VARCHAR COMMENT '回答テキスト（抽出済み）',
    run_id VARCHAR COMMENT 'エージェント実行ID（監査用）',
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'レコード作成日時',
    CONSTRAINT pk_branch_summary PRIMARY KEY (report_id)
) COMMENT = '支店別顧客サマリーレポート（DATA_AGENT_RUN による生成）';

-- ---------------------------------------------------------
-- Step 3-2: 支店101の顧客サマリーを取得
-- ---------------------------------------------------------

SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
        $${
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "支店101の顧客数、当月の入出金合計、主要顧客の取引傾向を要約してください"
                        }
                    ]
                }
            ],
            "stream": false
        }$$
    )
) AS agent_response;

-- ---------------------------------------------------------
-- Step 3-3: 結果をテーブルに格納（INSERT ... SELECT パターン）
-- ---------------------------------------------------------
-- 上記の結果を確認した上で、テーブルへの蓄積パターンを示す

INSERT INTO RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS
    (branch_code, report_date, agent_response, answer_text, run_id)
WITH agent_result AS (
    SELECT TRY_PARSE_JSON(
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
            'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
            $${
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": "支店102の顧客数、当月の入出金合計、主要顧客の取引傾向を要約してください"
                            }
                        ]
                    }
                ],
                "stream": false
            }$$
        )
    ) AS resp
)
SELECT
    102,
    CURRENT_DATE(),
    resp,
    (SELECT LISTAGG(c.value:text::STRING, '\n') WITHIN GROUP (ORDER BY c.index)
     FROM LATERAL FLATTEN(input => resp:content) c
     WHERE c.value:type::STRING = 'text'),
    resp:metadata:run_id::STRING
FROM agent_result;

-- ---------------------------------------------------------
-- Step 3-4: 格納されたレポートの確認
-- ---------------------------------------------------------

SELECT
    branch_code,
    report_date,
    answer_text,
    run_id,
    created_at
FROM RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS
ORDER BY branch_code;

-- ---------------------------------------------------------
-- Step 3-5: Task による定期実行（応用例）
-- ---------------------------------------------------------
-- 上記のようなレポート生成を Task で定期スケジュール実行することで、
-- 日次・週次の自動レポート生成が可能になる。
-- 
-- 【コストに関する注意】
--   - Task が実行されるたびにウェアハウスのコンピュートが発生
--   - AUTO_SUSPEND を適切に設定し、不要なコストを抑制すること
--   - 本番運用時は SCHEDULE の間隔とウェアハウスサイズを慎重に検討

-- 日次レポート格納テーブル
CREATE TABLE IF NOT EXISTS RETAIL_BANKING_DB.AGENT.DAILY_SUMMARY_REPORTS (
    report_id NUMBER AUTOINCREMENT,
    report_date DATE COMMENT 'レポート対象日',
    report_type VARCHAR COMMENT 'レポート種別（DAILY_TXN_SUMMARY 等）',
    agent_response VARIANT COMMENT 'エージェント応答（JSON全体）',
    summary_text VARCHAR COMMENT 'サマリーテキスト',
    run_id VARCHAR COMMENT 'エージェント実行ID',
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT '生成日時',
    CONSTRAINT pk_daily_summary PRIMARY KEY (report_id)
) COMMENT = '日次サマリーレポート（Task による自動生成）';

-- 日次サマリー生成用ストアドプロシージャ
CREATE OR REPLACE PROCEDURE RETAIL_BANKING_DB.AGENT.GENERATE_DAILY_SUMMARY()
RETURNS STRING
LANGUAGE SQL
AS
BEGIN
    INSERT INTO RETAIL_BANKING_DB.AGENT.DAILY_SUMMARY_REPORTS
        (report_date, report_type, agent_response, summary_text, run_id)
    WITH agent_result AS (
        SELECT TRY_PARSE_JSON(
            SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
                '{"messages":[{"role":"user","content":[{"type":"text","text":"昨日の取引サマリーを作成してください。以下の項目を含めてください: 1. 総取引件数と総取引金額、2. 入金・出金の内訳、3. チャネル別（窓口/ATM/オンライン）の取引件数、4. 高額取引（30万円以上）の一覧、5. 特記事項やリスク所見"}]}],"stream":false}'
            )
        ) AS resp
    )
    SELECT
        DATEADD(DAY, -1, CURRENT_DATE()),
        'DAILY_TXN_SUMMARY',
        resp,
        (SELECT LISTAGG(c.value:text::STRING, '\n') WITHIN GROUP (ORDER BY c.index)
         FROM LATERAL FLATTEN(input => resp:content) c
         WHERE c.value:type::STRING = 'text'),
        resp:metadata:run_id::STRING
    FROM agent_result;

    RETURN '日次レポート生成完了';
END;

-- Task の作成（毎朝9時に前日分のサマリーを生成）
CREATE OR REPLACE TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK
    WAREHOUSE = RETAIL_BANKING_WH
    SCHEDULE = 'USING CRON 0 9 * * * Asia/Tokyo'
    COMMENT = '日次取引サマリーレポート自動生成タスク'
AS
    CALL RETAIL_BANKING_DB.AGENT.GENERATE_DAILY_SUMMARY();

-- Task の状態確認
SHOW TASKS IN SCHEMA RETAIL_BANKING_DB.AGENT;

-- Task の有効化（本番運用開始時にコメント解除）
-- ⚠️ RESUME するとスケジュール通りに自動実行が開始されます
-- ALTER TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK RESUME;

-- Task の手動テスト実行
-- EXECUTE TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK;

-- Task の停止（不要になった場合）
-- ALTER TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK SUSPEND;


-- =========================================================
-- クリーンアップ（デモ終了後）
-- =========================================================
-- 
-- 不要になったオブジェクトを削除する場合は以下を実行
-- 
-- ---------------------------------------------------------

-- Task の停止・削除
-- ALTER TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK SUSPEND;
-- DROP TASK IF EXISTS RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK;

-- ストアドプロシージャの削除
-- DROP PROCEDURE IF EXISTS RETAIL_BANKING_DB.AGENT.GENERATE_DAILY_SUMMARY();

-- テーブルの削除
-- DROP TABLE IF EXISTS RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS;
-- DROP TABLE IF EXISTS RETAIL_BANKING_DB.AGENT.DAILY_SUMMARY_REPORTS;


-- =========================================================
-- セットアップ完了
-- =========================================================
-- 
-- 作成されたオブジェクト:
-- 
-- [RETAIL_BANKING_DB.AGENT]
--   テーブル:
--   - BRANCH_SUMMARY_REPORTS（支店別サマリーレポート）
--   - DAILY_SUMMARY_REPORTS（日次サマリーレポート）
--
--   ストアドプロシージャ:
--   - GENERATE_DAILY_SUMMARY（日次サマリー生成、Task から呼び出し）
--
--   タスク:
--   - DAILY_TXN_SUMMARY_TASK（日次レポート自動生成、初期状態: SUSPENDED）
-- 
-- デモシナリオ:
--   1. DATA_AGENT_RUN の基本実行
--   2. レスポンス JSON の解析パターン
--   3. 支店別顧客サマリーの生成 + Task による定期実行
-- 
-- ⚠️ 注意:
--   - DATA_AGENT_RUN は非ストリーミングのため、リアルタイム対話UIには
--     REST API（/api/v2/cortex/agent:run）の直接呼び出しを推奨
--   - Task の RESUME 前にコスト影響を確認すること
-- 
-- =========================================================
