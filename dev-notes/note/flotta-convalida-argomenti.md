# Convalida argomenti flotta, 10.10.2026

Passo circoscritto STATO4b, soltanto sorgenti e fixture: middleware/tools_bozza.py dichiara interval 60..3600 secondi e max intero 1..20. b2_rete.lua usa CC.need per i tipi, ma non applica questi limiti prima di leggere la linea. Intervallo zero entra nella divisione rtt/interval; valori fuori schema possono produrre proposte inattese nelle chiamate dirette. Si tratta per ora di analisi statica, da riprodurre con test.

Piano: aggiungere regressioni native Lua e mock che rifiutino valori fuori schema/non finiti prima di CC.lineVehicles e senza comandi, per apply falso e vero; controllare che estremi validi e argomenti omessi restino accettati. Pubblicare RED nella branch di lavoro, controllare l'errore reale CI, poi aggiungere due guardie locali subito dopo CC.need, senza cambiare calcolo/default o schema middleware. GREEN locale isolato/CI/revisione prima del merge.

Nessun avvio, partita, bridge reale, rigenerazione/installazione mod o dipendenza. I test apply=true chiamano soltanto fixture con lettura intercettata prima di qualsiasi possibile comando; non operano sul gioco.
