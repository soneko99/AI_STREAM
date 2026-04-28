<# ==========================================
 YouTube Live ↔ Dify AI 自動応答Bot with TTS (main.ps1)
 ------------------------------------------
 前提:
 - C:\ai-script\mod\ に mod01〜10.psm1 が配置済み
 - C:\ai-script\config\mykey.json に DifyApiKey, CartesiaApiKey, Google OAuthトークン類が保存済み
 - TTS音声を Virtual Audio Cable に再生する場合は、Windowsの既定の再生デバイスを
   "CABLE Input (VB-Audio Virtual Cable)" に設定してから起動してください。
 ========================================== #>

# ====== 文字化け対策 ======
try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# ====== モジュール読込 ======
Import-Module "C:\ai-script\mod\mod02.psm1" -Force  # トークン保証
Import-Module "C:\ai-script\mod\mod05.psm1" -Force  # live配信検出
Import-Module "C:\ai-script\mod\mod06.psm1" -Force  # コメント監視
Import-Module "C:\ai-script\mod\mod07.psm1" -Force  # Dify送信
Import-Module "C:\ai-script\mod\mod08.psm1" -Force  # チャット投稿
Import-Module "C:\ai-script\mod\mod09.psm1" -Force  # Cartesia TTS
Import-Module "C:\ai-script\mod\mod10.psm1" -Force  # 音声再生（Virtual Cable）

# ====== アクセストークン確保 ======
$AccessToken = $null; $Headers = $null
Ensure-AccessToken -AccessToken ([ref]$AccessToken) -Headers ([ref]$Headers)
Write-Host "✅ Access token ensured." -ForegroundColor Cyan

# ====== ライブ自動検出 ======
Write-Host "🔍 ライブ配信を検索中..." -ForegroundColor Yellow
$det = Detect-ActiveLive -Headers $Headers
if (-not $det) { throw "配信が見つかりません。YouTubeでライブ配信を開始してください。" }

$videoId   = $det.videoId
$liveChatId = $det.chatId
Write-Host ("🎥 videoId={0} / source={1}" -f $videoId, $det.source) -ForegroundColor Yellow

# chatId が null の場合は videos API で確定
if (-not $liveChatId) {
    $liveChatId = Get-LiveChatId -Headers $Headers -VideoId $videoId
}
if (-not $liveChatId) { throw "liveChatIdが取得できませんでした。" }
Write-Host ("💬 liveChatId={0}" -f $liveChatId) -ForegroundColor Yellow

# ====== Dify APIキー読込 ======
$DifyApiKey = Get-DifyApiKey
if (-not $DifyApiKey) { throw "DifyApiKeyが見つかりません（mykey.jsonを確認）。" }
Write-Host "🔑 DifyApiKey loaded." -ForegroundColor Yellow

# ====== Cartesia APIキー読込 ======
$CartesiaApiKey = $null
try {
    $CartesiaApiKey = Get-CartesiaApiKey
    Write-Host "🔑 CartesiaApiKey loaded." -ForegroundColor Yellow
} catch {
    Write-Host "⚠ CartesiaApiKeyが見つかりません。TTS機能は無効になります。" -ForegroundColor Yellow
}

# ====== TTS音声保存先ディレクトリ ======
$TtsOutputDir = "C:\ai-script\tts_output"
if (-not (Test-Path $TtsOutputDir)) {
    New-Item -ItemType Directory -Path $TtsOutputDir -Force | Out-Null
}

# ====== コメント監視開始 ======
Write-Host "🚀 コメント監視ループを開始します..." -ForegroundColor Cyan
$seen = New-Object System.Collections.Generic.HashSet[string]
$next = $null
$lastReplyAt = Get-Date '2000-01-01'
$MinReplyIntervalSec = 3

while ($true) {
    # トークン更新（1ループごとに再チェック）
    Ensure-AccessToken -AccessToken ([ref]$AccessToken) -Headers ([ref]$Headers)

    # コメント取得
    $resp = Get-LiveChatMessages -Headers $Headers -LiveChatId $liveChatId -PageToken $next
    if (-not $resp) {
        Write-Host "⚠ コメント取得エラー。2秒後に再試行..." -ForegroundColor Yellow
        Start-Sleep 2
        continue
    }

    foreach ($it in $resp.items) {
        if (-not $seen.Add($it.id)) { continue }

        $msg = $it.snippet.displayMessage
        $author = $it.authorDetails.displayName
        $isOwner = [bool]$it.authorDetails.isChatOwner

        # 配信者コメントは「!」で始まるもののみ対象（ループ防止）
        $startsWithBang = $msg.StartsWith('!')
        if ($isOwner -and -not $startsWithBang) { continue }

        # "!〇〇" の場合は先頭の!を除去して送信内容にする
        $query = if ($startsWithBang) { $msg.Substring(1).Trim() } else { $msg }

        if ([string]::IsNullOrWhiteSpace($query)) { continue }

        Write-Host ("🗣 [{0}] {1}" -f $author, $query)

        # ---- Dify連携 ----
        $answer = Invoke-DifyChat -ApiKey $DifyApiKey -Query $query -User $author
        if (-not $answer) { continue }

        # ---- レート制御 ----
        $elapsed = (New-TimeSpan -Start $lastReplyAt -End (Get-Date)).TotalSeconds
        if ($elapsed -lt $MinReplyIntervalSec) {
            Start-Sleep -Seconds ($MinReplyIntervalSec - $elapsed)
        }

        # ---- YouTubeへ投稿 ----
        Post-LiveChatMessage -Headers $Headers -LiveChatId $liveChatId -Message $answer
        $lastReplyAt = Get-Date

        # ---- Cartesia TTS → Virtual Audio Cable 再生 ----
        if ($CartesiaApiKey) {
            $timestamp = (Get-Date -Format 'yyyyMMdd_HHmmss')
            $wavPath = Join-Path $TtsOutputDir "tts_$timestamp.wav"
            $wavFile = Invoke-CartesiaTTS -ApiKey $CartesiaApiKey -Text $answer -OutputPath $wavPath
            if ($wavFile) {
                Invoke-WavPlayback -WavPath $wavFile
            }
        }
    }

    $next = $resp.nextPageToken
    Start-Sleep -Milliseconds ([int]$resp.pollingIntervalMillis + 200)
}
