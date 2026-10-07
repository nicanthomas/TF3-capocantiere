# Da fare (aggiornato 07.10.2026)

Bozze scritte senza gioco (da provare): vedi `dev/bozza/README.md` e `docs/piano-stasera.md`.

Modalita' di gioco prevista: creativa (i costi non vanno gestiti).

## Principi (richiesta di Nicolo', 07.10.2026)
- La mod deve saper piazzare TUTTO cio' che il giocatore puo' costruire a mano (stazioni, fermate, depositi di ogni
  tipo, scali merci, porti, aeroporti, eliporti, strade, autostrade, binari, segnali).
- Ogni cosa piazzata deve FUNZIONARE, non essere solo un costo fisso: collegata alla rete, servita da una linea con
  veicoli, con un bacino di passeggeri/merci reale. Se non funziona, l'azione lo dice e prova a correggere.
- Uso principale: early game = mappa appena creata (anno 2300, rete vuota), per costruire le arterie e le linee
  principali da zero. Il caso piu' importante e' quindi la mappa vuota del 2300, con i veicoli del 2300.
- Claude non gioca da solo: agisce solo sulle direttive di Nicolo'. Le correzioni trovate dal collaudo vengono
  proposte e fatte solo dopo conferma.
- Deve funzionare in tutte le epoche (dal 1900 al 2300) e convivere con le mod esterne usate da Nicolo'.

