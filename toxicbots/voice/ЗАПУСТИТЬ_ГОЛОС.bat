@echo off
chcp 65001 >nul
cd /d "%~dp0"
title ToxicBots - голос

set PY=
where py >nul 2>nul && set PY=py -3
if not defined PY where python >nul 2>nul && set PY=python
if not defined PY (
  echo Не найден Python. Поставь Python 3.10+ с python.org ^(галочка "Add to PATH"^)
  echo или командой:  winget install Python.Python.3.12
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo Первый запуск: ставлю зависимости...
  %PY% -m venv .venv || (pause & exit /b 1)
  ".venv\Scripts\python.exe" -m pip install --upgrade pip >nul
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt || (pause & exit /b 1)
)

rem Параметры: --mode always (слушать всегда), --key v (другая клавиша), --big (точная модель)
".venv\Scripts\python.exe" toxic_voice.py %*
pause
