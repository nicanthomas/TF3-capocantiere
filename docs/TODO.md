# Da fare

- [ ] Verificare in gioco il flusso completo file azione → mod → risultato con lo script nuovo
      (serve ricaricare la partita) e una prima sessione con `main.py`.
- [x] Ferrovia passeggeri tra citta' (provata nel 1900).
- [x] Ponti, gallerie e pendenza massima 2,5% (provati: Camomilla-Allegrezze, lago + collina).
- [ ] Test in partita avviata in epoca tarda: tram elettrici (deposito con catenaria), alta velocita' + passaggi a livello.
- [ ] Pulizia automatica anche per il tram quando l'azione fallisce.
- [ ] Merci in treno.
- [ ] `DEV_MODE = false` per l'uso normale; eventuale pulizia delle funzioni di sola diagnosi.
- [ ] Unificare: lo script della mod contiene una copia di `dev/cc_lib.lua` e `dev/cc_actions.lua`
      (oggi incollate tra i marcatori `CC sim library` e `fine azioni`); valutare un passo di build.
- [x] Linea a 3 citta' (Lanusei - Castelfracci - San Pietro), sovrappassi/sottopassi, deviazioni laterali, scelta
      di stazioni in piano.
- [x] Stazioni a 2 binari con scambi: piu' treni sulla stessa linea (provato nel 1900, costruito nel 2300).
- [ ] Prima sessione completa dalla console (`main.py`) con una direttiva vera.
- [ ] Treni merci.
- [x] Verifica 2300: treni (standard + catenaria, deposito elettrificato), tram elettrico, bus, merci su strada.
- [ ] Rivedere in movimento i veicoli nel 2300 (crash della partita prima della verifica, vedi scoperte-api).
