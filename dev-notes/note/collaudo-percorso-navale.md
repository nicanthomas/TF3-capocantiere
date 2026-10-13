# Collaudo navale: percorso nativo — 13.10.2026

Causa PROVATA IN TF3 su linea119497: findPathNodeToNode restituisce un percorso con modo12,
ma getDetailedLineProblems segnala noPath=true a entrambe le fermate. La nave non e' assegnabile.
CC.checkLine ignorava la verifica nativa e non riportava percorso mancante.

Fix limitato alle linee con modi SHIP/SMALL_SHIP (12/13): aggiunge noPath nativo alla condizione
di percorso mancante. API protetta; se non leggibile rimane controllo generico. Terra invariata.
Usa solo flags noPath veri, non interpreta reason Unknown e non ignora errori della costruzione.
Struttura {{StopState}} coerente con SDK util.d.tl e GUIufficiale manager_window.tl:5993.

Quattro mock: native mancante con generic true, native valido, terra invariata, errore API protetto.
RED CI38433730920: unica nuova regressione fallisce; Windows verde. Messaggio regressione
intenzionale appartiene al test del runner. Mock confinato nel gioco prima/dopo: nuova regressione
fallisce poi passa. Persistente mock math.maxinteger inapplicabile TF3Lua5.2, non test verde completo.
CI/revisione GREEN in corso. Codice non installato, collaudo reale aggiornato non eseguito.
NON risolve la geometria dei porti, l'assegnazione, i bacini o il servizio navale; segnala il problema reale.
