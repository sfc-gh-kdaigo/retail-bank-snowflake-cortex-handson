-- コンテキストを指定してデータベースを切り替える
 SET my_db = 'USER$' || CURRENT_USER();                                                              
 USE DATABASE IDENTIFIER($my_db);  

-- GitHubリポジトリと連携するためのAPI統合を作成
CREATE OR REPLACE API INTEGRATION git_api_integration
 API_PROVIDER = git_https_api
 API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-kdaigo/')
 ENABLED = TRUE;

-- リテール金融向けハンズオン用のGitHubリポジトリを登録
CREATE OR REPLACE GIT REPOSITORY retail_bank_snowflake_cortex_handson
 API_INTEGRATION = git_api_integration
 ORIGIN = 'https://github.com/sfc-gh-kdaigo/retail-bank-snowflake-cortex-handson.git';
