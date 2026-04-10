@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0start-openwebui.ps1" %*
