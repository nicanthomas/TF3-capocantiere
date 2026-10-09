@echo off
rem Avvia la console di Capo Cantiere INSIEME a Transport Fever 3 e la chiude quando il gioco si chiude.
rem
rem Installazione (una volta sola): Steam -> Libreria -> Transport Fever 3 -> Proprieta' -> Generali ->
rem Opzioni di avvio, scrivere (con il percorso vero di questa cartella, tra virgolette):
rem     "C:\percorso\TF3-capocantiere\middleware\avvia_con_gioco.bat" %command%
rem
rem La console si apre in una finestra a parte e aspetta: si attiva da sola quando carichi una partita con la mod
rem Capo Cantiere attiva (nel menu o in una mappa senza la mod resta in attesa e non chiama Claude).

rem 1) console in una finestra separata (titolo "Capo Cantiere", usato per chiuderla alla fine)
start "Capo Cantiere" /d "%~dp0" cmd /c avvia_capocantiere.bat

rem 2) il gioco, con il comando che passa Steam
%*

rem 3) se il gioco e' stato avviato da un altro processo, aspetto che transportfever3.exe sia chiuso
:attesa
timeout /t 5 /nobreak >nul
tasklist /fi "imagename eq transportfever3.exe" 2>nul | find /i "transportfever3.exe" >nul
if not errorlevel 1 goto attesa

rem 4) gioco chiuso: chiudo la console
taskkill /fi "WINDOWTITLE eq Capo Cantiere*" /t /f >nul 2>&1
exit /b 0
