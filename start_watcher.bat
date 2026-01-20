@echo off
echo ============================================================
echo Voice Transcription Watcher
echo ============================================================
echo.

cd /d D:\VoiceDropbox

REM Check if venv exists, create if not
if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
    call venv\Scripts\activate.bat
    echo Installing dependencies...
    pip install -r requirements.txt
) else (
    call venv\Scripts\activate.bat
)

echo.
echo Starting watcher service...
echo Press Ctrl+C to stop.
echo.

python voice_watcher.py

pause
