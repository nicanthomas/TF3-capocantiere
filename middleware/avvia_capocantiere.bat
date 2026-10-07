@echo off
rem Avvia la console di Capo Cantiere (doppio clic, oppure collegamento sul desktop con l'icona che preferisci).
rem La chiave API va impostata una volta con:  setx ANTHROPIC_API_KEY "..."
title Capo Cantiere
cd /d "%~dp0"
python verifica_installazione.py --no-pause
if errorlevel 1 (
    echo.
    echo Correggi i problemi indicati sopra e riprova.
    pause
    exit /b 1
)
echo.
python main.py
echo.
pause
