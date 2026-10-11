# Descrizioni dei dati facoltativi — 11.10.2026

Passo circoscritto autorizzato nello sviluppo autonomo: allineare soltanto descrizioni read_map/check_line_fleet e SYSTEM_PROMPT_BOZZA ai campi gia' implementati nei sorgenti. Schemi input, insiemi tool, conferme, routing e Lua invariati. Non aggiungere test che copiano il testo; eseguire suite isolata/CI esistente e revisione delle descrizioni rispetto agli adattatori.

Produttivita': tre booleani, false esplicito distinto da campi assenti/available=false; nessun moltiplicatore o causa dedotta. Qualita': due rami con available/errors propri, disponibile globale non garantisce entrambi; averageQuality senza unita'/range noti, bad_fraction rapporto di conteggi e non ritardo. Mod precedenti possono omettere i dati; nessuna deduzione automatica buono/cattivo, acquisto o costruzione. I campi restano NON provati su userdata C++ TF3.

Backup privato dei file preesistenti prima della modifica. Nessuna chiamata al modello, chiave, gioco, bridge vivo o installazione. GREEN locale/CI e revisione in attesa prima del merge.

Locale isolato: 90 test OK, zero errori/fallimenti, una classe Lua skip per DLL fidata assente, 16,120 s. CI e revisione ancora in attesa.
