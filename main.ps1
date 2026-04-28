param(
    [string]$RootPath = "",
    [string]$ConfigPath = "",
    [int]$PollSeconds = 5,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ============================================================
# AI_STREAM main.ps1
# - 固定パスを使わず、main.ps1 の配置場所を基準に動作
# - 既存 mod/*.psm1 を読み込み、既存関数を利用
# - mod02 の Ensure-AccessToken は [ref] 必須のため、Get-AuthHeaders 経由で呼び出す
# ============================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[AI_STREAM] $Message"
}

function Resolve-AiStreamRoot {
    param([string]$RootPath)

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        return (Resolve-Path $RootPath).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:AI_SCRIPT_ROOT)) {
        return (Resolve-Path $env:AI_SCRIPT_ROOT).Path
    }

    return $PSScriptRoot
}

function Import-AiStreamModules {
    param([Parameter(Mandatory=$true)][string]$Root)

    $modDir = Join-Path $Root "mod"
    if (-not (Test-Path $modDir)) {
        throw "mod フォルダが見つかりません: $modDir"
    }

    Get-ChildItem -Path $modDir -Filter "*.psm1" | Sort-Object Name | ForEach-Object {
        Write-Info "Import module: $($_.Name)"
        Import-Module $_.FullName -Force
    }
}

function Read-AiStreamConfig {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [string]$ConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path $Root "config\mykey.json"
    }

    if (-not (Test-Path $ConfigPath)) {
        $sample = Join-Path $Root "config\mykey.sample.json"
        throw @"
設定ファイルが見つかりません: $ConfigPath

対応:
1. config\mykey.sample.json を config\mykey.json にコピー
2. Google / Dify のキーを設定
3. mykey.json はGitにコミットしない

sample: $sample
"@
    }

    $raw = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
    $config = $raw | ConvertFrom-Json
    return [PSCustomObject]@{
        Path = $ConfigPath
        Value = $config
    }
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory=$true)]$Config,
        [string[]]$Names,
        $Default = $null
    )

    foreach ($name in $Names) {
        $current = $Config
        $ok = $true
        foreach ($part in ($name -split "\.")) {
            if ($null -eq $current.PSObject.Properties[$part]) {
                $ok = $false
                break
            }
            $current = $current.$part
        }
        if ($ok -and $null -ne $current -and "$current" -ne "") {
            return $current
        }
    }

    return $Default
}

function Invoke-AiStreamFunction {
    param(
        [Parameter(Mandatory=$true)][string[]]$Names,
        [hashtable]$Args = @{},
        [object[]]$FallbackPositionArgs = @(),
        [switch]$Optional
    )

    $cmd = $null
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { break }
    }

    if ($null -eq $cmd) {
        $msg = "関数が見つかりません。候補: $($Names -join ', ')"
        if ($Optional) {
            Write-Warning $msg
            return $null
        }
        throw $msg
    }

    $callArgs = @{}
    foreach ($key in $Args.Keys) {
        if ($cmd.Parameters.ContainsKey($key)) {
            $callArgs[$key] = $Args[$key]
        }
    }

    Write-Info "Call function: $($cmd.Name)"

    if ($callArgs.Count -gt 0) {
        return & $cmd @callArgs
    }

    if ($FallbackPositionArgs.Count -gt 0) {
        return & $cmd @FallbackPositionArgs
    }

    return & $cmd
}

# -----------------------------
# Boot
# -----------------------------
$Root = Resolve-AiStreamRoot -RootPath $RootPath
Write-Info "Root: $Root"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $Root "config\mykey.json"
}

# 既存モジュール内の固定パスフォールバックを避けるため、先に環境変数へ現在の場所を設定
$env:AI_SCRIPT_ROOT = $Root
$env:AI_CONFIG_PATH = $ConfigPath

Import-AiStreamModules -Root $Root

$configResult = Read-AiStreamConfig -Root $Root -ConfigPath $ConfigPath
$ConfigFile = $configResult.Path
$Config = $configResult.Value

$pollFromConfig = Get-ConfigValue -Config $Config -Names @("YouTube.PollSeconds", "PollSeconds") -Default $PollSeconds
if ($pollFromConfig -as [int]) {
    $PollSeconds = [int]$pollFromConfig
}

$maxReplyLength = [int](Get-ConfigValue -Config $Config -Names @("YouTube.MaxReplyLength", "MaxReplyLength") -Default 180)

Write-Info "Config: $ConfigFile"
Write-Info "PollSeconds: $PollSeconds"
Write-Info "MaxReplyLength: $maxReplyLength"

# トークン確認は毎ループではなく、起動時と一定間隔で行う
$lastTokenCheck = [datetime]::MinValue
$tokenCheckIntervalMinutes = 5

$accessToken = $null
$headers = $null
$seenMessageIds = @{}

