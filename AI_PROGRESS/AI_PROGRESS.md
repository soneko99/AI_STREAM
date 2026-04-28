## 概要
- 最終更新日: 2026-04-28
- 全体進捗: 80%

## 機能別進捗
| 機能 | 状態 | 備考 |
|------|------|------|
| コメント取得 | 完了 | mod05.psm1, mod06.psm1 実装済み |
| Dify AI回答生成 | 完了 | mod07.psm1 実装済み |
| YouTube Live投稿 | 完了 | mod08.psm1 実装済み |
| テキスト→Cartesia TTS→wav生成 | 完了 | mod09.psm1 新規作成済み |
| wavをVirtual Audio Cableへ再生 | 完了 | mod10.psm1 新規作成済み |
| main.ps1へのTTS統合 | 完了 | Dify回答→TTS→再生パイプライン統合済み |
| アバター生成（VRoid Studio） | 完了 | VRoid Studioでアバター作成・VRMエクスポート済み |
| VSeeFace表示確認 | 完了 | VSeeFace起動・VRM読込・フェイストラッキング確認済み |
| VSeeFace口パク設定 | 進行中 | CABLE Output設定未完了・口パク動作未確認（Issue #7 残課題） |
| OBS合成設定 | 未着手 | 外部ソフト設定・手動作業 |
| YouTube Live配信 | 進行中 | 基盤コード実装済み（認証・配信検出） |
| README.md更新 | 完了 | システム構成・セットアップ手順を記載 |

## 次にやるべきこと（Top3）
1. VB-Audio Virtual Cable をインストール後、OS再起動し VSeeFace のマイク入力に "CABLE Output" が表示されることを確認する（Issue #7 残課題）
2. Windowsのサウンド設定で既定再生デバイスを "CABLE Input" に変更し、`main.ps1` のTTS再生でアバターが口パクすることを確認する
3. OBS でアバター映像・Virtual Cable音声をキャプチャして配信テストを行う

## 実行ログ
- 2026-04-28: 設計概要Issue #2を解析、リポジトリスキャン実施
- 2026-04-28: AI_PROGRESS.md 初回作成
- 2026-04-28: mod09.psm1（Cartesia TTS テキスト→WAV生成）新規実装
- 2026-04-28: mod10.psm1（Virtual Audio Cable再生 / winmm.dll P/Invoke）新規実装
- 2026-04-28: main.ps1 にmod09/mod10をインポートし、TTSパイプラインを統合
- 2026-04-28: README.md をシステム全体構成・セットアップ手順に合わせて刷新
- 2026-04-28: VRoid Studio でアバター作成・VRMエクスポート完了（Issue #7）
- 2026-04-28: VSeeFace インストール・起動・VRM読込・フェイストラッキング確認完了（Issue #7）
- 2026-04-28: VSeeFaceのマイク入力にCABLE Output設定不可（VB-Audio Virtual Cable未インストール起因）→ Issue #7 残課題

## 課題・リスク
- VRoid Studio / VSeeFace / OBSはGUIツールのためコードによる自動化不可。手動セットアップが必要。
- `Invoke-WavPlayback`（mod10）はWindowsの既定再生デバイスに対して再生する。Virtual Cableへ出力するには、事前にWindowsの既定デバイスを "CABLE Input" に変更する必要がある。
- Cartesia APIのボイスIDはデフォルト `a0e99841-438c-4a64-b679-ae501e7d6091`（英語音声）。日本語音声が必要な場合はCartesiaのボイスライブラリで日本語対応ボイスIDに変更すること。
- `tts_output/` フォルダにWAVファイルが蓄積する。定期クリーンアップ処理の追加を検討。

## メモ
- 実装済みモジュール: mod01〜mod10
- パイプライン全体: YouTube Live コメント → Dify AI → Cartesia TTS(mod09) → Virtual Cable(mod10) → VSeeFace 口パク → OBS → YouTube Live
- 残タスクはすべて外部ソフト（GUI）の設定・操作であり、コード実装は完了状態
