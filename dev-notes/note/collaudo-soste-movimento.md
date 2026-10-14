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


CI38601254902 Ubuntu/Windows verde sul commit70 670c5c8; cinque file remoti
identici ai locali. Nuova build dev --bozza v14-bozza-db0a682b, sintassi Lua5.4
valida e DEV_MODE true una sola volta; release confrontata con Git e invariata.
SHA25629e34e4e506a12bd03472b99995dd5b4b01bdefefc6002c9e649a336574ab1b4.
Build NON installata/provata TF3. db0a682b sostituisce 0b20c9f6 come build sorgenti aggiornata.
