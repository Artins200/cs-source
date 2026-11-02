@echo off
chcp 65001 >nul
cd /d "%~dp0"
title ToxicBots - установка
set "TB=%LOCALAPPDATA%\ToxicBots"
set "VPY=%TB%\venv\Scripts\python.exe"

set PY=
where py >nul 2>nul && set PY=py -3
if not defined PY where python >nul 2>nul && set PY=python
if not defined PY (
  echo Не найден Python. Поставь Python 3.10-3.13 с python.org ^(галочка "Add to PATH"^)
  echo или командой:  winget install Python.Python.3.12
  pause
  exit /b 1
)

if not exist "%VPY%" (
  echo Создаю окружение в %TB%\venv ...
  if not exist "%TB%" mkdir "%TB%"
  %PY% -m venv "%TB%\venv"
  if errorlevel 1 ( echo Не получилось создать venv & pause & exit /b 1 )
)

echo Ставлю микрофон/распознавание: vosk sounddevice pynput numpy
"%VPY%" -m pip install --upgrade pip
"%VPY%" -m pip install -r requirements.txt
if errorlevel 1 ( echo ОШИБКА установки, смотри текст выше & pause & exit /b 1 )

echo Ставлю озвучку ботов: piper-tts
"%VPY%" -m pip install -r requirements-tts.txt
if errorlevel 1 echo [!] Озвучка не встала ^(часто из-за Python 3.14 - поставь 3.12^). Микрофон всё равно будет работать.

echo.
echo Готово. Теперь запускай ЗАПУСТИТЬ_ГОЛОС.bat
if not "%~1"=="nopause" pause
