function ConvertTo-YouTubeSafeMessage {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Text,

        [int]$MaxLength = 180
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    # 改行・連続空白をYouTubeチャット向けに整形
    $message = $Text -replace "`r`n", " "
    $message = $message -replace "`n", " "
    $message = $message -replace "`r", " "
    $message = $message -replace "\s+", " "
    $message = $message.Trim()

    if ($message.Length -gt $MaxLength) {
        $safeLength = [Math]::Max(1, $MaxLength - 1)
        $message = $message.Substring(0, $safeLength) + "…"
    }

    return $message
}

Export-ModuleMember -Function ConvertTo-YouTubeSafeMessage
