#requires -Version 5.1
# mod09.psm1 : Cartesia TTS API を使ったテキスト→WAV生成
# API: https://api.cartesia.ai/tts/bytes
# 関連Issue: [AI Task] TTS - Cartesia APIを使ったテキスト→WAV生成モジュール作成

Set-StrictMode -Version Latest

# ---------- Cartesia APIキーを config/mykey.json から取得 ----------
function Get-CartesiaApiKey {
  [CmdletBinding()]
  param(
    [Parameter()][string]$Path = "C:\ai-script\config\mykey.json"
  )

  if (-not (Test-Path $Path)) {
    throw "設定ファイルが見つかりません: $Path"
  }

  try {
    $json = Get-Content $Path -Raw | ConvertFrom-Json
    if (-not $json.CartesiaApiKey) {
      throw "mykey.json に CartesiaApiKey がありません。"
    }
    return $json.CartesiaApiKey
  } catch {
    throw "mykey.json の読込に失敗しました: $($_.Exception.Message)"
  }
}

# ---------- テキストをCartesia APIに送信してWAVファイルを生成 ----------
function Invoke-CartesiaTTS {
  [CmdletBinding()]
  param(
    # Cartesia APIキー（省略時はmykey.jsonから自動取得）
    [Parameter()][string]$ApiKey,
    # 読み上げるテキスト
    [Parameter(Mandatory)][string]$Text,
    # 出力WAVファイルパス（省略時は一時ファイルを使用）
    [Parameter()][string]$OutputPath,
    # 使用するモデルID
    [Parameter()][string]$ModelId = "sonic-2",
    # 音声ID（Cartesiaのボイスライブラリより）
    [Parameter()][string]$VoiceId = "a0e99841-438c-4a64-b679-ae501e7d6091",
    # 言語コード
    [Parameter()][string]$Language = "ja",
    # サンプルレート
    [Parameter()][int]$SampleRate = 44100
  )

  # APIキー解決
  if (-not $ApiKey) {
    $ApiKey = Get-CartesiaApiKey
  }

  # 出力パス未指定の場合は一時ファイル
  if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.wav'
  }

  # 出力ディレクトリが存在しない場合は作成
  $outDir = Split-Path $OutputPath -Parent
  if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }

  $endpoint = "https://api.cartesia.ai/tts/bytes"
  $headers = @{
    "X-API-Key"        = $ApiKey
    "Cartesia-Version" = "2024-11-13"
    "Content-Type"     = "application/json"
  }

  $body = @{
    model_id   = $ModelId
    transcript = $Text
    voice      = @{
      mode = "id"
      id   = $VoiceId
    }
    language      = $Language
    output_format = @{
      container   = "wav"
      encoding    = "pcm_f32le"
      sample_rate = $SampleRate
    }
  }

  try {
    Write-Verbose "[Cartesia TTS] 音声生成中: $($Text.Substring(0, [Math]::Min(40, $Text.Length)))..."
    Invoke-RestMethod `
      -Uri $endpoint `
      -Method Post `
      -Headers $headers `
      -Body ($body | ConvertTo-Json -Depth 6 -Compress) `
      -OutFile $OutputPath
    Write-Host ("🎤 TTS生成OK → {0}" -f $OutputPath) -ForegroundColor Cyan
    return $OutputPath
  } catch {
    Write-Host "❌ Cartesia TTSエラー: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    return $null
  }
}

Export-ModuleMember -Function Get-CartesiaApiKey, Invoke-CartesiaTTS
