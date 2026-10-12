# Velocita' dei modelli in TF3 — 12.10.2026

La prova Abriola-Maretto aveva fleet.speed_from_model=false e fallback 22 m/s.
PROVATO SUL PC: il modello base ecitaro/ecitaro.mdl contiene metadata.landVehicle.topSpeed=19.444;
roadVehicle contiene la configurazione delle ruote, non topSpeed. Nessun asset del gioco modificato.
PROVATO IN TF3: sonda in sola lettura, modello 4086, metadata.landVehicle.topSpeed=19.444;
roadVehicle/railVehicle/waterVehicle/airVehicle non restituiscono velocita'.
La funzione CC.modelTopSpeed estratta dai sorgenti precedenti restituisce nil sul modello reale:
regressione passed=false. Aggiungendo landVehicle prima delle chiavi legacy, stesso controllo passed=true.
Questa e' una prova della funzione corretta nel runtime reale, NON della mod reinstallata o della nuova stima completa.

Correzione minima b2_rete.lua, due controlli mock per landVehicle TF3 e roadVehicle legacy.
Suite Windows isolata: 134 test, zero errori/fallimenti, classe Lua saltata per runtime mancante.
Mock locale non eseguibile, NON verde; la CI Ubuntu deve eseguire Lua reale prima del merge.
Revisione separata sola lettura: nessun problema verificabile. Mod installata ancora v14-bozza-4e61dfa4.

Il nome linea non viene ignorato da build_intercity_bus: e' passato a CC.createLine e al comando.
La nota scoperte-api.md documenta che Auto Line Namer rinomina le linee nuove. Nessun comando
per forzare il nome e nessuna modifica alla mod di terzi: non correggere Capo Cantiere senza altra evidenza.

Save Abriola-Maretto ricaricato realmente: 79575 e cinque bus presenti. Nicolo' ha autorizzato
anello a doppio binario e porto/linea navale su copie distinte. La mod completa NON e' finalizzata.
