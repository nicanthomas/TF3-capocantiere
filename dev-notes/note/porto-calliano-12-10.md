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
