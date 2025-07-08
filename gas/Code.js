// API_URLはスクリプトプロパティから取得
function getApiUrl() {
  const apiUrl = PropertiesService.getScriptProperties().getProperty('API_URL');
  if (!apiUrl) {
    throw new Error('API_URLがスクリプトプロパティに設定されていません。\nスクリプトエディタで「プロジェクトの設定」→「スクリプトプロパティ」からAPI_URLを設定してください。');
  }
  return apiUrl;
} 

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('カスタムメニュー')
    .addItem('APIへ送信', 'processSpreadsheet')
    .addToUi();
}

/**
 * 列A,Bを読み取り、API Gateway に送る
 * 書く場所: gas/Code.gs
 */
function processSpreadsheet() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = spreadsheet.getSheetByName('入力シート');
  
  const lastRow = sheet.getLastRow();

  for (let row = 2; row <= lastRow; row++) {
    // C列に既に値がある場合はスキップ
    const existingResult = sheet.getRange(row, 3).getValue();
    if (existingResult !== '' && existingResult !== null) {
      Logger.log(`Row ${row}: 既に結果があります (${existingResult})、スキップします`);
      continue;
    }
    
    const valueA = sheet.getRange(row, 1).getValue();
    const valueB = sheet.getRange(row, 2).getValue();
    
    // A列またはB列が空の場合もスキップ
    if (valueA === '' || valueA === null || valueB === '' || valueB === null) {
      Logger.log(`Row ${row}: A列またはB列が空です、スキップします`);
      continue;
    }

    const payload = JSON.stringify({
      valueA: valueA,
      valueB: valueB,
      row: row
    });

    const options = {
      method: 'POST',
      contentType: 'application/json',
      payload: payload
    };

    Logger.log(`Row ${row}: APIへ送信 (A:${valueA}, B:${valueB})`);
    UrlFetchApp.fetch(getApiUrl(), options);
  }
}
