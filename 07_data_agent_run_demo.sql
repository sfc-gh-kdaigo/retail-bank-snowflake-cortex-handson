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
-- シナリオ3: バッチ処理 — 支店別顧客サマリーの自動生成
-- =========================================================
-- 
-- 【概要】
--   各支店に対してエージェントを一括実行し、
--   支店別の顧客サマリーレポートをテーブルに蓄積する
-- 
-- 【金融ユースケース】
--   - 経営層向けの支店別パフォーマンスレポート自動生成
--   - 週次・月次の定例報告資料の下書き作成
--   - 営業会議用の支店KPIサマリー
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 3-1: サマリー格納テーブルの作成
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS (
    report_id NUMBER AUTOINCREMENT,
    branch_code NUMBER(4,0) COMMENT '支店番号',
    report_date DATE COMMENT 'レポート生成日',
    question VARCHAR COMMENT 'エージェントへの質問内容',
    agent_response VARIANT COMMENT 'エージェントの応答（JSON全体）',
    answer_text VARCHAR COMMENT '回答テキスト（抽出済み）',
    run_id VARCHAR COMMENT 'エージェント実行ID（監査用）',
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'レコード作成日時',
    CONSTRAINT pk_branch_summary PRIMARY KEY (report_id)
) COMMENT = '支店別顧客サマリーレポート（DATA_AGENT_RUN によるバッチ生成）';

-- ---------------------------------------------------------
-- Step 3-2: 支店マスタを使ったバッチ実行
-- ---------------------------------------------------------
-- 支店101〜105に対してエージェントを実行し、結果をテーブルに格納
--
-- ※ DATA_AGENT_RUN の第2引数（request_body）は定数リテラルである必要があるため、
--   CONCAT で動的に構築すると SQL compilation error になる。
--   Snowflake Scripting で行ごとにループし、EXECUTE IMMEDIATE で
--   ペイロードをリテラルとして埋め込むことで回避する。

DECLARE
    v_bc STRING;
    v_question STRING;
    v_payload STRING;
    v_agent_sql STRING;
    c1 CURSOR FOR SELECT branch_code FROM (VALUES (101), (102), (103), (104), (105)) AS t(branch_code);
