# Prova navale completa — 13.10.2026

PROVATO IN TF3 build40420, modv14-bozza-56eb18f5, copia iniziale 'capocantiere test porto12-10'.
Due porti costruiti (gruppi121162/120860), Lissone deposito rifiutato, Calliano deposito117738 costruito.
Linea119497 creata, nave118966 oita_hovercraft comprata, assegnazione rifiutata. Azione ok=false.
Stima flotta1, giro745s, velocita27.7m/s ricavata dal modello. Sono stime, nave non in servizio.
Sonda di sola lettura: modello e linea modo12; deposito raggiunge entrambi i gruppi con modo12,
non con13. Nave IN_DEPOT, linea0veicoli. Nessun'altra costruzione/acquisto/assegnazione dopo il fallimento.
Il collaudo segnala anche entrambi i bacini senza edifici/industrie/coincidenze: servizio poco utile,
strada d'accesso non creata (messaggio generico gia'collegata/nonserve, non prova di accesso reale).
Causa assegnazione ancora da isolare; non correggere alla cieca o affermare servizio riuscito.
Risposta integrale senza dati personali in prove-navale-13-10-linea.json. Copia attualmente non salvata.

## Diagnosi successiva e salvataggio

PROVATO IN TF3: API app.saveGame con nome distinto e skipSetName=true, callback completato,
SAV70950145byte e JPG543171byte verificati. Nome 'capocantiere nave fallita13-10' (con spazio prima13).
Assegnazione della stessa nave alla stessa linea riprovata senza acquisti: stop0 rifiuta,
stop-1 (nextreachable, codice ufficiale GUI) rifiuta. Non e' un semplice ritardo di assegnazione.
API ufficiale util.line.getDetailedLineProblems: entrambe le fermate noPath=true,
incompatibleStop=false, duplicateStop=false. getFailedPathReason restituisce Unkown(0), senza posizione.
CC.groupPath tra gruppi nei due sensi e deposito verso entrambi restituiscono true con modo12.
Quindi il percorso generico a nodi NON certifica la navigabilita' reale dei porti.
Nessuna correzione al codice finche' causa non isolata. Bacino delle due fermate ancora vuoto.

## Confronto porto grande, prova separata

PROVATO IN TF3 v14-bozza-5f189de4: copia iniziale ricaricata da API app.
Stessi town_ids, solo kind=harbor_large: gruppi113926/102599 e deposito12439, linea121536.
Navi116136/103887 comprate (flotta stimata2), entrambe assegnazioni fallite; noPath nativo nelle due direzioni.
Quindi scegliere porto grande NON risolve. Nessun altro acquisto/assegnazione dopo questo fallimento.
Copia 'capocantiere porto grande fallito13-10' salvata con spazio prima13, callback/SAV71064085/JPG642246
verificati. Risposta prove-navale-13-10-grande.json. La copia del porto piccolo resta separata e intatta.
Confronto terminali piccolo: presenti, indice0, passeggeri ammessi; ipotesi stazione vuota esclusa.
Ipotesi futura NON provata: shoreSites sceglie ultimo punto di terra su passi25m, porto puo' lasciare
molo/uscita nella fascia poco profonda. Confrontare stesso schema spostato25m verso acqua su copia iniziale.

## Prototipo spostamento verso acqua25m

PROVATO IN TF3 su copia iniziale ricaricata: stesso schema harbor, solo shoreBack=-25 locale alla sonda.
Tutte tre posizioni Lissone rifiutate (una collisione ciascuna, nessun messaggio descrittivo).
Azione ok=false, created contiene zero costruzioni/linee/strade/binari/veicoli. Nessun acquisto.
Prototipo non pubblicato nel codice, nessuna modifica alla mod installata o ai salvataggi precedenti.
Dati in prove-navale-13-10-spostamento.json. L'ipotesi quota/profondita' non e' confermata da questa prova:
serve ispezionare proposte e collisioni a secco prima di altre costruzioni.

## Proposte a secco e spostamento10m

