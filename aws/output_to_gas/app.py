import json
import os
import boto3
from googleapiclient.discovery import build
from google.oauth2 import service_account

def lambda_handler(event, context):
    # デバッグ: 受信データをログ出力
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Step Functions から渡ってくる
    row = event.get('row')
    result = event.get('sum')  # AddFunctionが'sum'で出力している
    
    print(f"Processing - row: {row}, result: {result}")
    
    # Google Sheets APIを使用して直接書き込み
    try:
        # スプレッドシートIDとシート名を環境変数から取得
        SPREADSHEET_ID = os.environ.get('SPREADSHEET_ID')
        SHEET_NAME = os.environ.get('SHEET_NAME', '入力シート')
        
        # サービスアカウントキーをSecrets Managerから取得
        secrets_client = boto3.client('secretsmanager')
        secret_name = 'gas-api-gateway/google-service-account-key'
        
        # ローカルテスト用: 環境変数を優先チェック
        service_account_key = os.environ.get('GOOGLE_SERVICE_ACCOUNT_KEY')
        print(f"Environment variable GOOGLE_SERVICE_ACCOUNT_KEY exists: {service_account_key is not None}")
        if service_account_key:
            print(f"Using environment variable for service account key (length: {len(service_account_key)})")
        else:
            # 本番環境: Secrets Managerから取得
            try:
                response = secrets_client.get_secret_value(SecretId=secret_name)
                service_account_key = response['SecretString']
                print(f"Service account key retrieved from Secrets Manager")
            except Exception as secrets_error:
                print(f"Failed to get secret: {secrets_error}")
                raise Exception(f"Cannot retrieve service account key: {secrets_error}")
        
        if not service_account_key:
            raise Exception("Service account key is empty")
            
        try:
            service_account_info = json.loads(service_account_key)
        except json.JSONDecodeError as json_error:
            print(f"JSON decode error: {json_error}")
            print(f"Service account key length: {len(service_account_key) if service_account_key else 0}")
            raise Exception(f"Invalid JSON in service account key: {json_error}")
        credentials = service_account.Credentials.from_service_account_info(
            service_account_info,
            scopes=['https://www.googleapis.com/auth/spreadsheets']
        )
        
        service = build('sheets', 'v4', credentials=credentials)
        
        # セルの範囲を指定 (C列の指定した行)
        range_name = f'{SHEET_NAME}!C{row}'
        
        # 値を更新
        body = {
            'values': [[result]]
        }
        
        result_api = service.spreadsheets().values().update(
            spreadsheetId=SPREADSHEET_ID,
            range=range_name,
            valueInputOption='RAW',
            body=body
        ).execute()
        
        print(f"Successfully updated cell {range_name} with value {result}")
        print(f"API response: {result_api}")
        
        return {
            'statusCode': 200,
            'body': 'Success',
            'updatedRange': range_name,
            'updatedValue': result,
            'apiResponse': result_api
        }
        
    except Exception as e:
        print(f"Error updating spreadsheet: {e}")
        print(f"Error type: {type(e)}")
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}',
            'row': row,
            'result': result
        }
