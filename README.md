# GAS から API Gateway(Step Functions) を呼び出してGoogle Sheetsに直接書き込み

## フォルダ構成

```
.
├── aws/                      # AWS SAM 関連
│   ├── template.yaml         # SAMテンプレート（インフラ定義）
│   ├── statemachine.asl.json # Step Functions定義（未使用）
│   ├── add/
│   │   └── app.py            # 加算処理Lambda関数
│   ├── output_to_gas/
│   │   ├── app.py            # Google Sheets API連携Lambda関数
│   │   └── requirements.txt  # Python依存関係
│   ├── events/
│   │   ├── add_event.json           # テスト用イベントデータ
│   │   └── output_to_gas_event.json # テスト用イベントデータ
│   ├── samconfig.toml        # sam deploy --guided で生成
│   └── .python-version       # Python バージョン指定
│
├── gas/                      # Google Apps Script 関連
│   ├── .clasp.json           # clasp 設定ファイル
│   ├── appsscript.json       # GAS プロジェクト設定ファイル
│   └── Code.js               # メインスクリプト（processSpreadsheet関数）
│
├── venv/                     # Python仮想環境（Git管理外）
├── service-account-key.json  # Googleサービスアカウントキー（Git管理外）
├── config.json               # 統合設定ファイル（Git管理外）
├── deploy.sh                 # デプロイスクリプト
├── local-test.sh             # ローカルテスト用スクリプト
├── .gitignore                # Git除外設定
├── .python-version           # Python バージョン指定
└── README.md                 # プロジェクト共通説明
```

## 前提条件

- AWS アカウントがあること
- `AWS CLI` がインストール・設定済みであること
- `SAM CLI` がインストール済みであること
- Google アカウントがあること
- Google Cloud Platform プロジェクトがあること
- `clasp` がローカルにインストール済みであること

## 構築手順

**注意: サービスアカウントキーはAWS Secrets Managerに保存されます**

### 1. Google Service Accountの作成

