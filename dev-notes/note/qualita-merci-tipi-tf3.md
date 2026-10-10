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

## Design del passo sorgenti (sessione autonoma 10.10.2026)

Modifica circoscritta: CC.normalizeCargoQuality(summary) restituisce una tabella serializzabile con available/errors e i due rami passengers/cargo, ciascuno con available/errors e campi dichiarati leggibili. Ogni accesso e' protetto da pcall, senza pairs/clone/tostring del dato o dell'eccezione. nil/false/zero restano distinti; averageQuality e' copiato solo se numero finito, senza conversioni o soglie. Contatori non negativi interi; contatori incoerenti conservati ma rapporto omesso/errore segnalato. bad_fraction solo con countTotal positivo e contatori coerenti, mai presentato come percentuale o misura di ritardo.

CC.lineCargoQuality legge soltanto getSummarizedCargoQualityDataForLine(line_id), una chiamata protetta; API assente o guasta diventa risultato non disponibile. b2 aggiunge cargo_quality al risultato di adjust_line_fleet solo per apply falso/assente (check_line_fleet nel middleware). Anche con tempi giro mancanti la qualita' resta leggibile, senza cambiare il giudizio/stima della flotta. Nessun comando, acquisto, modifica o azione automatica aggiunto.

Prima del codice: casi mock RED in CI, poi GREEN; verificare campo opzionale, falso/zero, tipi errati, numeri non finiti, proxy con accessor guasto/pairs vietato e API assente/errore senza leak messaggi. Un userdata Lua sintetico verifica gli accessi espliciti; non dimostra compatibilita' del userdata C++ TF3. Nessuna mod rigenerata/installata. Bozza NON provata in partita.

## Esito dello sviluppo sorgenti

Adattatore e integrazione completati, 10.10.2026. RED nativo CI 38048874590 confermato prima del codice; GREEN 38049081989: Ubuntu 89 test (1 skip Windows), Windows 80 (classe Lua skip), mock normale 84 ok/0 falliti. Il test di fallimento intenzionale del mock produce 84 ok/1 fallito e viene atteso dalla suite; non e' un errore del normale collaudo. Locale isolato 80 OK, classe Lua saltata per DLL fidata assente. Revisione indipendente senza blocchi.

Il nuovo test usa un vero userdata Lua sintetico, ripristinandone il metatable anche in errore: non dimostra leggibilita' o semantica dei userdata C++ TF3. Le linee senza veicoli mantengono il ritorno anticipato precedente, senza dato aggiuntivo. IndustryProductivityInfo resta sola ricerca, non implementato. build --check --bozza resta DIVERSO: nessuna rigenerazione o installazione della mod, nessun collaudo in partita.
