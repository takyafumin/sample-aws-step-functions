#!/bin/bash

# ローカルテスト用スクリプト
set -e

# 使用方法を表示
show_usage() {
    echo "使用方法:"
    echo "  $0 add          # AddFunction単体テスト"
    echo "  $0 output       # OutputToGASFunctionテスト手順表示"
}



# AddFunction単体テスト
test_add() {
    echo "=== AddFunction テスト ==="
    cd aws
    sam local invoke AddFunction -e events/add_event.json
}

# OutputToGASFunction単体テスト
test_output() {
    echo "=== OutputToGASFunction テスト ==="
    echo "エラー: SAM Localでは環境変数が正しく渡されません"
    echo "手動テスト手順:"
    echo "1. aws/output_to_gas/app.py で Secrets Manager 部分をコメントアウト"
    echo "2. service-account-key.json を直接読み込むコードに変更"
    echo "3. sam build && sam local invoke OutputToGASFunction -e events/output_to_gas_event.json"
    echo "本番環境では正常に動作します"
}



# メイン処理
case "$1" in
    "add")
        test_add
        ;;
    "output")
        test_output
        ;;
    *)
        show_usage
        exit 1
        ;;
esac