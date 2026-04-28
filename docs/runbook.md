# AI_STREAM 運用メモ

## 起動

```powershell
.\exe.bat
```

または：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\main.ps1
```

## 投稿せずに確認

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\main.ps1 -DryRun
```

## よくあるエラー

### config/mykey.json が見つからない

`config/mykey.sample.json` をコピーしてください。

```powershell
Copy-Item .\config\mykey.sample.json .\config\mykey.json
```

### トークン期限切れ

`docs/refresh-token.md` を見て、YouTube/Google OAuth のRefresh Tokenを更新してください。

### Difyが返答しない

確認項目：

- Dify API Key
- Dify API URL
- Difyアプリが公開/利用可能か
- ネットワーク接続
- Dify側の利用上限

### YouTubeに投稿されない

確認項目：

- liveChatId が取得できているか
- Access Token が有効か
- YouTube Data API が有効か
- チャンネル/配信の権限が正しいか
