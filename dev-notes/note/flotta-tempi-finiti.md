# Tempi di giro finiti, 10.10.2026

Passo STATO4b sui sorgenti: sectionTimes viene sommato quando t > 0. math.huge soddisfa questa condizione; anche somme di valori singolarmente finiti possono traboccare. Da confermare in fixture prima del codice: nessun risultato con round_trip_s/interval_now_s infiniti e nessuna proposta/compra/vendita da una misura invalida.

Piano: un test Lua nativo e quattro verifiche mock per tempo infinito, overflow della somma per tratta, overflow del giro, e dati validi di un altro veicolo che restano utilizzabili. RED in CI prima della correzione. Ignorare singoli tempi non numerici/non positivi/non finiti; somme/medie/giro non finiti sono misure mancanti, senza inventare limiti fisici dei tempi. Conservare il precedente errore di misura mancante e i calcoli validi. Fixture apply=true intercetta add/remove e conta tentativi; nessun gioco, bridge, mod rigenerata o installazione.

Limite: comportamento dei veri sectionTimes C++ non nuovamente sondato; nessuna prova in partita. Non dedurre unita' da dati sintetici.

## RED riprodotto e correzione minima

CI 38050006467: Ubuntu 92 test/1 errore/1 skip Windows; errore nativo misura non finita genera stima o tentativo di modifica, quattro nuovi mock falliti. Windows verde con classe Lua skip. Dopo verifica del RED, b2 filtra tempi numerici positivi inferiori a math.huge e controlla la media della tratta e la somma del giro prima di accettarle. Overflow diventa misura mancante, stesso ritorno prima di proposta/apply. Nessuna modifica ai default, ai tempi finiti validi o al modello di stima. GREEN e revisione in attesa.

## Rilievo della revisione: overflow interi

Il primo GREEN 38050123124 non e' sufficiente per il merge: la revisione ha trovato che sum parte da 0 intero. In Lua 5.3/5.4 somme di interi traboccano con wraparound, non infinito ([manuale ufficiale Lua 5.4, 2.1/3.4.1](https://www.lua.org/manual/5.4/manual.html#3.4.1)). Due tempi math.maxinteger possono produrre sum=-2 e un giro negativo; controllare soltanto < math.huge non basta.

Prima della correzione aggiunti un test nativo e un quinto mock con due veicoli/due tratte math.maxinteger: risultato matematico positivo in virgola mobile e nessuna vendita dovuta al wraparound. Le modifiche apply=true restano fixture intercettate, mai gioco reale. Attendere RED dedicato, poi avviare l'accumulo da 0.0; nessuna nuova soglia dei tempi.

## RED dedicato interi e correzione

CI 38050265270 conferma il rilievo: Ubuntu 93 test/1 errore/1 skip Windows, nuovo test overflow intero altera il giro o vende veicoli in errore e quinto mock fallito. Solo dopo questo RED accumulo inizializzato con 0.0, evitando wraparound dell'addizione intera; guardia media/giro richiede anche valori positivi. Dato grande finito conserva risultato matematico float e target coerente; nessuna soglia inventata. GREEN finale/revisione in attesa.