PROVATO IN TF3 A SECCO: posizioni+10m senza collisioni a Lissone e sulla prima costa Calliano.
+25m collide con entita' basse4451/4793/4325, tipo non identificato; non affermare siano fondale.
Nessun comando inviato dalla sonda a secco. Prototipo+10m reale sulla copia iniziale senza residui:
porti120311/123906, deposito123907, linea25246, nave123908; assegnazione fallisce ancora.
Nessun'altra nave comprata. Quindi spostamento10m non risolve navigabilita' reale.
Save distinto 'capocantiere porto acqua10 fallito13-10' (spazio prima13), callback/SAV71144267/JPG821034
verificati. Prototipo locale, mod installata invariata. Risposta prove-navale-13-10-acqua10.json.
Ipotesi successiva NON provata: assegnazione dalla GUI invece di SIM; solo nave gia'presente, no acquisti.

## Contesto comando e modi memorizzati della linea

PROVATO IN TF3: stessa nave123908 assegnata da GUI con nextreachable-1 rifiuta (callback=false),
nessun cambiamento alla linea. Non correggere introducendo assegnazione asincrona senza una causa.
Nave effettiva carrierWATER4, config.transportModes12=true, altri10/13assenti, IN_DEPOT.
Porti offrono union12, ma linea25246 vehicleInfo.transportModes e' vuoto. Questa differenza
NON dimostra ancora causa: il campo potrebbe essere derivato dai veicoli gia'assegnati.
Prossima prova controllata: clone API Line della sola linea di test, aggiornare quel campo,
leggere se conservato e riprovare nave esistente. Stop/gruppi invariati, nessun altro acquisto.

## Modi derivati e posizione dei terminali

PROVATO IN TF3: clone Line e LineUpdateCmd con transportModes12=true accettato, ma campo resta vuoto;
nuova assegnazione nave esistente rifiutata. Il campo non offre una correzione al percorso.
Lettura connessioni reali dei terminali via getTpNetData/getNodeData e util.transport.calcPosition:
Lissone terminale(-5569.52,-5113.52,0), fondale circa-2.60; Calliano(-7476.86,-1715.66,0), circa-4.98.
Le connessioni hanno modo12 e acqua visibile, non sono stazioni interne vuote o reti senza edge.
Indice edge0-based -> tn.edges[index+1], come script ufficiale; i collegamenti sono su altra entita'
rispetto al nodo terminale. Iniziale sonda cercava nel solo componente del nodo e non li vedeva.
Lissone costa2 gia'valida a secco: origine(-5047.08,-5835.83), terreno17.32m, punto molo31.25m
verso acqua fondale-7.88 (41.25m:-14.53). Costa3 molto piu' bassa ma molo31.25m fondale-1.60.
Non inventare soglia navigabile: profondita' maggiore e' solo ipotesi da verificare con assegnazione.
Prossima prova: porto Lissone costa2, mantenere porto Calliano/nave esistente/linea e vecchio porto;
cambiare prima fermata se costruzione riesce. Nessuna demolizione o altro acquisto.

## Costa2 profonda rifiutata

PROVATO IN TF3: CC.placeTemplate harbor sul punto Lissone costa2, stessa versione/parametri,
comando rifiutato senza messaggio; nessuna costruzione nuova restituita, linea/nave non modificate.
La quota del terreno all'origine e'17.32m mentre porto si allinea all'acqua+2; non forzare ignoreErrors.
Profondita' sufficiente a un punto non certifica una posizione costruibile. Serve confronto con
anteprima ufficiale porto: harbor_modular.con configureLayerScript abilita navigableWater=true.
Non costruire alla cieca altre varianti, leggere prima la visualizzazione del gioco.

## Anteprima ufficiale porto a Lissone

PROVATO SUL PC dentro TF3, sola anteprima: costruzioni Acqua, primo porto/1terminale,
overlay ufficiale navigableWater. Puntatore1705,405: rosso 'Posiziona sulla costa';
puntatore1770,405: anteprima azzurra, senza errore, molo verso area colorata navigabile.
Camera centra(-5591.62,-5135.62), distanza350, client3440x1441; frame stock-port-preview-shore2.bmp
privato in work. Non e' ancora prova di assegnazione/servizio e non sono state create entita' da questi hover.
Prossima prova manuale gia'nel perimetro porto/linea autorizzato: clic solo anteprima valida,
leggere gruppo/parametri/transform e usarlo come prima fermata della linea25246 con nave123908.
Non leggere la vecchia proposta applicata; leggere solo componenti della costruzione nuova.

