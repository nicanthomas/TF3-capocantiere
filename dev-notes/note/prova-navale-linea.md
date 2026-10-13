# Prova navale completa — 13.10.2026

PROVATO IN TF3 build40420, modv14-bozza-56eb18f5, copia iniziale 'capocantiere test porto12-10'.
Due porti costruiti (gruppi121162/120860), Lissone deposito rifiutato, Calliano deposito117738 costruito.
Linea119497 creata, nave118966 oita_hovercraft comprata, assegnazione rifiutata. Azione ok=false.
Stima flotta1, giro745s, velocita27.7m/s ricavata dal modello. Sono stime, nave non in servizio.
Sonda di sola lettura: modello e linea modo12; deposito raggiunge entrambi i gruppi con modo12,
non con13. Nave IN_DEPOT, linea0veicoli. Nessun'altra costruzione/acquisto/assegnazione dopo il fallimento.
Il collaudo segnala anche entrambi i bacini senza edifici/industrie/coincidenze: servizio poco utile,
strada d'accesso non creata (messaggio generico gia'collegata/nonserve, non prova di accesso reale).
Causa assegnazione ancora da isolare; non correggere alla cieca o affermare servizio riuscito.
Risposta integrale senza dati personali in prove-navale-13-10-linea.json. Copia attualmente non salvata.

## Diagnosi successiva e salvataggio

PROVATO IN TF3: API app.saveGame con nome distinto e skipSetName=true, callback completato,
SAV70950145byte e JPG543171byte verificati. Nome 'capocantiere nave fallita13-10' (con spazio prima13).
Assegnazione della stessa nave alla stessa linea riprovata senza acquisti: stop0 rifiuta,
stop-1 (nextreachable, codice ufficiale GUI) rifiuta. Non e' un semplice ritardo di assegnazione.
API ufficiale util.line.getDetailedLineProblems: entrambe le fermate noPath=true,
incompatibleStop=false, duplicateStop=false. getFailedPathReason restituisce Unkown(0), senza posizione.
CC.groupPath tra gruppi nei due sensi e deposito verso entrambi restituiscono true con modo12.
Quindi il percorso generico a nodi NON certifica la navigabilita' reale dei porti.
Nessuna correzione al codice finche' causa non isolata. Bacino delle due fermate ancora vuoto.
