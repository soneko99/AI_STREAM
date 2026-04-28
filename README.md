# AI_STREAM

AI_STREAM は、YouTube Live のコメントを取得し、Dify でAI回答を生成して、YouTube Liveチャットへ自動投稿する PowerShell 製の配信支援Botです。

将来的には、Dify回答を Cartesia TTS で音声化し、Virtual Audio Cable 経由でVRMアバターの口パク・OBS配信へ接続する想定です。

## 現在の処理フロー

```text
YouTube Live コメント取得
↓
Dify にコメント送信
↓
Dify の回答を取得
↓
YouTube Live チャットへ返信投稿
```

## 想定する最終構成

```text
YouTube Live コメント取得
↓
DifyでAI回答生成
↓
Cartesia TTSで音声化
↓
Virtual Audio Cableへ再生
↓
VRMアバターソフトで口パク
↓
OBSでYouTube配信
```

## ディレクトリ構成

```text
AI_STREAM/
├─ main.ps1
├─ exe.bat
├─ mod/
│  ├─ mod01.psm1
│  ├─ mod02.psm1
│  ├─ mod03.psm1
│  ├─ mod05.psm1
│  ├─ mod06.psm1
│  ├─ mod07.psm1
│  ├─ mod08.psm1
│  └─ mod09_text_sanitize.psm1
├─ config/
│  ├─ mykey.sample.json
│  └─ mykey.json
└─ docs/
```

## セットアップ

### 1. configを作成

```powershell
Copy-Item .\config\mykey.sample.json .\config\mykey.json
```

`config/mykey.json` に Google / YouTube / Dify のキーを設定してください。

`mykey.json` は秘密情報を含むため、GitHubにコミットしないでください。

### 2. PowerShellで実行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\main.ps1
```

または、Windows上で `exe.bat` を実行します。

## DryRun

YouTubeへ投稿せず、取得・Dify応答まで確認する場合：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\main.ps1 -DryRun
```

## 重要な変更点

以前のように `C:\ai-script` 固定ではなく、`main.ps1` が置かれている場所をプロジェクトルートとして動作します。

必要であれば、環境変数 `AI_SCRIPT_ROOT` でルートを明示できます。

```powershell
$env:AI_SCRIPT_ROOT = "C:\ai-script"
```

## 注意

- APIキーやトークンをコミットしないでください。
- `config/mykey.json` は `.gitignore` に入れてください。
- Difyの回答が長い場合、YouTubeチャット向けに短縮されます。
- 現時点ではCartesia TTSは設定枠のみで、実処理は別フェーズです。