## Porto stock costruito e parametri confrontati

PROVATO IN TF3: clic singolo su anteprima valida1770,405, costruzione122925/gruppo125886,
'Porto di Lissone'. Nessun altro veicolo comprato, vecchi porti conservati.
Moduli e parametri smallterminals1/seed0 sono identici allo schema harbor della mod;
anno stock2030 vs prototipo2026, stessa epoca. Non e' un errore di moduli mancanti.
Trasformazione stock: X=(.631137,.775671), Y=(-.775671,.631137), origine(-5470.74,-4927.97,2).
Porto mod: X=(-.707107,.707107), Y=(-.707107,-.707107), origine(-5591.62,-5135.62,2).
Direzione acqua stock(.775671,-.631137) diversa dal raggio citta'->costa usato dalla mod(.707,.707).
Questa differenza suggerisce normale della costa, NON dimostra ancora causa senza servizio nave.
Prossima prova: cambiare solo prima fermata della linea25246 a125886 e usare nave123908 esistente.
Nuovo porto ancora non salvato; non leggere proposte applicate, componenti riletti viaAPI.

## Linea con primo porto stock e acqua connessa

PROVATO IN TF3: prima fermata25246 sostituita a125886, LineUpdate accettato;
seconda resta123906. Assegnazione della sola nave123908 rifiutata, niente altri acquisti.
Il primo porto stock non basta: nessuna prova che il problema sia solo quello di Lissone.
Copia 'capocantiere porto stock Lissone13-10' (spazio prima13) salvata, callback/SAV72369110/JPG670742
verificati. Contiene nuovo porto122925, vecchi porti/deposito e linea con fermata aggiornata.
Sonda read-only intera mappa(-8192..8192), griglia64m,65536punti isOnWater:
Lissone mod/stock, Calliano e Lissone costa3 ricadono nello stesso componente acqua(950celle).
E' solo approssimazione acqua visibile, NON certifica corridoio navigabile o profondita' minima;
non affermare che siano bacini separati. Nessuna modifica del terreno dalla scansione.
Prossima verifica mirata: uscita effettiva del deposito e collegamento alla zona navigabile,
prima di altre varianti di porto o acquisti.

## Deposito e modello effettivo

PROVATO IN TF3: deposito123907/con41986, file water_depot.con, uscita interna nodo0
(-7141.53,-1709.89,0) sul terreno2m, poi corsia verso(-7135.79,-1723.75,0) in acqua-6.25m,
proseguimento verso(-7088.72,-1837.38,0) in acqua-7.85m. Modi10/12.
Il nodo interno asciutto NON dimostra deposito invalido: script ufficiale pone nodo0 a(0,40,-2),
runway uscita/entrata aY-99/-100. Acqua-40 nel riferimento snap ruotato non basta da sola a interpretare tutto.
Nave Oita ha80posti passeggeri; CargoRep indice0 e'passengers, il vettore capacita'Lua parte da1.
Non confondere capacita'[1]=80 con80unita' di grain(cargo1). Lookup PASSENGERS=-1, fallback0
attuale e' corretto per questa partita. Nessuna prova di configurazione cargo incompatibile.
Anno simulazione ora2036: SolarShuttle2035 disponibile, modo12,20posti passeggeri; Oita2023modo12,80posti.
Confronto successivo: stesso deposito/linea e helper acquisto, cambia solo modello aSolarShuttle,
una nave, senza vendere o modificare Oita. E' una prova, non flotta definitiva stimata.

## Confronto SolarShuttle sullo stesso deposito/linea

PROVATO IN TF3: acquistata una SolarShuttle123446 con CC.buyVehicles, anno>=2035, stesso deposito123907,
linea25246 con gruppi125886/123906. Acquisto riuscito, assegnazione stop0 fallita, nessun veicolo sulla linea.
Oita123908 conservata; non venduto o demolito nulla. Il solo cambio modello non risolve.
Copia distinta 'capocantiere porto stock due modelli13-10' (spazio prima13) salvata, callback e file verificati.
Parametri/moduli del porto stock e mod confrontati anche nei campi annidati: solo name/variant, nessun campo
omesso oltreall'anno. Nodo interno deposito asciutto normale nello script ufficiale, uscita aY-98 in acqua.
Prossima prova: assegnazione esplicita Solar a stop1(Calliano), distinta da0 e nextreachable-1.
Se rifiuta ancora, confronto temporaneo tra due porti vicini per distinguere tratta e accesso deposito.


