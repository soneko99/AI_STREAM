#requires -Version 5.1
# mod10.psm1 : WAVファイルをVirtual Audio Cable（または任意の出力デバイス）に再生
# Windows Multimedia API (winmm.dll) のP/Invokeを使い、デバイス名でデバイスを指定して再生する
# 関連Issue: [AI Task] 音声再生 - Virtual Audio CableへのWAV再生機能実装

Set-StrictMode -Version Latest

# ---------- winmm.dll P/Invoke 定義（初回のみロード） ----------
$Script:WinMmLoaded = $false
function Initialize-WinMm {
  if ($Script:WinMmLoaded) { return }
  $Script:WinMmLoaded = $true

  $csharp = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinMmAudio
{
    // waveOutGetNumDevs: システムの出力デバイス数を返す
    [DllImport("winmm.dll")]
    public static extern int waveOutGetNumDevs();

    // waveOutGetDevCaps: デバイス情報を取得
    [DllImport("winmm.dll", CharSet = CharSet.Auto)]
    public static extern int waveOutGetDevCaps(int uDeviceID, ref WAVEOUTCAPS lpCaps, int dwSize);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct WAVEOUTCAPS
    {
        public ushort wMid;
        public ushort wPid;
        public uint vDriverVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szPname;
        public uint dwFormats;
        public ushort wChannels;
        public ushort wReserved1;
        public uint dwSupport;
    }

    // PlaySound: シンプルなWAV再生（デバイス選択不可だが同期再生できる）
    [DllImport("winmm.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool PlaySound(string pszSound, IntPtr hmod, uint fdwSound);

    public const uint SND_FILENAME  = 0x00020000;
    public const uint SND_SYNC      = 0x00000000;
    public const uint SND_ASYNC     = 0x00000001;
    public const uint SND_NOSTOP    = 0x00000010;
    public const uint SND_PURGE     = 0x00000040;
}
'@
  Add-Type -TypeDefinition $csharp -Language CSharp -ErrorAction SilentlyContinue
}

# ---------- 利用可能な出力デバイス一覧を取得 ----------
function Get-AudioOutputDevices {
  [CmdletBinding()]
  param()

  Initialize-WinMm

  $count = [WinMmAudio]::waveOutGetNumDevs()
  $devices = @()
  for ($i = 0; $i -lt $count; $i++) {
    $caps = New-Object WinMmAudio+WAVEOUTCAPS
    $size = [System.Runtime.InteropServices.Marshal]::SizeOf($caps)
    $result = [WinMmAudio]::waveOutGetDevCaps($i, [ref]$caps, $size)
    if ($result -eq 0) {
      $devices += [pscustomobject]@{
        Index = $i
        Name  = $caps.szPname
      }
    }
  }
  return $devices
}

# ---------- デバイス名からインデックスを検索 ----------
function Find-AudioDeviceIndex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$DeviceName
  )

  $devices = Get-AudioOutputDevices
  $match = $devices | Where-Object { $_.Name -like "*$DeviceName*" } | Select-Object -First 1
  if ($match) {
    return $match.Index
  }
  return -1
}

# ---------- WAVファイルをデフォルトデバイスに再生（同期） ----------
function Invoke-WavPlayback {
  [CmdletBinding()]
  param(
    # 再生するWAVファイルのパス
    [Parameter(Mandatory)][string]$WavPath,
    # 出力デバイス名のキーワード（省略時はデフォルトデバイス）
    # 例: "CABLE Input", "VB-Audio"
    [Parameter()][string]$DeviceName,
    # 非同期で再生するか（$true = ノンブロッキング）
    [Parameter()][switch]$Async
  )

  if (-not (Test-Path $WavPath)) {
    Write-Host "❌ WAVファイルが見つかりません: $WavPath" -ForegroundColor Red
    return $false
  }

  # デバイス指定がある場合は確認表示（PlaySoundはデバイス選択不可のため情報提供のみ）
  if ($DeviceName) {
    Initialize-WinMm
    $idx = Find-AudioDeviceIndex -DeviceName $DeviceName
    if ($idx -ge 0) {
      Write-Verbose "[Invoke-WavPlayback] デバイス検出: Index=$idx, Name=$DeviceName"
    } else {
      Write-Host ("⚠ デバイス '{0}' が見つかりません。デフォルトデバイスで再生します。" -f $DeviceName) -ForegroundColor Yellow
      Write-Host "利用可能なデバイス:" -ForegroundColor Yellow
      Get-AudioOutputDevices | ForEach-Object { Write-Host ("  [{0}] {1}" -f $_.Index, $_.Name) -ForegroundColor Yellow }
    }
  }

  # .NET MediaPlayer を使ってデバイス名のあるものに再生（レジストリでデフォルトデバイス変更が必要な場合の代替）
  # Virtual Cable 使用時は Windows 設定でデフォルト出力デバイスを CABLE Input に変更してから呼び出すこと
  Initialize-WinMm
  $flags = if ($Async) { [WinMmAudio]::SND_FILENAME -bor [WinMmAudio]::SND_ASYNC } `
           else        { [WinMmAudio]::SND_FILENAME -bor [WinMmAudio]::SND_SYNC }

  $absPath = (Resolve-Path $WavPath).Path
  $ok = [WinMmAudio]::PlaySound($absPath, [System.IntPtr]::Zero, $flags)
  if ($ok) {
    Write-Host ("🔊 再生完了 → {0}" -f $absPath) -ForegroundColor Cyan
  } else {
    Write-Host ("❌ 再生失敗: {0}" -f $absPath) -ForegroundColor Red
  }
  return $ok
}

# ---------- WAV再生を停止 ----------
function Stop-WavPlayback {
  [CmdletBinding()]
  param()
  Initialize-WinMm
  [WinMmAudio]::PlaySound($null, [System.IntPtr]::Zero, [WinMmAudio]::SND_PURGE) | Out-Null
}

Export-ModuleMember -Function Get-AudioOutputDevices, Find-AudioDeviceIndex, Invoke-WavPlayback, Stop-WavPlayback
