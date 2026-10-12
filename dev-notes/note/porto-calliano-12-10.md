# Porto Calliano costruito dall'interfaccia — 12.10.2026

PROVATO IN TF3, copia separata `capocantiere test porto 12-10` creata dal save bus senza residui ferroviari. Nuovo .sav di 70733789 byte e .jpg verificati alle 19:55:31 prima di costruire; originale non sovrascritto.

Un solo porto passeggeri grande piazzato dalla GUI su anteprima valida: costruzione 122216, file `::/stations/water/harbor_modular.con`, una stazione, nessun deposito, due edifici nel bacino prima del collegamento stradale. NON ancora linea navale funzionante.

Parametri: largeterminals=1, seed=0, year=2025. Trasformazione X=(0.990344,-0.13863), Y=(0.13863,0.990344), origine=(-7134.1,-1723.31,2). Terreno all'origine=0.300003: la GUI pone il porto a quota 2, non alla quota del terreno usata da CC.placeTemplate. Posizione generica della costruzione=(-7141.03,-1746.71,16.7868), diversa dall'origine: usare la trasformazione per confrontare.

Moduli letti in forma piatta (una lettura precedente perdeva i dati annidati per il limite di profondita' del protocollo):
- 100009444=medium_pier.module
- 100009612=passenger_dock_100_25.module
- 100009722=passenger_dock_100_50.module
- 100010150,101010150,98010150,99010150=pedestrian_entrance.module

Tutti in `::/stations/water/`, variante 0. Acqua a -Y60, non agli altri tre lati. Il modello grande copiato da terzi nel codice ha piu' moduli; il modello piccolo non e' ancora confrontato. La quota differente e' una causa candidata, NON una correzione verificata: vecchie prove a quota 2 fallivano anch'esse.

Anello: proposte a secco sul mondo fallito per offset -10,-5,+5 m tutte rifiutate per collisioni stradali. Sonda bloccava sendCommand; nessuna costruzione o rimozione per questa diagnosi. Non aggirare le collisioni. Il percorso del secondo binario resta da correggere.

### Prova automatica reale del 12.10, 20:06

PROVATO IN TF3: build_air_or_water_line town_ids=[62685,62691], kind=harbor, numero navi omesso, conferma esplicita nel middleware. Entrambi i porti piccoli si costruiscono e generano stazioni (63463,63832). La prova fallisce poi: `nessun deposito/hangar per i veicoli`. Deposito di Lissone rifiutato nei tre punti di costa candidati (collisioni o messaggio vuoto). Nessuna linea o nave creata. Il middleware riporta pulizia di due costruzioni; porto GUI 122216 resta sulla mappa.

Questo risultato supera il vecchio blocco storico dei porti; non dimostra che funzionino su ogni costa. Non e' stata modificata la mod per questo esito: versione 509c3059. Risposta grezza in `prove-navale-12-10.json`.

Porto GUI salvato separatamente: `capocantiere porto GUI 12-10`, .sav 71091514 byte e .jpg 610344 byte verificati alle 20:04:04. Prossimo passo: deposito GUI per leggere quota/orientamento validi, quindi correggere soltanto cause confermate.

### Stop richiesto da Nicolo', 12.10.2026 20:11

PROVATO IN TF3 prima dello stop: deposito navale costruito dalla GUI, costruzione 122426, file `::/depots/water/water_depot.con`, un deposito e zero stazioni. Parametri seed=1, year=2027. Trasformazione X=(0.997749,-0.0670646), Y=(0.0670646,0.997749), origine=(-7558.78,-1680.23,2), acqua sul lato -Y60. Nessun acquisto nave e nessuna linea navale conclusa.

TF3 lasciato aperto sulla copia `capocantiere porto GUI 12-10`: il salvataggio verificato delle 20:04 precede questo deposito. Il deposito GUI e le variazioni successive NON sono salvati. Il porto GUI era stato salvato; originale e copie precedenti preservati. Nessuna modifica sorgenti dopo la correzione velocita' 219e678.

La sonda di percorso deposito/porto non e' stata eseguita: l'ordine `stop, update git` e' arrivato prima dell'avvio ed il controllo automatico ha respinto l'azione. Non aggirato. Nessuna conclusione sulla raggiungibilita' del deposito. Alla ripresa verificare prima lo stato reale del PC e conservare una nuova copia se ancora disponibile; poi diagnosi deposito e collaudo navi. Doppio binario ancora incompleto. Mod NON finalizzata.