BEGIN
    FOR rec IN c1 DO
        v_bc := rec.branch_code::STRING;
        v_question := '支店' || :v_bc || 'の顧客数、当月の入出金合計、主要顧客の取引傾向を要約してください';
        v_payload := '{"messages":[{"role":"user","content":[{"type":"text","text":"' || :v_question || '"}]}],"stream":false}';

        -- DATA_AGENT_RUN をリテラル引数で実行し、結果を一時テーブルに格納
        v_agent_sql := 'CREATE OR REPLACE TEMPORARY TABLE _tmp_agent_resp AS ' ||
            'SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(' ||
            '''RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT'',' ||
            '''' || :v_payload || '''' ||
            ')) AS resp';
        EXECUTE IMMEDIATE :v_agent_sql;

        -- 一時テーブルから結果を読み取って INSERT
        INSERT INTO RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS
            (branch_code, report_date, question, agent_response, answer_text, run_id)
        SELECT
            :v_bc::NUMBER,
            CURRENT_DATE(),
            :v_question,
            resp,
            (SELECT LISTAGG(c.value:text::STRING, '\n') WITHIN GROUP (ORDER BY c.index)
             FROM LATERAL FLATTEN(input => resp:content) c
             WHERE c.value:type::STRING = 'text'),
            resp:metadata:run_id::STRING
        FROM _tmp_agent_resp;
    END FOR;
    DROP TABLE IF EXISTS _tmp_agent_resp;
    RETURN 'バッチ処理完了: 支店 101〜105';
END;

-- ---------------------------------------------------------
-- Step 3-3: 生成されたレポートの確認
-- ---------------------------------------------------------

SELECT
    branch_code,
    report_date,
    answer_text,
    run_id,
    created_at
FROM RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS
ORDER BY branch_code;


-- =========================================================
-- シナリオ4: AML / 不正取引モニタリング
-- =========================================================
-- 
-- 【概要】
--   高額取引のアラートに対して、エージェントが自動で調査サマリーを
--   生成するパターン。構造化データ（取引履歴）と非構造化データ
--   （内部規定・KYCマニュアル）を横断的に分析する。
-- 
-- 【金融ユースケース】
--   - AML（アンチマネーロンダリング）アラートの初期調査自動化
--   - 高額取引の自動レビュー・リスク評価
--   - 調査員への引継ぎ資料の自動生成
-- 
-- 【重要】
--   本シナリオはデモ用です。実際の AML 運用では、
--   必ず Human-in-the-loop（人間によるレビュー）を組み込んでください。
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 4-1: 調査結果格納テーブルの作成
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS RETAIL_BANKING_DB.AGENT.AML_INVESTIGATION_RESULTS (
    investigation_id NUMBER AUTOINCREMENT,
    customer_id NUMBER(10,0) COMMENT '対象顧客番号',
    customer_name VARCHAR COMMENT '顧客名',
    alert_reason VARCHAR COMMENT 'アラート理由',
    txn_amount NUMBER(13,0) COMMENT 'アラート対象取引金額',
    txn_date NUMBER(8,0) COMMENT '取引日（YYYYMMDD）',
    agent_response VARIANT COMMENT 'エージェント応答（JSON全体）',
    investigation_summary VARCHAR COMMENT '調査サマリー（テキスト抽出済み）',
    run_id VARCHAR COMMENT 'エージェント実行ID（監査証跡）',
    investigated_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT '調査実行日時',
    review_status VARCHAR DEFAULT 'PENDING' COMMENT 'レビュー状態（PENDING/REVIEWED/ESCALATED）',
    reviewer VARCHAR COMMENT 'レビュー担当者',
    review_notes VARCHAR COMMENT 'レビューコメント',
    CONSTRAINT pk_aml_investigation PRIMARY KEY (investigation_id)
) COMMENT = 'AML調査結果（DATA_AGENT_RUN による自動調査）※最終判断は必ず人間が行うこと';

-- ---------------------------------------------------------
-- Step 4-2: 高額取引の検出とエージェントによる自動調査
-- ---------------------------------------------------------
-- 取引金額30万円以上の取引をアラート対象とし、
-- エージェントが顧客背景・取引パターン・KYC関連情報を調査
--
-- ※ シナリオ3と同様、DATA_AGENT_RUN の引数は定数リテラルである必要があるため、
--   Snowflake Scripting + EXECUTE IMMEDIATE で行ごとに実行する。

DECLARE
    v_customer_id STRING;
    v_customer_name STRING;
    v_alert_reason STRING;
    v_txn_amount STRING;
    v_txn_date STRING;
    v_question STRING;
    v_payload STRING;
    v_agent_sql STRING;
    c1 CURSOR FOR
        SELECT
            t."顧客番号"::STRING AS customer_id,
            c."漢字氏名１" AS customer_name,
            CASE
                WHEN t."取引金額" >= 500000 THEN '50万円以上の高額取引'
                WHEN t."取引金額" >= 300000 THEN '30万円以上の取引'
            END AS alert_reason,
            t."取引金額"::STRING AS txn_amount,
            t."運用日付"::STRING AS txn_date
        FROM RETAIL_BANKING_DB.RETAIL_BANKING_JP."流動性預金取引データ＿日次" t
        JOIN RETAIL_BANKING_DB.RETAIL_BANKING_JP."顧客基本属性情報＿月次" c
            ON t."顧客番号" = c."顧客番号"
            AND t."金融機関コード" = c."金融機関コード"
        WHERE t."取引金額" >= 300000
        QUALIFY ROW_NUMBER() OVER (PARTITION BY t."顧客番号" ORDER BY t."取引金額" DESC) = 1;
BEGIN
    FOR rec IN c1 DO
        v_customer_id := rec.customer_id;
        v_customer_name := rec.customer_name;
        v_alert_reason := rec.alert_reason;
        v_txn_amount := rec.txn_amount;
        v_txn_date := rec.txn_date;
        v_question := '以下の取引について調査してください。' ||
            '顧客名: ' || :v_customer_name ||
            ', 顧客番号: ' || :v_customer_id ||
            ', 取引金額: ' || :v_txn_amount || '円' ||
            ', 取引日: ' || :v_txn_date ||
            ', アラート理由: ' || :v_alert_reason ||
            '。この顧客の属性情報、最近の取引パターン、本人確認状況を確認し、' ||
            'リスク評価と調査所見をまとめてください。';
        v_payload := '{"messages":[{"role":"user","content":[{"type":"text","text":"' || :v_question || '"}]}],"stream":false}';

        -- DATA_AGENT_RUN をリテラル引数で実行し、結果を一時テーブルに格納
        v_agent_sql := 'CREATE OR REPLACE TEMPORARY TABLE _tmp_agent_resp AS ' ||
            'SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(' ||
            '''RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT'',' ||
            '''' || :v_payload || '''' ||
            ')) AS resp';
        EXECUTE IMMEDIATE :v_agent_sql;

        -- 一時テーブルから結果を読み取って INSERT
        INSERT INTO RETAIL_BANKING_DB.AGENT.AML_INVESTIGATION_RESULTS
            (customer_id, customer_name, alert_reason, txn_amount, txn_date,
             agent_response, investigation_summary, run_id)
        SELECT
            :v_customer_id::NUMBER,
            :v_customer_name,
            :v_alert_reason,
            :v_txn_amount::NUMBER,
            :v_txn_date::NUMBER,
            resp,
            (SELECT LISTAGG(c.value:text::STRING, '\n') WITHIN GROUP (ORDER BY c.index)
             FROM LATERAL FLATTEN(input => resp:content) c
             WHERE c.value:type::STRING = 'text'),
            resp:metadata:run_id::STRING
        FROM _tmp_agent_resp;
    END FOR;
    DROP TABLE IF EXISTS _tmp_agent_resp;
    RETURN 'AML調査バッチ完了';
