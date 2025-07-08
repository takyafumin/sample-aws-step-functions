import json

def lambda_handler(event, context):
    # event が str の場合は dict にパース
    if isinstance(event, str):
        event = json.loads(event)

    valueA = event.get('valueA')
    valueB = event.get('valueB')
    row = event.get('row')

    result = valueA + valueB

    # event は書き換えずに新しい dict を返す
    return {
        'statusCode': 200,
        'sum': result,
        'row': row
    }
