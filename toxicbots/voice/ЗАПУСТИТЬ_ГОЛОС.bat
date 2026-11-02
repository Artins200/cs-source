@echo off
chcp 65001 >nul
cd /d "%~dp0"
title ToxicBots - голос
set "VPY=%LOCALAPPDATA%\ToxicBots\venv\Scripts\python.exe"

rem проверяем, что всё установлено; если нет - ставим
if not exist "%VPY%" goto install
"%VPY%" -c "import vosk, sounddevice, pynput, numpy" >nul 2>nul || goto install
goto run

:install
echo Не хватает пакетов - запускаю установку...
call "УСТАНОВИТЬ_ЗАВИСИМОСТИ.bat" nopause
if not exist "%VPY%" ( pause & exit /b 1 )

:run
rem Параметры: --demo, --no-mic, --no-tts, --mode always, --key v, --voices dmitri,ruslan, --big
"%VPY%" toxic_voice.py %*
pause
