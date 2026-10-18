@echo off
cd /d "%~dp0"
python start_receiver_https.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Press any key to exit...
    pause > nul
)
