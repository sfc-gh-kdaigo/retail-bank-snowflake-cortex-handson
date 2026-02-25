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
--    4. 04_rag_setup.sql         ← Cortex Search設定
--    5. 05_sproc_setup.sql       ← Stored Procedure
--    6. 06_agent_design.md       ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- =========================================================

USE DATABASE RETAIL_BANKING_DB;
USE WAREHOUSE RETAIL_BANKING_WH;


-- =============================================================================
-- 1. AI_COMPLETE: テキスト生成
-- =============================================================================
-- 最もシンプルなCortex AI Functions。LLMにテキスト生成を依頼する。

-- モデル比較: 同じ質問を異なるモデルで実行
SELECT AI_COMPLETE('claude-4-sonnet', '住宅ローンの固定金利と変動金利の違いを50字以内で教えてください。') AS RESPONSE;

SELECT AI_COMPLETE('openai-gpt-4.1', '住宅ローンの固定金利と変動金利の違いを50字以内で教えてください。') AS RESPONSE;

-- 構造化出力（response_format）: JSON形式で安定した出力を得る
SELECT AI_COMPLETE(
    'claude-4-sonnet',
    '以下の顧客問い合わせを分析してください: 「住宅ローンの繰上返済をしたいのですが、手数料はいくらですか？また、期間短縮型と返済額軽減型のどちらがお得ですか？」',
    {},
    {
        'type': 'json',
        'schema': {
            'type': 'object',
            'properties': {
                'category': {'type': 'string', 'description': '問い合わせカテゴリ（住宅ローン/預金/投資信託/カード/その他）'},
                'intent': {'type': 'string', 'description': '顧客の意図を20文字以内で'},
                'urgency': {'type': 'string', 'description': '緊急度（高/中/低）'},
                'requires_specialist': {'type': 'boolean', 'description': '専門担当者へのエスカレーションが必要か'}
            }
        }
    }
) AS RESPONSE;

-- 構造化出力の結果をフラット化して各カラムに展開
SELECT 
    result:"category"::VARCHAR AS "カテゴリ",
    result:"intent"::VARCHAR AS "顧客の意図",
    result:"urgency"::VARCHAR AS "緊急度",
    result:"requires_specialist"::BOOLEAN AS "専門担当要否"
FROM (
    SELECT AI_COMPLETE(
        'claude-4-sonnet',
        '以下の顧客問い合わせを分析してください: 「住宅ローンの繰上返済をしたいのですが、手数料はいくらですか？また、期間短縮型と返済額軽減型のどちらがお得ですか？」',
        {},
        {
            'type': 'json',
            'schema': {
                'type': 'object',
                'properties': {
                    'category': {'type': 'string', 'description': '問い合わせカテゴリ（住宅ローン/預金/投資信託/カード/その他）'},
                    'intent': {'type': 'string', 'description': '顧客の意図を20文字以内で'},
                    'urgency': {'type': 'string', 'description': '緊急度（高/中/低）'},
                    'requires_specialist': {'type': 'boolean', 'description': '専門担当者へのエスカレーションが必要か'}
                }
            }
        }
    ) AS result
);


-- =============================================================================
-- 2. AI_CLASSIFY: テキスト分類
-- =============================================================================
-- テキストを指定されたカテゴリに分類する。

-- 顧客問い合わせの分類
SELECT AI_CLASSIFY(
    '投資信託の解約方法を教えてください。基準価額が下がっているので早めに手続きしたいです。',
    ['口座開設', '預金', '融資', '投資信託', 'カード', '相続', '苦情']
) AS classification;

-- =============================================================================
-- 3. AI_SENTIMENT: 感情分析
-- =============================================================================
-- テキストの感情をスコア（-1〜1）で判定する。
-- 観点（aspect）を指定して、複数の軸で評価することも可能。

-- シンプルな感情分析
SELECT AI_SENTIMENT('住宅ローンの金利を引き下げていただき、大変助かりました。ありがとうございます。') AS sentiment_score;

SELECT AI_SENTIMENT('口座の不正利用が発覚し、対応が遅くて非常に不安です。') AS sentiment_score;

-- =============================================================================
-- 4. AI_EMBED: テキストのベクトル化
-- =============================================================================
-- テキストをベクトル（数値配列）に変換する。
-- 類似検索やクラスタリングの基盤となる機能。

SELECT AI_EMBED(
    'snowflake-arctic-embed-l-v2.0',
    '住宅ローンの繰上返済について教えてください'
) AS embedding;

-- ベクトル間の類似度比較（コサイン類似度）
SELECT VECTOR_COSINE_SIMILARITY(
    AI_EMBED('snowflake-arctic-embed-l-v2.0', '住宅ローンの繰上返済について教えてください'),
    AI_EMBED('snowflake-arctic-embed-l-v2.0', '住宅ローンの一部返済の手続き方法を知りたい')
) AS similarity_high;

SELECT VECTOR_COSINE_SIMILARITY(
    AI_EMBED('snowflake-arctic-embed-l-v2.0', '住宅ローンの繰上返済について教えてください'),
    AI_EMBED('snowflake-arctic-embed-l-v2.0', '外貨預金の為替レートはいつ更新されますか')
) AS similarity_low;


-- =============================================================================
-- 5. TRANSLATE: 多言語翻訳
-- =============================================================================
-- テキストを指定言語に翻訳する。海外送金対応・監査・外国人顧客対応に活用。

SELECT SNOWFLAKE.CORTEX.TRANSLATE(
    'お客様の口座から不審な引き落としが検出されました。至急ご確認をお願いいたします。',
    'ja', 'en'
) AS english_translation;

SELECT SNOWFLAKE.CORTEX.TRANSLATE(
    'お客様の口座から不審な引き落としが検出されました。至急ご確認をお願いいたします。',
    'ja', 'zh'
) AS chinese_translation;


-- =========================================================
-- 02_ai_functions_demo.sql 完了
-- =========================================================
-- 
-- 実行したCortex AI Functions:
--   1. AI_COMPLETE   : テキスト生成・構造化出力（JSON）
--   2. AI_CLASSIFY   : テキスト分類
--   3. AI_SENTIMENT  : 感情分析
--   4. AI_EMBED      : ベクトル化・類似度比較
--   5. TRANSLATE     : 多言語翻訳
-- 
-- 次のステップ:
--   → 03_sv_setup.sql（Semantic View設定）
-- 
-- =========================================================
