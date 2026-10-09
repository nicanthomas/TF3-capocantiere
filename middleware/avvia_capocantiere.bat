@echo off
rem Avvia la console di Capo Cantiere (doppio clic, oppure collegamento sul desktop con l'icona che preferisci).
rem La chiave API va impostata una volta con:  setx ANTHROPIC_API_KEY "..."
title Capo Cantiere
cd /d "%~dp0"
rem Se la mod installata accanto (cartella dati di TF3) e' una versione "bozza" (v14), attiva le azioni nuove della console
if not defined CAPOCANTIERE_BOZZA findstr /c:"-bozza-" "%~dp0..\..\mods\tfcapocantiere_1\content\capocantiere\capocantiere.script.lua" >nul 2>&1 && set CAPOCANTIERE_BOZZA=1
if "%CAPOCANTIERE_BOZZA%"=="1" echo Azioni v14 (bozza) attive.
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