while ($true) {
    try {
        $now = Get-Date

        if (($now - $lastTokenCheck).TotalMinutes -ge $tokenCheckIntervalMinutes -or [string]::IsNullOrWhiteSpace("$accessToken")) {
            if (-not (Get-Command Get-AuthHeaders -ErrorAction SilentlyContinue)) {
                throw "Get-AuthHeaders 関数が見つかりません。mod02.psm1 が正しく読み込まれているか確認してください。"
            }

            Write-Info "Call function: Get-AuthHeaders"
            $auth = Get-AuthHeaders
            $accessToken = $auth.access_token
            $headers = $auth.headers

            if ([string]::IsNullOrWhiteSpace("$accessToken")) {
                throw "access_token が取得できませんでした。config/youtube_tokens.json と refresh_token を確認してください。"
            }

            $lastTokenCheck = $now
        }

        $liveChatId = Invoke-AiStreamFunction `
            -Names @("Get-LiveChatId", "Get-ActiveLiveChatId", "Get-YouTubeLiveChatId", "Get-ActiveLiveBroadcastChatId", "Resolve-LiveChat") `
            -Args @{
                AccessToken = $accessToken
                Headers = $headers
                ConfigPath = $ConfigFile
                Config = $Config
            } `
            -Optional

        if ([string]::IsNullOrWhiteSpace("$liveChatId")) {
            Write-Info "配信中の liveChatId が見つかりません。待機します。"
            Start-Sleep -Seconds $PollSeconds
            continue
        }

        Write-Info "liveChatId: $liveChatId"

        $comments = Invoke-AiStreamFunction `
            -Names @("Get-LiveChatMessages", "Get-YouTubeLiveChatMessages", "Get-LiveChatComments", "Get-Comments") `
            -Args @{
                AccessToken = $accessToken
                Headers = $headers
                LiveChatId = $liveChatId
                ConfigPath = $ConfigFile
                Config = $Config
            } `
            -FallbackPositionArgs @($accessToken, $liveChatId) `
            -Optional

        if ($null -eq $comments) {
            Start-Sleep -Seconds $PollSeconds
            continue
        }

        foreach ($comment in @($comments)) {
            $messageId = $null
            $messageText = $null

            if ($comment -is [string]) {
                $messageText = $comment
                $messageId = [string]::Join("-", @($messageText.GetHashCode(), $now.ToString("yyyyMMddHHmmss")))
            } else {
                $messageId = $comment.id
                if ([string]::IsNullOrWhiteSpace("$messageId") -and $null -ne $comment.PSObject.Properties["messageId"]) { $messageId = $comment.messageId }
                if ([string]::IsNullOrWhiteSpace("$messageId") -and $null -ne $comment.PSObject.Properties["snippet"]) { $messageId = $comment.snippet.id }

                $messageText = $comment.text
                if ([string]::IsNullOrWhiteSpace("$messageText") -and $null -ne $comment.PSObject.Properties["message"]) { $messageText = $comment.message }
                if ([string]::IsNullOrWhiteSpace("$messageText") -and $null -ne $comment.PSObject.Properties["snippet"]) { $messageText = $comment.snippet.displayMessage }
                if ([string]::IsNullOrWhiteSpace("$messageText") -and $null -ne $comment.PSObject.Properties["snippet"]) { $messageText = $comment.snippet.textMessageDetails.messageText }
            }

            if ([string]::IsNullOrWhiteSpace("$messageText")) {
                continue
            }

            if (-not [string]::IsNullOrWhiteSpace("$messageId") -and $seenMessageIds.ContainsKey($messageId)) {
                continue
            }

            if (-not [string]::IsNullOrWhiteSpace("$messageId")) {
                $seenMessageIds[$messageId] = $true
            }

            Write-Info "Comment: $messageText"

            $difyAnswer = Invoke-AiStreamFunction `
                -Names @("Send-DifyMessage", "Invoke-Dify", "Send-Dify", "Ask-Dify", "Send-MessageToDify", "Invoke-DifyChat") `
                -Args @{
                    Query = $messageText
                    Text = $messageText
                    Message = $messageText
                    ConfigPath = $ConfigFile
                    Config = $Config
                } `
                -FallbackPositionArgs @($messageText, $ConfigFile)

            if ([string]::IsNullOrWhiteSpace("$difyAnswer")) {
                Write-Info "Dify answer is empty. skip."
                continue
            }

            $reply = $difyAnswer
            if (Get-Command ConvertTo-YouTubeSafeMessage -ErrorAction SilentlyContinue) {
                $reply = ConvertTo-YouTubeSafeMessage -Text "$difyAnswer" -MaxLength $maxReplyLength
            }

            if ([string]::IsNullOrWhiteSpace("$reply")) {
                continue
            }

            Write-Info "Reply: $reply"

            if ($DryRun) {
                Write-Info "DryRun: 投稿せずにスキップ"
                continue
            }

            Invoke-AiStreamFunction `
                -Names @("Post-LiveChatMessage", "Send-LiveChatMessage", "Post-YouTubeLiveChatMessage", "Send-YouTubeLiveChatMessage") `
                -Args @{
                    AccessToken = $accessToken
                    Headers = $headers
                    LiveChatId = $liveChatId
                    Message = $reply
                    Text = $reply
                    ConfigPath = $ConfigFile
                    Config = $Config
                } `
                -FallbackPositionArgs @($accessToken, $liveChatId, $reply)
        }
    }
    catch {
        Write-Warning "Loop error: $($_.Exception.Message)"
        # トークン系エラーの場合、次ループで再確認させる
        $lastTokenCheck = [datetime]::MinValue
    }

    Start-Sleep -Seconds $PollSeconds
}