END;

-- ---------------------------------------------------------
-- Step 4-3: 調査結果の確認
-- ---------------------------------------------------------

SELECT
    investigation_id,
    customer_name,
    alert_reason,
    txn_amount,
    investigation_summary,
    review_status,
    investigated_at
FROM RETAIL_BANKING_DB.AGENT.AML_INVESTIGATION_RESULTS
ORDER BY txn_amount DESC;

-- ---------------------------------------------------------
-- Step 4-4: レビュー担当者による確認・エスカレーション（手動操作）
-- ---------------------------------------------------------
-- 調査員がレビューした後のステータス更新例

-- UPDATE RETAIL_BANKING_DB.AGENT.AML_INVESTIGATION_RESULTS
-- SET review_status = 'REVIEWED',
--     reviewer = CURRENT_USER(),
--     review_notes = '取引パターンに異常なし。給与振込に該当。'
-- WHERE investigation_id = 1;

-- UPDATE RETAIL_BANKING_DB.AGENT.AML_INVESTIGATION_RESULTS
-- SET review_status = 'ESCALATED',
--     reviewer = CURRENT_USER(),
--     review_notes = '追加調査が必要。コンプライアンス部門へエスカレーション。'
-- WHERE investigation_id = 2;


-- =========================================================
-- シナリオ5: Task による定期実行（日次レポート自動生成）
-- =========================================================
-- 
-- 【概要】
--   Snowflake Task を使って DATA_AGENT_RUN を定期スケジュール実行し、
--   日次の取引サマリーレポートを自動生成する
-- 
-- 【金融ユースケース】
--   - 毎朝の経営日報（前日取引サマリー）の自動作成
--   - 週次のコンプライアンスレポート自動生成
--   - リアルタイムに近い異常検知レポート（短間隔スケジュール）
-- 
-- 【コストに関する注意】
--   - Task が実行されるたびにウェアハウスのコンピュートが発生
--   - AUTO_SUSPEND を適切に設定し、不要なコストを抑制すること
--   - 本番運用時は SCHEDULE の間隔とウェアハウスサイズを慎重に検討
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 5-1: 日次レポート格納テーブルの作成
-- ---------------------------------------------------------

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

-- ---------------------------------------------------------
-- Step 5-2: 日次サマリー生成用ストアドプロシージャの作成
-- ---------------------------------------------------------
-- ※ Task の AS 句でも DATA_AGENT_RUN の引数は定数リテラルである必要があるため、
--   ストアドプロシージャ内で EXECUTE IMMEDIATE を使い、Task から CALL する。

CREATE OR REPLACE PROCEDURE RETAIL_BANKING_DB.AGENT.GENERATE_DAILY_SUMMARY()
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    v_date_str STRING;
    v_question STRING;
    v_payload STRING;
    v_agent_sql STRING;
