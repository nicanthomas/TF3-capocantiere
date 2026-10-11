# Indicatori produttivita' industrie — 11.10.2026

Passo sorgenti STATO4c/5b, autorizzazione a proseguire lo sviluppo sicuro. Fonte statica gia' documentata in qualita-merci-tipi-tf3.md: IndustryProductivityInfo dichiara producing, boostFromRule, boostFromPersonCapacity boolean; industry.getIndustryProductivityInfo(industryEntity) prende un solo entity. Non e' una prova del comportamento del userdata C++.

Design: CC.normalizeIndustryProductivity(value) crea una tabella nuova con available/errors e soltanto i tre booleani letti esplicitamente tramite pcall. Nessuna enumerazione, clone, metatable esportato, tostring del dato o eccezione raw. false e' valido e copiato; nil/tipo inatteso/accessor guasto segnala campo non disponibile, conservando gli altri. available true solo quando tutti e tre i campi sono booleani.

CC.industryProductivity(industry_id) chiama soltanto l'API dichiarata, una volta con un argomento. API assente/guasta produce available=false/error fisso senza dettagli raw. read_map aggiunge productivity a ogni industria con posizione presente nel risultato; errori non cambiano ok, id/nome/coordinate/inputs/outputs, griglia o linee. Industrie senza posizione non generano chiamate aggiuntive. Nessun comando o giudizio automatico sulla produzione.

Prima del codice: regressioni mock e userdata Lua sintetico in CI RED; poi implementazione minima b8 e GREEN locale isolato/CI/revisione prima del merge main. Fixture verificano false/nil/tipi errati/accesso guasto/pairs-tostring vietati, firma API, errore senza leak, mappa con API buona/assente/guasta e nessun comando. Il userdata sintetico non prova C++ TF3.

Unico checkout, nessuna installazione o lettura di chiavi/salvataggi, nessun avvio gioco/bridge reale o rigenerazione/installazione mod. DLL Lua locale fidata assente: classe nativa Windows resta skip, prova nativa in CI Ubuntu. build DIVERSO resta aperto.

## RED e implementazione minima

RED nativo CI 38134377278 prima del codice: normalizzatore mancante nel mock e regressione userdata in errore; Ubuntu 94 test/1 errore/1 skip Windows, 14,106 s. Windows verde con classe Lua skip. Solo dopo questa prova aggiunte le due funzioni b8 e il campo productivity in read_map. Riutilizzato il reader privato pcall per campi espliciti, nessuna nuova dipendenza o comando. GREEN e revisione in attesa.

## Esito

GREEN CI 38134484171: Ubuntu 94 test/1 skip Windows, 14,433 s; Windows 80/1 classe Lua skip, 14,334 s; mock normale 104 ok/0 falliti. Locale isolato 80 OK/1 classe Lua skip, 15,956 s. Revisione indipendente senza blocchi, integrazione dopo confronto main remoto. Nuovi casi: dodici mock e un userdata Lua sintetico con tre soli accessi/metatable ripristinato prima degli assert.

Output read_map.industries[].productivity: available, errors e booleani dichiarati leggibili. available falso non implica producing falso o assenza di boost; i campi non leggibili sono omessi, diagnostiche esplicite. Nessun nuovo tool/conferma, politica o comando nel gioco. Campo ancora bozza: installazione/runtimes C++/semantica dei boost non verificati. build DIVERSO rimane avviso, mod non rigenerata/installata.
