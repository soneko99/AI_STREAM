# YouTube Refresh Token 更新手順

## 目的

YouTube Data API の Access Token が期限切れになった場合でも、Refresh Token から再取得できるようにします。

## 確認するもの

- Google Cloud Console の OAuth Client ID
- OAuth Client Secret
- YouTube Data API v3 が有効になっていること
- 必要なスコープが含まれていること

## 注意

Refresh Token や Access Token は秘密情報です。

以下はGitHubにコミットしないでください。

```text
config/mykey.json
config/youtube_tokens.json
youtube_tokens.json
```

## 更新後にやること

1. `config/mykey.json` に新しいRefresh Tokenを反映
2. 古い token json がある場合は退避または削除
3. DryRunで確認

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\main.ps1 -DryRun
```
