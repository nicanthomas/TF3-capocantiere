# Aggiornamento del gioco build 40420 (08.10.2026) — effetti sul progetto

Note di rilascio: https://wiki.transportfever3.com/doku.php?id=releasenotes (40420 Steam, 08.10.2026; prima: 40408 del 29.09).

## BLOCCANTE: la mod non puo' piu' scrivere nella cartella `capocantiere`
- Note di rilascio: "Improved the internal scripting API's functionality" (nessun dettaglio).
- Log del gioco (`crash_dump/stdout.txt`, 08.10 15:16Z, partita di terzi caricata) ogni 10 s:
  `capocantiere.script.lua:278: The directory you trying to access is not available or invalid`
  (traceback: `saveUserdata` <- `exportState`). `state.lua` resta quello del 07.10 sera.
- Prova: file azioni `lua_eval` (sonda di diagnosi) per gli id 1 e 34 -> in 40 s nessuno eseguito, nessuna riga nel
  log. Quindi o anche `getAllUserdata`/`loadUserdata` sono bloccate, o il lastActionId della partita e' un altro.
  I due file sono stati poi resi neutri (`actions = {}`).
- Il log (`log.message`) funziona ancora: e' l'unico canale di uscita sicuro in questo momento.
- Conseguenza: finche' non si trova la cartella permessa, la mod non riceve comandi e non esporta lo stato
  (ne' sonde, ne' prove, ne' middleware).

## Prossimo passo previsto (serve l'accesso alla cartella `mods\tfcapocantiere_1` e una ricarica della partita)
Copia di prova (`build_script.py --dev` + patch `ensureDir()` all'inizio di `guiTick`) che al primo giro:
1. scrive nel log i nomi di tutte le funzioni di `app` (per vedere se c'e' una funzione nuova per la cartella dati);
2. prova `getAllUserdata` (SOLA LETTURA) su `save`, `screenshots`, `mod_presets`, `mods`, `""`, `"."`;
3. prova lettura+scrittura solo in posti permessi dalle regole: `capocantiere` (varianti con `/`, `./`, percorso
   assoluto) e la cartella della mod (`mods/tfcapocantiere_1[/capocantiere]`);
4. usa la prima cartella che funziona e lo scrive nel log (`[CAPOCANTIERE] DIRTEST ...`).
Il middleware (`game_bridge.py`) va poi allineato alla cartella trovata.

## Altre voci delle note di rilascio che ci riguardano
- "Fixed incorrect auto-activation for non-builtin mods": da verificare se la mod va ora attivata a mano nelle
  partite (e se "deluxe"/"preorder" non si riattivano piu' da sole nella partita di terzi).
- "Fixed a crash with mods that have dependencies in the staging area" / migliorie al validatore delle mod: nessun
  effetto atteso (la mod non ha dipendenze).
- "Fixed an inability to build airport hangars in specific scenarios": puo' riguardare il crash dell'hangar
  (sezione 8 di STATO); l'annulla a fasi resta comunque.
- "Fixed incorrect terminal assignment when building stops on modded asymmetric streets": utile con mod di strade
  di terzi (fermate bus/tram).
- "Fixed an error when bulldozing stations while a pinned window is active": utile per l'annulla.
- Campagna "build signal task", Map Editor, Tycoon Mod, grafica, localizzazione: nessun effetto.
- Salvataggi: la partita di terzi (versione 604, init 599) si carica senza errori nella 40420.
