# Opzioni TF3: collaudo temporaneo e ripristino

10.10.2026: autorizzazione esplicita della sessione a salvare le opzioni originali, disattivare temporaneamente il wrapper nel campo Steam, collaudare il solo menu e ripristinare. Non e' un permesso permanente a cambiare impostazioni del PC.

Configurazione osservata: wrapper avvia_con_gioco.bat seguito da %command%, percorso privato non pubblicato. La precedente lettura del wrapper aveva rilevato console Anthropic e taskkill: non si esegue questa catena durante il collaudo. File originali intatti.

Backup: due JSON privati nell'area work della chat, directory steam-launch-options-session2; solo app ID, posizione della configurazione, valore LaunchOptions e SHA256 del valore. Copie rilette e identiche; confronto con il valore attuale riuscito. Non copiare o pubblicare l'intero localconfig.vdf, screenshot del campo o identificativi del profilo.

Modifica attraverso il dialogo proprieta' Steam dell'app 3493540, non scrittura del file VDF mentre Steam e' attivo. Verificare processo/percorso/titolo/geometria e focus prima degli input. Il dialogo si intitola Transport Fever 3 ma appartiene a steamwebhelper.exe: non confonderlo con il gioco.

Sequenza: svuotare soltanto Opzioni di avvio; chiudere il dialogo; controllare vuoto con lettura selettiva; avviare via Steam una volta; menu soltanto; uscita dal menu e verifica termine processo; riaprire proprieta', inserire il valore launch_options del backup senza stamparlo; chiudere; confronto esatto con entrambe le copie e impronta. Niente caricamenti, bridge, chiavi o Taskkill.

Recupero manuale anche se la chat termina: aprire original.json localmente, riportare solo launch_options nel campo Steam di TF3. Non importare gli altri campi nel client e non sostituire l'intera configurazione. Conservare entrambi i backup. Prima del collaudo verificare che esistano e che il dialogo sia controllabile; se il recupero non e' disponibile, non cambiare le opzioni.

Esito: due cicli TF3 nel solo menu completati; uscita normale e processo terminato. Valore originale RIPRISTINATO esattamente, confrontato dopo la chiusura delle proprieta'; due copie e impronta integre. Nessuna modifica al file wrapper. I dialoghi ricreati hanno HWND diverso: identificarli di nuovo, non riusare handle. Guardie hanno rifiutato il vecchio handle senza input. Conservare i backup privati; wrapper originale nuovamente attivo.
