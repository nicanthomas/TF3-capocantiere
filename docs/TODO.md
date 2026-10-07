# Da fare (aggiornato 07.10.2026)

Modalita' di gioco prevista: creativa (i costi non vanno gestiti).

## Gia' fatto
- [x] Bus, tram (anche elettrici), fermate, linee, acquisto veicoli.
- [x] Merci su strada (industria → industria/citta').
- [x] Ferrovia passeggeri tra 2+ citta': stazioni a 2 binari con scambi, passaggi a livello, sovrappassi,
      sottopassi, ponti, gallerie, deviazioni, pulizia se fallisce.
- [x] Epoche: provato nel 1900; costruito nel 2300 (standard + catenaria, tram elettrico, bus, merci).

## Fase 0 - Prossima sessione
- [ ] Chiave API nuova: `setx ANTHROPIC_API_KEY "..."`, `pip install anthropic`; revocare la chiave vecchia (utente).
- [ ] Verifica nel 2300 (`autosave_CC_test_2300-04-15`): veicoli in movimento su ferrovia a 2 binari con
      2 treni elettrici, tram elettrico, bus, merci.
- [ ] Prima sessione completa con `main.py` e direttive vere.

## Fase 1 - Protezione della partita
- [ ] Verifica "a secco" di ogni proposta (`makeProposalData`) prima di costruire.
- [ ] Salvataggio automatico prima delle azioni grandi (verificare se l'API lo consente).
- [ ] Avviso / ripresa se la partita e' in pausa.
- [ ] Validazione degli input delle azioni nella mod.
- [ ] Pulizia automatica anche per il tram quando l'azione fallisce.

## Fase 2 - Logica di posizionamento
- [ ] Stazioni dove servono (bacino di passeggeri/merci), non solo dove c'e' spazio.
- [ ] Ogni costruzione collegata alla rete stradale (strade d'accesso se mancano).
- [ ] Nodi intermodali passeggeri: stazione treno vicino a fermata tram/bus, linea urbana che passa dalla stazione.
- [ ] Nodi intermodali merci: catene camion → treno → camion (e porto/aeroporto).
- [ ] Riuso di stazioni e depositi esistenti.

## Fase 3 - Nuovi mezzi e infrastrutture
- [ ] Treni merci.
- [ ] Bus tra citta' vicine.
- [ ] Autostrade tra citta' con svincoli.
- [ ] Aerei passeggeri e merci (aeroporti).
- [ ] Elicotteri (verificare quali modelli esistono).
- [ ] Navi passeggeri e merci (porti).
- [ ] Capacita' ferroviaria: doppio binario, segnali.

## Fase 4 - Gestione della rete
- [ ] Aggiungere/togliere veicoli, sostituire modelli vecchi.
- [ ] Modificare, allungare, demolire linee su richiesta.
- [ ] Annulla ultima azione.

## Fase 5 - Interfaccia
- [ ] Test di una finestra di testo nella GUI di TF3.
- [ ] Chat in gioco con conferme Si'/No.
- [ ] Avvio con un'icona (middleware in sottofondo).

## Fase 6 - Qualita' e manutenzione
- [ ] Script di build per lo script della mod (oggi cc_lib + cc_actions incollati a mano); eventuale divisione in piu' file.
- [ ] Log per azione nella cartella capocantiere.
- [ ] Test automatici su CC_test.
- [ ] Prove nelle epoche intermedie (1950, 1990) e su altre mappe.
- [ ] Filtro veicoli delle mod (parti di treni bloccati, modelli incompleti).
- [ ] Avviso se cambia la build di TF3.
- [ ] Meno consumo API: riassunto della conversazione, prompt caching.
- [ ] Middleware: sposta in una sottocartella i vecchi file `actions_` rimasti (senza cancellarli).
- [ ] `docs/scoperte-api.md`: correggere le righe superate su `trackType` e `tramCatenary` (indici da 1).
- [ ] Finale: `DEV_MODE = false`, README aggiornato.
