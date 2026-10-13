# Ricerca deposito navale presso tutte le città — 13.10.2026

PROVATO IN TF3, mod 0200b845 installata e ricaricata su copia iniziale `capocantiere test porto 12-10`. Prova build_air_or_water_line([62685,62691], kind=harbor, numero navi omesso): porti costruiti, gruppi117952/115920, poi fallimento `nessun deposito/hangar per i veicoli`. I tre candidati della prima città Lissone rifiutati (collisione o messaggio vuoto). Pulizia automatica di due porti, nessuna linea/nave creata. Risposta in prove-navale-13-10.json.

Il sorgente cerca il deposito solamente presso a.town_ids[1]. Test singolo, stessa mod e funzione CC.buildTemplateNear, ma seconda città Calliano62691: successo, costruzione103939/deposito118853. Acqua reale0; nessun ignoreErrors forzato. Deposito costruito, NON ancora prova percorso/servizio (porti della prova precedente rimossi). Questa costruzione successiva al test non è ancora salvata.

Difetto isolato: una prima città priva di spazio impedisce l'intera linea pur essendo disponibile una posa presso un'altra città della stessa linea. Correzione prevista: provare le città indicate in ordine fino al primo deposito creato; conservare le diagnosi e fermarsi dopo successo. Nessuna città aggiuntiva, nessuna costruzione in background. Quota acqua+2 resta necessaria e già corretta; non modificare la ricerca geometrica della costa per questo passo.
