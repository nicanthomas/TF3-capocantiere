# Controllo grafico Windows: Steam e menu TF3 provati

## Stato verificato il 10.10.2026

Nuova autorizzazione esplicita al ciclo temporaneo delle opzioni Steam. Doppio backup privato del solo LaunchOptions, confronto/impronta verificati; campo svuotato tramite Steam, wrapper escluso. Nessuna chiave letta/usata, Taskkill, partita caricata, costruzione, installazione o modifica agente ai file gioco/mod/salvataggi. Due avvii normali, menu soltanto, uscita normale e processo assente verificato.
Opzioni originali RIPRISTINATE, confronto esatto dopo chiusura del dialogo. Il wrapper originale resta attivo e incompatibile con divieti chiave/Taskkill: non cliccare Gioca senza ripetere il ciclo temporaneo autorizzato. Procedura/recupero in ripristino-opzioni-steam.md.

TF3 build 40420: finestra SDL_app da eseguibile esatto E:\SteamLibrary\steamapps\common\Transport Fever 3\TransportFever3.exe; PrintWindow leggibile, focus verificato. Mouse apre pannello impostazioni senza cambiarne valori. Tab/Esc virtual-key scan=0 senza effetto visibile; Esc con KEYEVENTF_SCANCODE e scan 0x01 ritorna al menu (frame stabile ispezionato). Esci chiude direttamente senza conferma; Steam torna a Gioca dopo breve aggiornamento. Non usare Ferma. Screenshot durante chiusura puo' fallire per finestra gia' scomparsa. Non confondere successo SendInput con prova del comportamento UI.

## Strumento nel repository

dev-notes/strumenti/windows_pc.py usa solo stdlib e DLL Windows di sistema. Non avvia programmi e non carica configurazioni Steam, salvataggi, mod o credenziali. Comandi: list, screenshot BMP, focus, click con coordinate client, text stampabile e backspace. Nessun hotkey o Invio. Ogni uso effettivo resta soggetto alle autorizzazioni della sessione.

Da PowerShell, nel checkout:

```powershell
python -B dev-notes/strumenti/windows_pc.py list
python -B dev-notes/strumenti/windows_pc.py screenshot --hwnd <HWND> --pid <PID> --output <artefatto-nuovo.bmp>
python -B dev-notes/strumenti/windows_pc.py focus --hwnd <HWND> --pid <PID>
```

Sostituire i segnaposto con valori appena identificati, non copiare HWND/PID precedenti. Per TF3 aggiungere --target tf3 --tf3-exe con percorso assoluto verificato; senza tale percorso rifiuta finestre TF3.
Screenshot solo nella cartella artefatti autorizzata, mai nei dati del gioco o nel repository pubblico. Non sovrascrive file esistenti. Ispezionare prima degli input: Steam puo' mostrare frame incompleti durante ridisegno, ricatturare dopo stabilizzazione. Un successo API non dimostra un'immagine utilizzabile. Cattura del menu TF3 provata; durante transizioni attendere e ispezionare un frame stabile.

## Protezioni e limiti

Verifica HWND/PID/percorso/titolo/classe/rettangolo. Steam solo dalla directory specificata (steam.exe/steamwebhelper.exe); selezione ambigua rifiutata. Ricontrollo prima/dopo input, blocco su focus/geometria diversi o modificatori/pulsanti premuti. Clic verifica limiti client e finestra sotto il punto. Eccezioni esplicite anche con Python -O. Testi con controlli (Invio/Tab/Esc) rifiutati prima degli eventi.
SendInput globale mantiene race tra controllo e invio: niente input concorrente, nessuna garanzia di confinamento OS. Su invio incompleto fermarsi e verificare lo stato dei tasti, senza ulteriori eventi ad altre finestre. Coordinate da immagine/client attuali.

## Prove reali Steam

Nuovo helper: identificazione dinamica, screenshot ispezionato, focus, clic ricerca, testo zzcodexprobe visibile. Ripristino con 12 Backspace totali (prima 11, screenshot mostrava un residuo, poi rimosso), Pagina iniziale e ricerca vuota verificate visivamente. Nessun Gioca/installazione/acquisto/disinstallazione. Screenshot soltanto locali; TF3 assente. Quattordici regressioni controller su backend simulato, anche -O; intera suite isolata 64/64 OK. Non sono prove TF3. PostMessage ignorato da Steam nel probe precedente.

## Procedura TF3 con ciclo opzioni autorizzato

1. Ricontrollare processo assente e autorizzazioni; seguire ripristino-opzioni-steam.md per backup verificato e svuotamento temporaneo del campo. Senza recupero disponibile non cambiare opzioni o avviare.
2. Identificare Steam e Gioca da screenshot recente. Un solo clic, attesa limitata, nessun secondo tentativo se tarda. Verificare processo e percorso E:\SteamLibrary\steamapps\common\Transport Fever 3\transportfever3.exe.
3. Identificare finestra TF3 da eseguibile esatto, screenshot e focus. Solo menu e input innocui ispezionati; niente Carica/Continua/Nuova partita, Lua o costruzioni. Per tastiera fisica usare scancode; Esc torna dal pannello impostazioni al menu, non presumere effetto di Tab.
4. Tornare al menu e ispezionarlo; usare icona Esci con controlli target/focus. Chiusura diretta senza conferma osservata; verificare processo terminato e Gioca tornato in Steam. Ripristinare le opzioni originali e confrontare esattamente il valore con i backup.
5. Se non risponde, fermare input, documentare schermata/processi e passare a sorgenti/test. Nessun Taskkill, modifica impostazioni o intervento sui salvataggi.

## Rafforzamento dopo revisione

Clic CLI richiede --rect LEFT TOP RIGHT BOTTOM corrispondente al rettangolo dello screenshot recente (riportato nel JSON): se la finestra si e' mossa, catturare di nuovo prima di scegliere coordinate. Controlla anche posizione effettiva del puntatore prima del clic, per fermarsi su drift da input concorrente dentro la stessa finestra. Blocco include pulsanti laterali XBUTTON1/2, testati separatamente. Rimane la race SendInput documentata.
Riferimenti API: [ctypes Python](https://docs.python.org/3/library/ctypes.html), [gestione stati Lua](https://www.lua.org/manual/5.4/manual.html#lua_close).

Riferimento scancode: [Microsoft KEYBDINPUT](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-keybdinput). Con KEYEVENTF_SCANCODE il campo wScan identifica il tasto; wVk e' ignorato. L'effetto concreto sopra e' una prova locale TF3, non una promessa per ogni pannello o applicazione.
