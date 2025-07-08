#!/bin/bash

# デプロイスクリプト
# 使用方法: ./deploy.sh [gas|aws|all]

set -e

# 引数チェック
DEPLOY_TARGET=$1

if [[ -z "$DEPLOY_TARGET" || ("$DEPLOY_TARGET" != "gas" && "$DEPLOY_TARGET" != "aws" && "$DEPLOY_TARGET" != "all") ]]; then
    echo "使用方法: $0 [gas|aws|all]"
    echo "  gas: GASのみデプロイ"
    echo "  aws: AWSリソースのみデプロイ"
    echo "  all: 両方デプロイ"
    exit 1
fi

# 設定ファイルの存在確認
if [ ! -f "config.json" ]; then
    echo "Error: config.json が見つかりません"
    echo "以下のコマンドで作成してください:"
    echo 'cat > config.json << EOF'
    echo '{'
    echo '  "spreadsheet_id": "YOUR_SPREADSHEET_ID",'
    echo '  "sheet_name": "入力シート"'
    echo '}'
    echo 'EOF'
    exit 1
fi

if [ ! -f "service-account-key.json" ]; then
    echo "Error: service-account-key.json が見つかりません"
    echo "Google Service Accountのキーファイルをプロジェクトルートに配置してください"
    exit 1
fi

if [[ "$DEPLOY_TARGET" == "gas" || "$DEPLOY_TARGET" == "all" ]] && [ ! -f "gas/.clasp.json" ]; then
    echo "Error: gas/.clasp.json が見つかりません"
    echo "GASのスクリプトIDを設定してください"
    exit 1
fi

# AWS用の設定値を読み込み（AWSデプロイ時のみ）
if [[ "$DEPLOY_TARGET" == "aws" || "$DEPLOY_TARGET" == "all" ]]; then
    SPREADSHEET_ID=$(jq -r .spreadsheet_id config.json)
    SHEET_NAME=$(jq -r .sheet_name config.json)
    

fi



echo "=== Deploy Start ($DEPLOY_TARGET) ==="
if [[ "$DEPLOY_TARGET" == "aws" || "$DEPLOY_TARGET" == "all" ]]; then
    echo "SpreadsheetId: $SPREADSHEET_ID"
    echo "SheetName: $SHEET_NAME"
fi
echo ""

# GASデプロイ
if [[ "$DEPLOY_TARGET" == "gas" || "$DEPLOY_TARGET" == "all" ]]; then
    echo "1. GASコードをデプロイ中..."
    cd gas
    clasp push --force
    echo "✓ GASデプロイ完了"
    echo ""
    cd ..
fi

# AWSリソースデプロイ
if [[ "$DEPLOY_TARGET" == "aws" || "$DEPLOY_TARGET" == "all" ]]; then
    echo "2. AWSリソースをビルド中..."
    cd aws
    sam build
    echo "✓ ビルド完了"
    echo ""
    
    echo "3. AWSリソースをデプロイ中..."
    sam deploy --parameter-overrides \
      SpreadsheetId="$SPREADSHEET_ID" \
      SheetName="$SHEET_NAME"
    
    echo "4. Secrets Managerにサービスアカウントキーを設定中..."
    aws secretsmanager put-secret-value \
      --secret-id gas-api-gateway/google-service-account-key \
      --secret-string file://../service-account-key.json
    echo "✓ AWSデプロイ完了"
    echo ""
    cd ..
fi

# エンドポイントURL表示とGASスクリプトプロパティ設定（AWSデプロイ時のみ）
if [[ "$DEPLOY_TARGET" == "aws" || "$DEPLOY_TARGET" == "all" ]]; then
    echo "=== デプロイ結果 ==="
    API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name gas-api-gateway \
      --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
      --output text --no-verify-ssl 2>/dev/null)
    echo "API Endpoint: $API_ENDPOINT"
    
    # GASスクリプトプロパティの手動設定案内
    if [[ "$DEPLOY_TARGET" == "all" ]]; then
        echo ""
        echo "4. GASスクリプトプロパティを手動で設定してください："
        echo "   1. GASエディタでスクリプトを開く"
        echo "   2. 「プロジェクトの設定」→「スクリプトプロパティ」をクリック"
        echo "   3. 「スクリプトプロパティを追加」で以下を設定："
        echo "      プロパティ: API_URL"
        echo "      値: $API_ENDPOINT"
    fi
    echo ""
fi

echo "✅ ${DEPLOY_TARGET}のデプロイが完了しました！"
