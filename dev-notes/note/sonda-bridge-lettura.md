# Sonda snapshot bridge di sola lettura — 11.10.2026

Design circoscritto: bridge_snapshot.py standalone stdlib + parser letterali lua_table, nessun import game_bridge, ricerca Steam, ambiente o DLL. CLI richiede --state-file assoluto locale, basename state.lua/capocantiere_state.lua; nessun percorso di default o rete UNC. Aprire solo file regolari, rb, limite diagnostico 8 MiB, decodifica UTF-8 stretta, controllare cambiamento dimensione/mtime/identita' durante la lettura (non garanzia OS di snapshot atomico). Nessuna scrittura, cartella, azione, risultato o cleanup.

Riepilogo JSON: ok/errors/warnings fissi, counts delle cinque sezioni, validita' lastActionId senza valore, modVersion soltanto presente/assente, read_only=true e live_bridge_tested=false. Non stampare percorsi, nomi/coordinate, messaggi esportati o eccezioni raw. Sezione opzionale assente -> null e warning, tipo errato -> errore; lastActionId intero non negativo, bool escluso. File parsabile non prova partita aperta, runtime vivo o richiesta ricevuta.

Sette regressioni fixture prima del codice: byte/directory invariati e sibling azione, nome legacy/assenze, input rifiutati prima open, errori statici/Unicode/schema, limite e read bounded, cambio durante read, CLI/import senza ambiente/bridge/ricerche/DLL. RED locale/CI, GREEN/revisione prima merge. NON eseguire sui dati reali senza ambito concordato; installazioni/mod/partite/chiavi fuori scope.

RED locale corretto: 104 test/17 errori da tool/costanti/funzioni mancanti (subcase inclusi), 1 classe Lua skip, 16,246 s. Nome serializzatore fixture corretto a dumps prima del RED valido; sorgente produttivo assente.