1. **Google Cloud Consoleにアクセス**
   - [Google Cloud Console](https://console.cloud.google.com/) にアクセス
   - プロジェクトを選択または作成

2. **Google Sheets APIを有効化**
   - 「APIとサービス」→「ライブラリ」
   - 「Google Sheets API」を検索して有効化

3. **サービスアカウントを作成**
   - 「APIとサービス」→「認証情報」
   - 「認証情報を作成」→「サービスアカウント」
   - 名前を入力して作成

4. **JSONキーをダウンロード**
   - 作成したサービスアカウントをクリック
   - 「キー」タブ→「キーを追加」→「JSON」
   - ダウンロードしたJSONファイルをプロジェクトルートに `service-account-key.json` として配置

5. **設定ファイルの作成**

```bash
# config.jsonを作成してスプレッドシートIDを設定
cat > config.json << EOF
{
  "spreadsheet_id": "YOUR_SPREADSHEET_ID",
  "sheet_name": "入力シート"
}
EOF
```

### 2. スプレッドシートの共有設定

1. **対象のスプレッドシートを開く**
2. **共有ボタンをクリック**
3. **サービスアカウントのメールアドレスを追加**
   - JSONキー内の `client_email` の値
   - 権限：「編集者」

### 3. ローカル開発環境のセットアップ（コード修正する場合）

```bash
# プロジェクトルートでPython仮想環境を作成
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Google APIライブラリをインストール
pip install -r aws/output_to_gas/requirements.txt

# 仮想環境を終了する場合
deactivate
```

### 4. GAS設定

```bash
# gas/.clasp.jsonへスクリプトIDを設定
cd gas

# .clasp.jsonファイルを作成/編集
cat > .clasp.json << EOF
{
  "scriptId": "YOUR_GAS_SCRIPT_ID",
  "rootDir": "$(pwd)"
}
EOF

# GASにログイン（初回のみ）
clasp login

# コードをpull（最新の取得）
clasp pull
```

**注意：**
- `YOUR_GAS_SCRIPT_ID`を実際のGASスクリプトIDに置き換えてください
- スクリプトIDはGASエディタのURLから取得できます
- API_URLは手動でGASスクリプトプロパティに設定してください（下記手順参照）

### 5. GASスクリプトプロパティの設定

`./deploy.sh all`実行後、表示されたAPI Endpointを使って手動で設定：

1. **GASエディタでスクリプトを開く**
2. **「プロジェクトの設定」→「スクリプトプロパティ」をクリック**
3. **「スクリプトプロパティを追加」で以下を設定：**
   - プロパティ: `API_URL`
   - 値: デプロイ後に表示されたAPI Endpoint URL

## デプロイ手順

### 1. AWSリソースのデプロイ

**簡単デプロイ（推奨）：**
```bash
# プロジェクトルートで実行
# 全てデプロイ
./deploy.sh all

# GASのみデプロイ
./deploy.sh gas

# AWSリソースのみデプロイ
./deploy.sh aws
```

**デプロイスクリプトの機能：**
- 設定ファイルの存在確認
- デプロイ対象の選択（gas/aws/all）
- GASコードのデプロイ
- AWSリソースのデプロイ
- APIエンドポイントURLの表示

**手動デプロイ：**
```bash
# 1. GASコードのデプロイ
cd gas
clasp push --force

# 2. AWSリソースのデプロイ
cd ../aws
sam build
sam deploy --parameter-overrides \
  SpreadsheetId="$(jq -r .spreadsheet_id ../config.json)" \
  SheetName="$(jq -r .sheet_name ../config.json)"

# 3. Secrets Managerにサービスアカウントキーを設定
aws secretsmanager put-secret-value \
  --secret-id gas-api-gateway/google-service-account-key \
  --secret-string file://../service-account-key.json
```

**注意：**
- サービスアカウントキーはAWS Secrets Managerに自動保存されます
- Lambda関数は実行時にSecrets Managerからキーを取得します

**初回デプロイ（設定保存用）：**
```bash
cd aws
# 初回は--guidedで設定を保存
sam deploy --guided
```
対話式で以下を入力：
- `SpreadsheetId`: `$(jq -r .spreadsheet_id ../config.json)`
- `SheetName`: `$(jq -r .sheet_name ../config.json)`

初回デプロイ後、Secrets Managerにサービスアカウントキーを設定：
```bash
aws secretsmanager put-secret-value \
  --secret-id gas-api-gateway/google-service-account-key \
  --secret-string file://../service-account-key.json
```

### 2. エンドポイントURL確認

```bash
# プロジェクトルートまたはawsディレクトリで実行
aws cloudformation describe-stacks --stack-name gas-api-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text --no-verify-ssl 2>/dev/null
```

## テスト手順

### 1. curlコマンドでのテスト

```bash
# プロジェクトルートで実行
# 直接JSONを指定
curl -X POST https://YOUR_API_ENDPOINT/prod/execution \
  -H "Content-Type: application/json" \
  -d '{
    "valueA": 5,
    "valueB": 7,
    "row": 2
  }'

# イベントファイルを使用
curl -X POST https://YOUR_API_ENDPOINT/prod/execution \
  -H "Content-Type: application/json" \
  -d @aws/events/add_event.json
```

### 2. ローカルLambdaテスト

**注意：ローカルテストではSecrets Managerにアクセスできないため、環境変数を使用**

```bash
# AddFunction単体テスト
./local-test.sh add

# OutputToGASFunction単体テスト（要service-account-key.json）
./local-test.sh output
```

**手動テスト：**
```bash
# AddFunction単体
cd aws
sam local invoke AddFunction -e events/add_event.json

# OutputToGASFunction単体（環境変数設定後）
export GOOGLE_SERVICE_ACCOUNT_KEY=$(cat ../service-account-key.json | jq -c .)
./local-test.sh setup
sam local invoke OutputToGASFunction -e events/output_to_gas_event.json --env-vars env.json
```

### 3. GASからの実行テスト

1. **スプレッドシートを開く**
2. **メニュー「カスタムメニュー」→「APIへ送信」をクリック**
3. **A列・B列のデータが自動的に処理され、C列に結果が書き込まれる**

**注意：**
- C列に既に値がある行はスキップされます
- A列またはB列が空の行もスキップされます

## 処理フロー

1. GAS → API Gateway → Step Functions実行開始
2. AddFunction → 数値の加算処理（A列 + B列）
3. OutputToGASFunction → Google Sheets APIで直接C列に結果を書き込み

## TIPS

### スタック削除

```bash
aws cloudformation delete-stack --stack-name gas-api-gateway
```

### 環境変数の確認

```bash
aws lambda get-function-configuration --function-name OutputToGASFunction --no-verify-ssl 2>/dev/null
```

### VS CodeでのPythonインタープリター設定

1. VS Codeでプロジェクトルートを開く
2. `aws/output_to_gas/app.py` ファイルを開く
3. 左下のPythonバージョン表示をクリック
4. `./venv/bin/python` を選択