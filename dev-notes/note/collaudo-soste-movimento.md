# Collaudo: sosta prevista non prova movimento

14.10.2026, ChatGPT — SOLO TEST AUTOMATICI Lua5.4, nessuna prova nuova TF3.

Il ramo precedente incrementava vehicles_moving anche se due posizioni erano
identiche, purche' lo stato fosse AT_TERMINAL o IN_DEPOT. Riprodotto sul codice
reale: un veicolo fermo al terminale veniva certificato in movimento.

Fix b8: con due campioni e tempo avanzato, spostamento>=2m conta moving.
Sotto soglia: AT_TERMINAL/IN_DEPOT conta nel nuovo vehicles_waiting, altri
stati restano vehicles_still (problema). Senza dati/tempo valido resta unknown.
Soglia, motivi unknown e persistenza campioni invariati. Stato nel deposito
continua a dare «tutti i veicoli sono ancora nel deposito». Una sosta prevista
non e' un blocco in viaggio; ok=true non dimostra da solo traffico o movimento.

I conteggi moving/still/waiting/unknown sono disgiunti. Un arrivo al terminale
con spostamento misurato resta moving: la misura descrive l'intervallo, non la
velocita' istantanea. Il nuovo campo e' descritto in check_line del middleware.
Quattro regressioni prima rosse, dopo verdi: terminale/deposito fermi, viaggio
bloccato, spostamento all'arrivo, primo campione/tempo fermo sconosciuti.
Suite locale183test/1skipWindows e mock150 verdi; revisione senza blocchi.

NON cambia il servizio navale o ferroviario, non certifica il trasporto di
passeggeri/merci; mod release e installazione PC restano invariate. Per provare
in TF3 servono build bozza aggiornata, copie di test e autorizzazioni della chat.
