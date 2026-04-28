# AI Stream — YouTube Live AI配信パイプライン

YouTube Liveのコメントに対してDify AIが自動回答し、Cartesia TTSで音声化してVRMアバターに喋らせる、AI配信用の完全自動パイプラインです。

---

## 🗺 システム全体構成

```
YouTube Live コメント取得（PowerShell）
        ↓
Dify（AI回答生成）
        ↓
PowerShell
  ├ テキスト → Cartesia TTS → wav生成
  ├ wav を Virtual Audio Cable に再生
        ↓
VRMアバターソフト（VSeeFace）
  → 音量ベースで口パク
        ↓
OBS
  ├ アバター映像キャプチャ
  ├ 音声ミックス
        ↓
YouTube Live 配信
```

---

## 🚀 機能一覧

- **コメント自動取得**：YouTube Live チャットからリアルタイムにコメントを取得
- **AI回答生成**：Dify APIを通じてコメントへの返答を自動生成
- **TTS音声生成**：Cartesia APIでAI回答テキストをWAVファイルに変換
- **音声再生**：Virtual Audio CableへWAVを再生→VSeeFaceアバターが口パク
- **チャット投稿**：AI回答をYouTube Liveチャットへ自動投稿

---

## 📦 動作環境

- OS：Windows 10/11
- 言語：PowerShell 5.1 以上
- 外部ツール：VRoid Studio、VSeeFace、VB-Audio Virtual Cable、OBS Studio

---

## 🔧 セットアップ手順

### 1. 必要なソフトのインストール
- [VRoid Studio](https://vroid.com/studio) — VRMアバター作成
- [VSeeFace](https://www.vseeface.icu/) — VRM表示＋口パク
- [VB-Audio Virtual Cable](https://vb-audio.com/Cable/) — 仮想オーディオデバイス
- [OBS Studio](https://obsproject.com/) — 配信合成

### 2. 設定ファイルの配置
`C:\ai-script\config\mykey.json` を以下の形式で作成してください：

```json
{
  "DifyApiKey": "your-dify-api-key",
  "CartesiaApiKey": "your-cartesia-api-key",
  "ClientId": "your-google-oauth-client-id",
  "ClientSecret": "your-google-oauth-client-secret",
  "RefreshToken": "your-google-refresh-token"
}
```

### 3. スクリプトの配置
`C:\ai-script\` 以下にこのリポジトリの内容を配置します：

```
C:\ai-script\
  ├ main.ps1
  ├ mod\
  │   ├ mod01.psm1 〜 mod10.psm1
  ├ config\
  │   └ mykey.json
  └ tts_output\     ← 自動生成される
```

### 4. VSeeFace の設定
- VSeeFace を起動し、VRMファイルを読み込む
- マイク入力を **CABLE Output (VB-Audio Virtual Cable)** に指定

### 5. Windowsの既定再生デバイス変更
- Windowsサウンド設定で既定の再生デバイスを **CABLE Input (VB-Audio Virtual Cable)** に変更

### 6. 実行
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\main.ps1
```

---

## 📁 モジュール一覧

| ファイル | 役割 |
|---------|------|
| mod01.psm1 | JSON設定読込 |
| mod02.psm1 | Google OAuthトークン管理 |
| mod03.psm1 | ユーティリティ |
| mod04.psm1 | ユーティリティ |
| mod05.psm1 | YouTube Live配信の自動検出 |
| mod06.psm1 | YouTube Liveコメント取得・監視 |
| mod07.psm1 | Dify AIチャットAPI連携 |
| mod08.psm1 | YouTube Liveチャット投稿 |
| mod09.psm1 | Cartesia TTS（テキスト→WAV生成） |
| mod10.psm1 | WAV音声再生（Virtual Audio Cable対応） |

---

## 🔑 必要なAPIキー

| サービス | 取得先 |
|---------|-------|
| Dify API Key | [Dify](https://dify.ai/) のアプリ設定 |
| Cartesia API Key | [Cartesia](https://cartesia.ai/) のダッシュボード |
| Google OAuth | [Google Cloud Console](https://console.cloud.google.com/) |
