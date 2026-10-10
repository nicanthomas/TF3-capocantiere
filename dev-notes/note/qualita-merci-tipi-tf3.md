# Qualita' merci: definizioni TF3 lette senza avviare il gioco

Verifica statica Codex, Windows, 10.10.2026. Nessun avvio TF3, nessun caricamento di partita, nessuna modifica o estrazione di file del gioco. Questi tipi non costituiscono una prova del comportamento a runtime.

## Fonte locale

Definizioni distribuite con il gioco: api/tealdef/api/engine/util.d.tl sotto E:\SteamLibrary\steamapps\common\Transport Fever 3.
SHA256 del file letto: B5BA8C2467C6247866FE4B3088EF7ADF2388E1B71528DB9082C12B71558973F4.
Il vecchio percorso res/scripts non esiste in questa installazione. Non si pubblica il file del gioco.

## Campi dichiarati

| Tipo | Campo | Tipo dichiarato |
| --- | --- | --- |
| CargoQualityData (righe 716-724) | countBad | integer |
| CargoQualityData | countTotal | integer |
| CargoQualityData | averageQuality | number oppure nil |
| CargoQualityData | isVeryBad | boolean |
| SummarizedCargoQualityData (725-731) | passengers | CargoQualityData |
| SummarizedCargoQualityData | cargo | CargoQualityData |
| IndustryProductivityInfo (905-910) | producing | boolean |
| IndustryProductivityInfo | boostFromRule | boolean |
| IndustryProductivityInfo | boostFromPersonCapacity | boolean |

CargoQualityData e' un userdata con clone; non presumere che pairs o serializzazione di tabelle funzionino. Le definizioni non specificano intervallo o unita' di averageQuality e getProductionRating. I boost dell'industria sono indicatori booleani, non moltiplicatori numerici.

## Argomenti delle funzioni

| Funzione nella famiglia util | Argomenti |
| --- | --- |
| cargo.getCargoQualityDataForLine (736) | lineEntity, cargoTypeId obbligatorio |
| cargo.getCargoQualityDataForVehicle (741) | vehicleEntity, cargoTypeId opzionale |
| cargo.getCargoQualityDataForStockList (769) | stockListEntity, cargoTypeId obbligatorio |
| cargo.getCargoQualityDataForStock (775) | stockListEntity, stockId, cargoTypeId opzionale |
| cargo.getSummarizedCargoQualityDataForStockList/Line/Vehicle (780-788) | un solo entity |
| stock.getCargoProducedPerYear | stockListEntity, cargoTypeId obbligatorio |
| stock.getCargoShippedPerYear/getCargoDeliveredPerYear | stockListEntity |
| stock.getCargoTypeShippedPerYear/getCargoTypeDeliveredPerYear | stockListEntity, cargoTypeId |
| industry.getIndustryProductivityInfo (913) | industryEntity |

L'assenza di cargoTypeId nelle due chiamate precedenti e' una spiegazione statica plausibile degli errori can't be cast annotati in STATO; non e' ancora confermata da una nuova sonda TF3. Il commento della variante Stock specifica che nil aggrega i tipi.

## Prossimo sviluppo consentito sui sorgenti

Preparare una normalizzazione in Lua con accessi espliciti protetti da pcall ai soli campi dichiarati, tenendo separati passeggeri e merci. Preservare averageQuality assente, senza inventare percentuali o soglie. Un rapporto countBad/countTotal e' calcolabile soltanto quando countTotal e' positivo; la sua interpretazione richiede ancora conferma. Conservare i tre booleani dell'industria.

Prima dell'integrazione in check_line_fleet: concordare il formato, aggiungere mock dei campi opzionali/errori di accesso e casi con zero elementi, poi testare in CI. L'effettiva leggibilita' dei userdata e il significato dei valori restano da verificare in una partita autorizzata. Nessuna sonda live e' stata eseguita in questa sessione.

Ricerca nelle sorgenti testuali base/content e base/tealdef: non trovata implementazione che chiarisca l'unita' di averageQuality. base/tealdef/gui/main/cargo_react_util.d.tl dichiara getFrownyIconLayout con CargoQualityData ma non chiarisce il valore. Non ispezionati salvataggi, chiavi o contenuti binari.
