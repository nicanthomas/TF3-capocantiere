# Controllo grafico Windows: Steam provato, TF3 bloccato

## Stato verificato il 10.10.2026

Avvio/chiusura TF3 e input nel solo menu sono autorizzati nella sessione corrente. Nessun caricamento o modifica di partite, mod o file del gioco; nessuna chiave Anthropic, installazione o chiusura forzata.
Le opzioni Steam, lette senza modificarle, richiamano avvia_con_gioco.bat con %command%. Il wrapper installato apre la console che legge la chiave Anthropic e alla fine usa taskkill /t /f. Avvio NON eseguito; processo TF3 assente. Non cambiare opzioni o file installati senza autorizzazione distinta.

## Strumento nel repository

dev-notes/strumenti/windows_pc.py usa solo stdlib e DLL Windows di sistema. Non avvia programmi e non carica configurazioni Steam, salvataggi, mod o credenziali. Comandi: list, screenshot BMP, focus, click con coordinate client, text stampabile e backspace. Nessun hotkey o Invio. Ogni uso effettivo resta soggetto alle autorizzazioni della sessione.

Da PowerShell, nel checkout:

```powershell
python -B dev-notes/strumenti/windows_pc.py list
python -B dev-notes/strumenti/windows_pc.py screenshot --hwnd <HWND> --pid <PID> --output <artefatto-nuovo.bmp>
python -B dev-notes/strumenti/windows_pc.py focus --hwnd <HWND> --pid <PID>
```

Sostituire i segnaposto con valori appena identificati, non copiare HWND/PID precedenti. Per TF3 aggiungere --target tf3 --tf3-exe con percorso assoluto verificato; senza tale percorso rifiuta finestre TF3.
Screenshot solo nella cartella artefatti autorizzata, mai nei dati del gioco o nel repository pubblico. Non sovrascrive file esistenti. Ispezionare prima degli input: Steam puo' mostrare frame incompleti durante ridisegno, ricatturare dopo stabilizzazione. Un successo API non dimostra un'immagine utilizzabile. Cattura TF3 non ancora provata.

## Protezioni e limiti

Verifica HWND/PID/percorso/titolo/classe/rettangolo. Steam solo dalla directory specificata (steam.exe/steamwebhelper.exe); selezione ambigua rifiutata. Ricontrollo prima/dopo input, blocco su focus/geometria diversi o modificatori/pulsanti premuti. Clic verifica limiti client e finestra sotto il punto. Eccezioni esplicite anche con Python -O. Testi con controlli (Invio/Tab/Esc) rifiutati prima degli eventi.
SendInput globale mantiene race tra controllo e invio: niente input concorrente, nessuna garanzia di confinamento OS. Su invio incompleto fermarsi e verificare lo stato dei tasti, senza ulteriori eventi ad altre finestre. Coordinate da immagine/client attuali.

## Prove reali Steam

Nuovo helper: identificazione dinamica, screenshot ispezionato, focus, clic ricerca, testo zzcodexprobe visibile. Ripristino con 12 Backspace totali (prima 11, screenshot mostrava un residuo, poi rimosso), Pagina iniziale e ricerca vuota verificate visivamente. Nessun Gioca/installazione/acquisto/disinstallazione. Screenshot soltanto locali; TF3 assente. Quattordici regressioni controller su backend simulato, anche -O; intera suite isolata 64/64 OK. Non sono prove TF3. PostMessage ignorato da Steam nel probe precedente.

## Procedura TF3 dopo risoluzione autorizzata del blocco

1. Ricontrollare opzioni/wrapper in sola lettura, processo assente e autorizzazioni applicabili. Procedere soltanto con avvio che rispetti divieti chiave/Taskkill; altrimenti continuare nel repository.
2. Identificare Steam e Gioca da screenshot recente. Un solo clic, attesa limitata, nessun secondo tentativo se tarda. Verificare processo e percorso E:\SteamLibrary\steamapps\common\Transport Fever 3\transportfever3.exe.
3. Identificare finestra TF3 da eseguibile esatto, screenshot e focus. Solo menu principale e input innocui ispezionati; niente Carica/Continua, Lua o costruzioni.
4. Usare Esci dalla schermata corrente con controlli target/focus; verificare processo terminato e Gioca tornato in Steam. Verificare separatamente eventuale console, senza chiavi o chiusure forzate.
5. Se non risponde, fermare input, documentare schermata/processi e passare a sorgenti/test. Nessun Taskkill, modifica impostazioni o intervento sui salvataggi.

## Rafforzamento dopo revisione

Clic CLI richiede --rect LEFT TOP RIGHT BOTTOM corrispondente al rettangolo dello screenshot recente (riportato nel JSON): se la finestra si e' mossa, catturare di nuovo prima di scegliere coordinate. Controlla anche posizione effettiva del puntatore prima del clic, per fermarsi su drift da input concorrente dentro la stessa finestra. Blocco include pulsanti laterali XBUTTON1/2, testati separatamente. Rimane la race SendInput documentata.
Riferimenti API: [ctypes Python](https://docs.python.org/3/library/ctypes.html), [gestione stati Lua](https://www.lua.org/manual/5.4/manual.html#lua_close).