### 13.10, 20:49 — Solar verso la seconda fermata e revisione statica

PROVATO IN TF3: una sola assegnazione GUI della Solar 123446 alla linea 25246, indice fermata 1 (Calliano), restituisce successo=false. La nave resta in deposito; nessun nuovo acquisto. Il salvataggio separato «capocantiere porto stock due modelli 13-10» conserva lo stato precedente.

SOLO REVISIONE STATICA: confronto indipendente con SDK e GUI ufficiali non identifica un errore dimostrato in createLine/acquisto. Le runways TAKEOFF/LANDING dei porti sono distinte dal nodo del terminale: verificare la loro registrazione. La GUI usa autoAssignTerminals e configura stopConfig; confronto utile, causa ancora non dimostrata. Il selettore modelli non filtra SHIP/SMALL_SHIP per porti piccoli: difetto separato, non causa corrente perché Oita e Solar sono SMALL_SHIP.

Prossimo discriminante: accessi dei due porti; eventuale rotta temporanea tra due porti vicini nella stessa baia usando le navi già acquistate, poi ripristino della rotta originale. Nessuna prova di navigazione riuscita.


### 13.10, 20:53 — prima nave realmente in movimento; discriminante nella baia

PROVATO IN TF3: accessi TAKEOFF/LANDING registrati per porto stock Lissone125886, porto API Lissone120311 e Calliano123906. Tutti i punti esaminati risultano sull'acqua (quota terreno circa -5.75, -2.60 e -4.98 rispettivamente). La prima lettura privata erroneamente trattava i valori della mappa come stazioni singole; nel gioco sono liste. Nessuna assenza di accessi dimostrata.

Sulla linea25246, seconda fermata sostituita temporaneamente con120311, prima125886 invariata: il controllo nativo non segnala percorsi mancanti. Assegnazione Solar123446 stop0 accettata: EN_ROUTE. Ripristinando123906(Calliano) ricompaiono due percorsi mancanti. Tornando120311, controllo senza problemi e Solar in viaggio. Nessun acquisto o costruzione supplementare.

Movimento reale: campioni x=-6232.97,y=-2135.70 e x=-5882.99,y=-2389.01, entrambi velocita'8.33329m/s. Non ancora dimostrato arrivo o servizio completato. Questo esclude un blocco generale di assegnazione, schema linea o uscita deposito nel caso corrente; rimane il corridoio verso Calliano e/o accesso di quel porto.

Copia nuova «capocantiere Solar baia Lissone 13-10»: SAV72974555 byte/JPG652670 byte verificati. Copia precedente «capocantiere porto stock due modelli 13-10» conserva la tratta originale con due navi in deposito. Prima sonda movimento chiamava un namespace inesistente ed e' fallita senza modifiche; corretta usando getter ufficiali api.engine.util.vehicle.getPosition/getSpeed. Nessuna pretesa di tratta interurbana riuscita.


### 13.10, 20:59 — guardia prima dell'acquisto, sviluppo su branch

Guardia in b4 dopo creazione linea, soltanto porti: API nativa deve restituire un segmento per fermata e stati noPath=false. Risposta assente, vuota/incompleta, eccezione o flag non booleano impediscono l'acquisto. Linea, stazioni e deposito restano recuperabili; nessuna demolizione automatica perché b9 conserva risultati con line_id. Aerei invariati. Non risolve corridoio Calliano, deposito o assegnazione.

Test nuovi: primo commit test CI38450986113 fallisce per cinque regressioni attese, confermate nei log; non unito main. Dieci casi dopo implementazione passano nel mock isolato sotto Lua TF3; rimane unico caso preesistente math.maxinteger incompatibile5.2, non dichiarare suite verde. Python locale134 test,0errori/fallimenti,1classeLua saltata. Revisione indipendente senza blocchi; aggiunti tre casi limite richiesti. In attesa CI completa del commit implementazione, non installato.
