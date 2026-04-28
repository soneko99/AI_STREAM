@echo off
setlocal

REM AI_STREAM 起動用
REM この bat が置かれているフォルダをプロジェクトルートとして main.ps1 を実行します。

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0main.ps1"

pause
