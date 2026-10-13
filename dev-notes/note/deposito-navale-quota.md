# Deposito navale: quota superficie acqua — 13.10.2026

PROVATO IN TF3 sulla copia `capocantiere porto GUI 12-10`, mod v14-bozza-509c3059. Porto precedente 122216 ricaricato. Nessuna modifica al save originale.

Causa riprodotta variando soltanto la quota nello stesso punto della posa GUI valida del 12.10: origine (-7558.78,-1680.23), Y=(0.0670646,0.997749), water_depot.con, parametri e proposta invariati. CC.placeTemplate originale prende terreno=0.0385056: rifiutata, due collisioni. Intercettando CC.heightAt per questo singolo esperimento con valore 2, la stessa funzione riesce: costruzione 123741, deposito 120768, zero stazioni. Non forzati ignoreErrors o collisioni.

Fonte ufficiale locale letta in sola lettura: archivio base/content/depots/water.zip, water/water_depot.script.lua, updateFn. result.snapPoint specifica alignWithCoast=true, forceSnapToWaterSurfaceHeight=true, snapHeightOffsetAboveWater=2.0, waterPoints={{0,-40,0}}. La GUI usa questa quota; la mod usa getHeightAt. Non assumere acqua=0 in ogni mappa: leggere waterLevel reale prima della correzione stabile.

PROVATO IN TF3 senza modifiche: CC.hasPath da CC.depotNodes(120768) al nodo del porto gruppo 115052 con modi {12,13} restituisce true. Questo verifica il percorso, NON il servizio di una nave (nessuna linea o nave ancora creata).

Nuovo salvataggio distinto `capocantiere deposito quota 13-10`, alle 06:39:52 Europe/Zurich: .sav 71138234 byte, .jpg 617676 byte, presenza verificata. Nessun file esistente sovrascritto.

Correzione permanente e test automatici di questa causa ancora da fare. Sonda costruzione e risposte complete conservate privatamente in work della chat; i sorgenti non sono ancora modificati.

### Sorgenti e regressioni

API reale TERRAIN sul mondo: waterLevel=0; makeMapFromGame(false,false,false,false).waterLevel=0 conferma. Anche harbor_modular.script.lua ufficiale usa superficie acqua+2. Fix limitato a CC.placeTemplate per kind=water: quota reale+2, blocco con messaggio fisso se acqua illeggibile/non numerica/non finita; terra resta getHeightAt.

Cinque mock: acqua0, acqua10, terra7, acquaassente, acquaNaN. Prima del codice, CI38347898595 fallisce nello step Mock Lua, Windows passa. Mock con API finta confinata nel runtime TF3: quattro nuovi fallimenti prima, zero nuovi dopo; un caso preesistente math.maxinteger resta fallito (NON suite completamente verde in TF3). Nessuna costruzione reale da questo mock. Runtime Lua Windows esterno ancora assente, non dichiarare mock locale superato. Fix non ancora installato; CI verde e revisione richieste prima del merge.

CI ordinaria38348243694 verde (Ubuntu mock/Lua/Python, WindowsPython). Locale134test,0fallimenti/0errori, una classeLua saltata,16.724s. Revisione sola lettura senza blocchi; correzione unita main84e1118. Sonde reali confermano _VERSION='Lua 5.2', math.maxinteger e math.type assenti: il singolo caso interi del mock5.3/5.4 non e' applicabile a questo runtime; nessun difetto flotta reale dedotto. Fonti b4 e mock normalizzate a LF per evitare differenze dell'intero file dalla copia Windows; nessuna modifica logica aggiuntiva.