## Gia' fatto
- [x] Bus, tram (anche elettrici), fermate, linee, acquisto veicoli.
- [x] Merci su strada (industria → industria/citta').
- [x] Ferrovia passeggeri tra 2+ citta': stazioni a 2 binari con scambi, passaggi a livello, sovrappassi,
      sottopassi, ponti, gallerie, deviazioni, pulizia se fallisce.
- [x] Epoche: provato nel 1900; costruito nel 2300 (standard + catenaria, tram elettrico, bus, merci).

## Fase 0 - Prossima sessione
- [ ] Chiave API nuova: `setx ANTHROPIC_API_KEY "..."`, revoca della vecchia (Nicolo'); `pip install anthropic` (io, dopo conferma).
- [ ] Verifica nel 2300 (`autosave_CC_test_2300-04-15`): veicoli in movimento su ferrovia a 2 binari con
      2 treni elettrici, tram elettrico, bus, merci.
- [ ] Installare sul PC il middleware aggiornato (backup prima) e lanciare `verifica_installazione.py`.
- [ ] Prima sessione completa con `main.py` e direttive vere.

## Fase 1 - Protezione della partita
- [ ] Verifica "a secco" di ogni proposta (`makeProposalData`) prima di costruire. (bozza: `CC.buildCmd`)
- [ ] Salvataggio automatico prima delle azioni grandi (verificare se l'API lo consente).
- [ ] Avviso / ripresa se la partita e' in pausa. (bozza: velocita' in state.lua, avviso nel middleware, `set_speed`)
- [x] Validazione degli argomenti nel middleware (schema dei tool).
- [ ] Validazione degli input anche nella mod.
- [ ] Pulizia automatica anche per il tram quando l'azione fallisce. (bozza: b9)

## Fase 2 - Logica di posizionamento
- [ ] Stazioni dove servono (bacino di passeggeri/merci), non solo dove c'e' spazio. (bozza: b3)
- [ ] Ogni costruzione collegata alla rete stradale (strade d'accesso se mancano). (bozza: `CC.ensureRoadAccess`)
- [ ] Nodi intermodali passeggeri: stazione treno vicino a fermata tram/bus, linea urbana che passa dalla stazione. (bozza: navetta)
- [ ] Nodi intermodali merci: catene camion → treno → camion (e porto/aeroporto). (bozza: scali con l'industria nel bacino)
- [ ] Riuso di stazioni e depositi esistenti.
- [ ] Depositi con logica: vicino al capolinea, collegati alla rete della linea, fuori dal centro. Tutti i tipi:
      strada, tram, ferrovia, navale; per aerei/elicotteri verificare se serve un deposito o fa da hangar l'aeroporto.
- [ ] Comando diretto "costruisci deposito" (oggi i depositi nascono solo dentro "fai una linea").

## Fase 2b - Collaudo: quello che costruisco deve funzionare
- [ ] Dopo ogni costruzione, controllo automatico: linea con percorso valido, veicoli assegnati e in movimento
      (non bloccati), deposito raggiungibile, fermate con citta'/industrie nel bacino.
- [ ] Controllo a distanza di tempo (es. dopo 1-2 mesi di gioco): passeggeri/merci trasportati > 0, carico in attesa,
      veicoli fermi. Rapporto a Claude e proposta di correzione (piu' veicoli, fermata spostata, collegamento mancante).
- [ ] Comando "controlla la rete": elenco di linee e costruzioni che non funzionano.
- [ ] Le prove in gioco (p1-p9) verificano anche il funzionamento, non solo che la costruzione esista.

## Fase 2c - Imparare da reti fatte da altri e dalle mod esterne
- [ ] Salvataggio di un altro giocatore (con le stesse mod del suo autore): caricarlo con la nostra mod e leggere con
      le sonde s6/s7 aeroporti, porti, scali, svincoli, linee e depositi reali -> schemi (`CC.TEMPLATES`) e regole di
      posizionamento.
- [ ] Mod esterne che Nicolo' usera': leggerne i file (cartella mods + Workshop di Steam, sola lettura) per capirne
      la logica (costruzioni, moduli, veicoli, parametri) e farle usare anche alla nostra mod.

## Fase 3 - Nuovi mezzi e infrastrutture
- [ ] Treni merci. (bozza: b3)
- [ ] Bus tra citta' vicine. (bozza: b2)
- [ ] Autostrade tra citta' con svincoli. (bozza: superstrada senza svincoli, b4)
- [ ] Aerei passeggeri e merci (aeroporti). (bozza b4 + sonde: schemi da copiare in gioco)
- [ ] Elicotteri (esistono: eliporto nel menu aereo, passeggeri e merci). (bozza b4)
- [ ] Navi passeggeri e merci (porti: `harbor_modular.con`, `water_depot.con`). (bozza b4)
- [ ] Capacita' ferroviaria: doppio binario, segnali.
- [ ] Linee circolari (anello chiuso) e linee nei due sensi opposti sulla stessa infrastruttura.
- [ ] Traffico misto passeggeri + merci sugli stessi binari: scali merci su raccordi collegati alla linea principale
      con scambi, binari di sorpasso/precedenza, binari di transito nelle stazioni passeggeri per i merci, segnali
      fitti; il collaudo controlla che i merci lenti non blocchino i passeggeri.
- [ ] Treni veloci / alta velocita' sulla stessa infrastruttura: linee che fermano solo nelle citta' principali,
      binari di transito nelle stazioni minori, binario ad alta velocita' e curve ampie dove serve, sorpassi dei treni
      lenti; avviso a Claude se la capacita' non basta (proposta: binari dedicati all'AV).
- [ ] Potenziare cio' che esiste quando il traffico cresce: binari e marciapiedi in piu' nelle stazioni, fermate
      piu' grandi, strade allargate, scali e porti ampliati (le arterie fatte a inizio partita devono poter crescere).

## Fase 3b - Pianificazione della rete (direttive strategiche)
- [ ] Direttive ampie ("collega tutte le citta' principali", "porta il carbone alla citta' X"): Claude legge la mappa,
      propone un piano in passi (arterie prima, poi linee secondarie e nodi di scambio), chiede conferma, poi costruisce
      un passo alla volta controllando ogni risultato.
- [ ] Lettura della mappa per Claude: citta' e dimensioni, industrie e catene merci, acqua/coste, rilievi, rete esistente.

## Fase 4 - Gestione della rete
- [ ] Aggiungere/togliere veicoli, sostituire modelli vecchi. (bozza: b2)
- [ ] Modificare, allungare, demolire linee su richiesta. (bozza: b2)
- [ ] Annulla ultima azione. (bozza: b2 + `middleware/journal.py`)

## Fase 5 - Interfaccia
- [ ] Test di una finestra di testo nella GUI di TF3.
- [ ] Chat in gioco con conferme Si'/No, aperta da un'icona nella barra del gioco.
- [x] Avvio con doppio clic: `avvia_capocantiere.bat` + `verifica_installazione.py`.
- [ ] Avvio insieme al gioco / middleware in sottofondo.

## Fase 6 - Qualita' e manutenzione
- [x] Script di build `dev/build_script.py` (backup + controllo sintassi + `--check`).
- [ ] Eventuale divisione dello script della mod in piu' file (da provare se TF3 lo consente).
- [ ] Log per azione nella cartella capocantiere.
- [ ] Numero di versione scritto dallo script di build dentro lo script della mod (e in state.lua).
- [ ] Promozione delle bozze provate: da `dev/bozza/` a `cc_actions.lua`, schemi da `tools_bozza.py` a `tools.py`.
- [ ] `state.lua` su mappe grandi: esportare solo i dati utili, e piu' di rado quando nulla cambia.
- [x] Test automatici del middleware senza gioco (`middleware/test_middleware.py`).
- [ ] Test automatici in gioco su CC_test.
- [ ] Prove su una mappa nuova appena creata (2300, nessuna infrastruttura) come caso principale.
- [ ] Prove nelle epoche intermedie (1950, 1990) e su altre mappe (montagna, isole, citta' molto dense).
- [ ] Filtro veicoli delle mod (parti di treni bloccati, modelli incompleti).
- [ ] Avviso se cambia la build di TF3.
- [x] Meno consumo API: prompt caching e taglio dei turni vecchi (`MAX_TURNS`).
- [ ] Riassunto automatico dei messaggi vecchi (oggi vengono solo tagliati: Claude perde il contesto delle
      costruzioni fatte prima).
- [x] Middleware: all'avvio sposta in `vecchi` i file `actions_` rimasti (senza cancellarli).
- [x] `docs/scoperte-api.md`: righe su `trackType` e `tramCatenary` corrette (indici da 1).
- [ ] Finale: `DEV_MODE = false`, README aggiornato.
