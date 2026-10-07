# Piano per la sessione con il PC (07.10.2026 sera)

Partita: `CC_test`, salvataggio `autosave_CC_test_2300-04-15` (mod v13 installata). Dopo ogni prova: gioco in pausa.
Regole: scrivo solo in `mods` e `capocantiere`, backup prima di sovrascrivere, niente cancellazioni.
GitHub sempre aggiornato: dopo ogni modifica o scoperta (codice, risultati delle sonde e delle prove, schemi copiati,
TODO) caricamento via Composio, titolo `gg.mm.aaaa-NR-Descrizione`, controllo degli SHA. Niente lavoro solo in locale.

## Chi fa cosa
Regola: tutto cio' che posso fare io lo faccio io. Nicolo' fa solo cio' che richiede lui di persona:
- accendere il PC, aprire l'app di Claude e approvare le richieste di accesso;
- chiave API (creazione, `setx`, revoca della vecchia): la chiave non deve mai passare da me;
- confermare le scritture fuori da `mods`/`capocantiere`: installazione di `anthropic` (cartella di Python),
  nuovi salvataggi (cartella dei salvataggi), mod scaricate dal Workshop (cartelle di Steam).

## 0. Prima di tutto
- [ ] (Nicolo') Chiave API nuova: `setx ANTHROPIC_API_KEY "..."`; revocare la vecchia.
- [ ] (io, dopo conferma) `pip install anthropic`.
- [ ] Spostare `actions_241_*` e `actions_242_*` in `capocantiere\vecchi` PRIMA di caricare il salvataggio
      (altrimenti la mod potrebbe eseguirli).
- [ ] Backup del middleware installato in `capocantiere\backup\middleware_v7`, poi copia di quello nuovo
      (main, game_bridge, tools, lua_table, conversation, journal, tools_bozza, verifica_installazione,
      avvia_capocantiere.bat, test_middleware).
- [ ] `python verifica_installazione.py`.

## 1. Verifica v13 nel 2300
- [ ] Caricare il salvataggio, controllare che i veicoli si muovano: ferrovia Caprifoglio-Assalve (2 treni elettrici
      che si incrociano), tram elettrico Caprifoglio, bus Assalve, merci fattoria -> Assalve.

## 2. Sonde (sola lettura, nessun rischio)
Ogni sonda: `python dev/mkeval.py --id <lastActionId+1> --key sN --solo-lib dev/sonde/sN_*.lua`, poi leggere il results.
- [ ] s1 API (salvataggio, comandi linee), s2 costruzioni, s3 moduli, s4 veicoli (aerei/elicotteri/navi), s5 strade.
- [ ] (io, col mouse nel gioco) Costruire a mano: scalo merci ferroviario, campo d'aviazione o aeroporto, eliporto,
      porto + deposito navale. Se il controllo del computer non basta: Nicolo'.
- [ ] s6 copia costruzioni -> `CC.TEMPLATES` / `CC.CARGO_STATION_TEMPLATE` in `dev/bozza`.
- [ ] s7 linee e bacini.

## 3. Prove della bozza (costruiscono: salvare prima)
`python dev/mkeval.py --id <N> --key pN dev/prove/_aiuti.lua dev/prove/pN_*.lua`
- [ ] p1 ricognizione (sola lettura)
- [ ] p2 bus tra citta'
- [ ] p3 aggiungi / togli / sostituisci veicoli
- [ ] p6 annulla
- [ ] p7 navetta stazione-centro
- [ ] p8 allunga linea
- [ ] p4 treno merci
- [ ] p5 ferrovia passeggeri v2
- [ ] p9 strada d'accesso (dopo le costruzioni fatte a mano)
- [ ] aerei / elicotteri / navi / superstrada (dopo aver riempito gli schemi)

Per ogni prova che costruisce: controllare anche che FUNZIONI (veicoli in movimento, passeggeri/merci trasportati
dopo qualche mese di gioco), non solo che la costruzione esista.

## 3b. Early game (mappa appena creata)
- [ ] (io, dopo conferma per la cartella dei salvataggi) Nuova partita di prova nel 2300 su mappa appena creata, senza nulla costruito (stesse mod): ripetere p2, p4, p5
      partendo da zero (prime arterie e linee principali).

## 3c. Salvataggio di terzi e mod esterne (se disponibili)
- [ ] (io) Cercare sul Workshop/web un salvataggio di TF3 con una rete gia' costruita e proporlo a Nicolo';
      scaricarlo (e le sue mod) solo dopo conferma.
- [ ] (io) Caricarlo, sonde s6/s7, salvare i risultati.
- [ ] (io) Elenco delle mod installate letto dalla cartella mods + Workshop (sola lettura), lettura della loro logica.

## 4. Versione 14
- [ ] `python dev/build_script.py --bozza`, backup della v13, installazione, ricarica della partita.
- [ ] `set CAPOCANTIERE_BOZZA=1` e prima sessione vera con `avvia_capocantiere.bat`.