BEGIN
    v_date_str := DATEADD(DAY, -1, CURRENT_DATE())::STRING;
    v_question := '昨日（' || :v_date_str || '）の取引サマリーを作成してください。' ||
        '以下の項目を含めてください: ' ||
        '1. 総取引件数と総取引金額、' ||
        '2. 入金・出金の内訳、' ||
        '3. チャネル別（窓口/ATM/オンライン）の取引件数、' ||
        '4. 高額取引（30万円以上）の一覧、' ||
        '5. 特記事項やリスク所見';
    v_payload := '{"messages":[{"role":"user","content":[{"type":"text","text":"' || :v_question || '"}]}],"stream":false}';

    v_agent_sql := 'CREATE OR REPLACE TEMPORARY TABLE _tmp_agent_resp AS ' ||
        'SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(' ||
        '''RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT'',' ||
        '''' || :v_payload || '''' ||
        ')) AS resp';
    EXECUTE IMMEDIATE :v_agent_sql;

    INSERT INTO RETAIL_BANKING_DB.AGENT.DAILY_SUMMARY_REPORTS
        (report_date, report_type, agent_response, summary_text, run_id)
    SELECT
        DATEADD(DAY, -1, CURRENT_DATE()),
        'DAILY_TXN_SUMMARY',
        resp,
        (SELECT LISTAGG(c.value:text::STRING, '\n') WITHIN GROUP (ORDER BY c.index)
         FROM LATERAL FLATTEN(input => resp:content) c
         WHERE c.value:type::STRING = 'text'),
        resp:metadata:run_id::STRING
    FROM _tmp_agent_resp;

    DROP TABLE IF EXISTS _tmp_agent_resp;
    RETURN '日次レポート生成完了（対象日: ' || :v_date_str || '）';
END;

-- ---------------------------------------------------------
-- Step 5-3: Task の作成（毎朝9時に前日分のサマリーを生成）
-- ---------------------------------------------------------

CREATE OR REPLACE TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK
    WAREHOUSE = RETAIL_BANKING_WH
    SCHEDULE = 'USING CRON 0 9 * * * Asia/Tokyo'
    COMMENT = '日次取引サマリーレポート自動生成タスク'
AS
    CALL RETAIL_BANKING_DB.AGENT.GENERATE_DAILY_SUMMARY();

-- ---------------------------------------------------------
-- Step 5-4: Task の状態確認
-- ---------------------------------------------------------

SHOW TASKS IN SCHEMA RETAIL_BANKING_DB.AGENT;

-- ---------------------------------------------------------
-- Step 5-5: Task の有効化（本番運用開始時にコメント解除）
-- ---------------------------------------------------------
-- ⚠️ Task を RESUME するとスケジュール通りに自動実行が開始されます
--    テスト完了後に有効化してください

-- ALTER TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK RESUME;

-- ---------------------------------------------------------
-- Step 5-6: Task の手動テスト実行
-- ---------------------------------------------------------
-- スケジュールを待たずに即座に実行してテストする場合

-- EXECUTE TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK;

-- ---------------------------------------------------------
-- Step 5-7: Task の停止（不要になった場合）
-- ---------------------------------------------------------

-- ALTER TASK RETAIL_BANKING_DB.AGENT.DAILY_TXN_SUMMARY_TASK SUSPEND;


-- =========================================================
-- シナリオ6: マルチターン会話（thread_id の活用）
-- =========================================================
-- 
-- 【概要】
--   thread_id と parent_message_id を使い、
--   エージェントとの会話の文脈を維持しながら深掘り分析を行う
-- 
-- 【金融ユースケース】
--   - 「この顧客について詳しく」→「その取引履歴は？」→「類似顧客は？」
--     のような段階的な分析フロー
-- 
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- Step 6-1: 1ターン目 — 初期質問
-- ---------------------------------------------------------

SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'RETAIL_BANKING_DB.AGENT.RETAIL_BANKING_AGENT',
        $${
            "thread_id": 0,
            "parent_message_id": 0,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "取引金額が最も大きい顧客を教えてください"
                        }
                    ]
                }
            ],
            "stream": false
        }$$
    )
) AS first_response;

-- ---------------------------------------------------------
-- Step 6-2: 2ターン目 — 前回の回答を踏まえた深掘り
-- ---------------------------------------------------------
-- ※ 実際の運用では、1ターン目のレスポンスから thread_id と
--    message_id を取得して渡します。
--    以下は会話履歴を messages に含めるパターンの例です。

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
                            "text": "取引金額が最も大きい顧客を教えてください"
                        }
                    ]
                },
                {
                    "role": "assistant",
                    "content": [
                        {
                            "type": "text",
                            "text": "取引金額が最も大きい顧客は山田太郎様（顧客番号: 1000001）です。"
                        }
                    ]
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "その顧客の直近の取引履歴を詳しく教えてください。また、本人確認に必要な書類も確認してください。"
                        }
                    ]
                }
            ],
            "stream": false
        }$$
    )
) AS followup_response;


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

-- テーブルの削除
-- DROP TABLE IF EXISTS RETAIL_BANKING_DB.AGENT.BRANCH_SUMMARY_REPORTS;
-- DROP TABLE IF EXISTS RETAIL_BANKING_DB.AGENT.AML_INVESTIGATION_RESULTS;
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
--   - AML_INVESTIGATION_RESULTS（AML調査結果）
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
--   3. バッチ処理 — 支店別顧客サマリー自動生成
--   4. AML / 不正取引モニタリング
--   5. Task による定期実行（日次レポート）
--   6. マルチターン会話（thread_id の活用）
-- 
-- ⚠️ 注意:
--   - DATA_AGENT_RUN は非ストリーミングのため、リアルタイム対話UIには
--     REST API（/api/v2/cortex/agent:run）の直接呼び出しを推奨
--   - AML シナリオの最終判断は必ず人間が行うこと（Human-in-the-loop）
--   - Task の RESUME 前にコスト影響を確認すること
-- 
-- =========================================================
