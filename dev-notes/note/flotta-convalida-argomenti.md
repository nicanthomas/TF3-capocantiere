# Convalida argomenti flotta, 10.10.2026

Passo circoscritto STATO4b, soltanto sorgenti e fixture: middleware/tools_bozza.py dichiara interval 60..3600 secondi e max intero 1..20. b2_rete.lua usa CC.need per i tipi, ma non applica questi limiti prima di leggere la linea. Intervallo zero entra nella divisione rtt/interval; valori fuori schema possono produrre proposte inattese nelle chiamate dirette. Si tratta per ora di analisi statica, da riprodurre con test.

Piano: aggiungere regressioni native Lua e mock che rifiutino valori fuori schema/non finiti prima di CC.lineVehicles e senza comandi, per apply falso e vero; controllare che estremi validi e argomenti omessi restino accettati. Pubblicare RED nella branch di lavoro, controllare l'errore reale CI, poi aggiungere due guardie locali subito dopo CC.need, senza cambiare calcolo/default o schema middleware. GREEN locale isolato/CI/revisione prima del merge.

Nessun avvio, partita, bridge reale, rigenerazione/installazione mod o dipendenza. I test apply=true chiamano soltanto fixture con lettura intercettata prima di qualsiasi possibile comando; non operano sul gioco.

## Riproduzione e correzione

RED CI 38049622568: Ubuntu 91 test, 2 errori (interval e max non rifiutati prima della lettura), 1 skip Windows; due controlli mock nuovi falliti, estremi/default gia' validi. Windows 80 OK/classe Lua skip; locale 80 OK/1 classe Lua skip in 15,744 s. Le guardie sono state aggiunte soltanto dopo questa prova, immediatamente dopo CC.need e prima di ComponentType/lineVehicles. Errori fissi indicano il campo e il limite senza convertire valori non finiti o esporre informazioni del mondo. CC.need conserva il controllo intero di max. Default/calcolo e schema Python invariati. GREEN/revisione ancora da verificare.

## Esito e limite della garanzia

GREEN CI 38049721158: Ubuntu 91 test/1 skip Windows, 13,961 s; Windows 80/1 classe Lua skip, 14,530 s; mock normale 87 ok/0 falliti. Locale isolato 80 OK/classe Lua skip, 15,780 s. Revisione indipendente senza blocchi.

La garanzia riguarda la lettura della linea (CC.lineVehicles) e l'assenza di comandi, non zero letture API complessive: il wrapper b9 preesistente puo' chiamare CC.gameSpeed anche dopo il rifiuto. I test intercettano lineVehicles e W.sent. Nessuna estensione del passo al wrapper, nessuna prova in TF3. Lo schema Python e il calcolo per input validi rimangono invariati.
