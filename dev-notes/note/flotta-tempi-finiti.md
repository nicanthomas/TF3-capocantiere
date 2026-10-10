# Tempi di giro finiti, 10.10.2026

Passo STATO4b sui sorgenti: sectionTimes viene sommato quando t > 0. math.huge soddisfa questa condizione; anche somme di valori singolarmente finiti possono traboccare. Da confermare in fixture prima del codice: nessun risultato con round_trip_s/interval_now_s infiniti e nessuna proposta/compra/vendita da una misura invalida.

Piano: un test Lua nativo e quattro verifiche mock per tempo infinito, overflow della somma per tratta, overflow del giro, e dati validi di un altro veicolo che restano utilizzabili. RED in CI prima della correzione. Ignorare singoli tempi non numerici/non positivi/non finiti; somme/medie/giro non finiti sono misure mancanti, senza inventare limiti fisici dei tempi. Conservare il precedente errore di misura mancante e i calcoli validi. Fixture apply=true intercetta add/remove e conta tentativi; nessun gioco, bridge, mod rigenerata o installazione.

Limite: comportamento dei veri sectionTimes C++ non nuovamente sondato; nessuna prova in partita. Non dedurre unita' da dati sintetici.
