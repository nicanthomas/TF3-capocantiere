# Ricerca deposito navale presso tutte le città — 13.10.2026

PROVATO IN TF3, mod 0200b845 installata e ricaricata su copia iniziale `capocantiere test porto 12-10`. Prova build_air_or_water_line([62685,62691], kind=harbor, numero navi omesso): porti costruiti, gruppi117952/115920, poi fallimento `nessun deposito/hangar per i veicoli`. I tre candidati della prima città Lissone rifiutati (collisione o messaggio vuoto). Pulizia automatica di due porti, nessuna linea/nave creata. Risposta in prove-navale-13-10.json.

Il sorgente cerca il deposito solamente presso a.town_ids[1]. Test singolo, stessa mod e funzione CC.buildTemplateNear, ma seconda città Calliano62691: successo, costruzione103939/deposito118853. Acqua reale0; nessun ignoreErrors forzato. Deposito costruito, NON ancora prova percorso/servizio (porti della prova precedente rimossi). Questa costruzione successiva al test non è ancora salvata.

Difetto isolato: una prima città priva di spazio impedisce l'intera linea pur essendo disponibile una posa presso un'altra città della stessa linea. Correzione prevista: provare le città indicate in ordine fino al primo deposito creato; conservare le diagnosi e fermarsi dopo successo. Nessuna città aggiuntiva, nessuna costruzione in background. Quota acqua+2 resta necessaria e già corretta; non modificare la ricerca geometrica della costa per questo passo.

### Correzione e regressioni

Ricerca presso le città richieste in ordine, fino al primo successo; log di ogni fallimento, nessuna costruzione presso città aggiuntive. Tre regressioni: seconda città utile, primo successo interrompe, nessun successo non crea linea. Mock con API finta confinata nel runtime TF3: due nuovi fallimenti prima, zero dopo. Unico caso preesistente math.maxinteger non applicabile a Lua5.2 resta distinto. Nessuna costruzione reale dal mock. CI ordinaria e revisione ancora da completare; fix non installato.

### 13.10, 07:09 — ricerca deposito corretta e installata

CI38349547194 verde Ubuntu/Windows; locale134test,0fallimenti/0errori, classeLua saltata,17.037s.
Revisione senza regressioni concrete; percorso deposito nuovo/porti ancora da verificare realmente.
Fix unito main7fe129b; --dev --bozza v14-bozza-4e8640b2 generata, installata a gioco/console chiusi
con backup e SHA256 uguali. TF3 riavviato. Nuovo save 'capocantiere deposito Calliano 13-10'
verificato07:06:53 (.sav71049690byte/.jpg583579). Copia iniziale porto preservata per nuova prova.
Nessuna linea/nave conclusa ancora; correzione sorgenti e installazione non equivalgono a collaudo completo.
