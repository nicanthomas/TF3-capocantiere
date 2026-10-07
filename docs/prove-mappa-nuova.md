# Prove su mappa nuova (07.10.2026, anno 2020, modalita' creativa)

Mappa appena creata: 11 citta', 19 industrie, nessuna infrastruttura del giocatore. Mod v13 + bozza via sim_eval.

## Prima serie (azione 1): riuscita
- p1 ricognizione, p16 mappa, s11 tempo: ok (gameTime parte da 1000 ms).
- p2 bus tra Sarnano e Alloro (3,8 km): fermate nuove, deposito, 2 bus; collaudo ok.
- p5 ferrovia passeggeri v2 Sarnano-Alloro: stazioni a 350 e 500 m dal centro, binario di 3,2 km (8 ponti,
  28 gallerie, sovrappassi), 2 treni, navette bus in tutte e due le citta'; collaudo ok.
- p4 treno merci: fallito con la piattaforma petrolifera (industria in acqua: nessun posto per lo scalo). Le prove ora
  scartano le industrie con acqua entro 150 m.

## Seconda serie (azione 3): CRASH del gioco
Lanciate insieme p4, p14, p12, p3+p8, p19, p20, p21. Dal registro del gioco (`crash_dump/stdout.txt`):
1. "Duplicate edge detected" in `construction_util_connector` durante le verifiche a secco delle stazioni (non fatale).
2. Fatale (il gioco continua ma lo stato e' corrotto): `TransportNetworkSystem::EntityToBeRemoved: AreAllNodesEmpty`
   subito dopo una proposta rifiutata ("Costruzione non consentita") che collegava un segmento a nodi esistenti:
   si sta togliendo un'entita' che ha ancora nodi di rete occupati (pulizia dopo un fallimento).
3. Poi `GetComponentDataIndex: it != components.end()` e `NodeList::Remove` (entita' gia' tolte).
4. Crash finale: "Duplicate edges found" sull'entita' 87730 durante il posizionamento di un porto ("Posiziona sulla
   costa", quota -6 m).

Lezioni:
- Le PULIZIE (togliere costruzioni/binari appena fatti dopo un fallimento) sono la parte piu' pericolosa: togliere
  qualcosa che e' gia' collegato alla rete o ha veicoli dentro corrompe lo stato. Vanno rese prudenti: togliere solo
  costruzioni isolate, mai nello stesso momento in cui si vendono veicoli (vedi crash dell'hangar), meglio lasciare un
  pezzo inutile che rischiare il crash.
- Una prova per volta: con 7 prove nello stesso file non si capisce quale ha causato il problema.
- Porti: verificare a secco anche la rete d'acqua; evitare punti vicini ad altre costruzioni sull'acqua.
