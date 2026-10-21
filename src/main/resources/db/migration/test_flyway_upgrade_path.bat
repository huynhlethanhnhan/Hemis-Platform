@echo off
rem Runner kiem thu duong dan nang cap Flyway V1 -> V2 -> V3 voi du lieu mau
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_flyway_upgrade_path.ps1"
exit /b %ERRORLEVEL%
