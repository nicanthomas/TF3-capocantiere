# Collaudo navale: percorso nativo — 13.10.2026

Causa PROVATA IN TF3 su linea119497: findPathNodeToNode restituisce un percorso con modo12,
ma getDetailedLineProblems segnala noPath=true a entrambe le fermate. La nave non e' assegnabile.
CC.checkLine ignorava la verifica nativa e non riportava percorso mancante.

Fix limitato alle linee con modi SHIP/SMALL_SHIP (enum ufficiale, verificato nel gioco: SHIP10/SMALL_SHIP12): aggiunge noPath nativo alla condizione
di percorso mancante. API protetta; se non leggibile rimane controllo generico. Terra invariata.
Usa solo flags noPath veri, non interpreta reason Unknown e non ignora errori della costruzione.
Struttura {{StopState}} coerente con SDK util.d.tl e GUIufficiale manager_window.tl:5993.

Quattro mock: native mancante con generic true, native valido, terra invariata, errore API protetto.
RED CI38433730920: unica nuova regressione fallisce; Windows verde. Messaggio regressione
intenzionale appartiene al test del runner. Mock confinato nel gioco prima/dopo: nuova regressione
fallisce poi passa. Persistente mock math.maxinteger inapplicabile TF3Lua5.2, non test verde completo.
CI38434059558 verde: Ubuntu148test/1skip, mock121ok/0falliti, Windowsverde.
Locale134test senza errori/fallimenti, classeLua saltata17.187s. Revisione senza blocchi.
Unito main207073e. Codice non installato, collaudo reale aggiornato non eseguito.
NON risolve la geometria dei porti, l'assegnazione, i bacini o il servizio navale; segnala il problema reale.

## Installazione e collaudo reali

PROVATO SUL PC: generata/installata v14-bozza-5f189de4 con TF3/console chiusi, backup/hash verificati.
PROVATO IN TF3: ricaricata copia nave fallita13-10; check_line della mod installata restituisce
ok=false e 'nessun percorso' per entrambe le direzioni, insieme a veicoli0 e bacino insufficiente.
Nessuna costruzione o nuova assegnazione. Sonda enum reale: SHIP=10, SMALL_SHIP=12;
13 NON e' il modo grande nave. I confronti per enum nella mod sono corretti; fixture/fallback
da allineare ai numeri reali, senza attribuire al modo13 un significato non provato.
Coordinate porti lette senza modifiche: construction120807(-5598.69,-5142.69,2),
construction117036(-7461.07,-1677.55,2). Nodo terminale indice44, entita'network distinta;
nessun edge geometrico navale leggibile su quel componente, non prova di assenza di acqua.
