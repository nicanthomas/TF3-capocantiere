# Parser userdata completo — 11.10.2026

Problema riprodotto sui soli testi fixture: loads ignora nomi/keyword del wrapper, end assente e token dopo il primo valore. Non esegue Lua, ma puo' presentare un file malformato come stato valido. Correzione circoscritta: richiedere function data() return valore end esatto e consumare tutti i token; mantenere tabella/valore nudo, return valore, commenti e formato dumps. Nessun file gioco o dato reale letto, nessuna installazione. Non affermare che sia un parser Lua generale.

Quattro regressioni prima del codice: wrapper errato, end assente, contenuto residuo, formati validi invariati. RED locale/CI prima dell'implementazione, poi GREEN/revisione e merge dopo controllo main remoto. Sonda bridge standalone rimandata al parser corretto.

RED locale: 97 test/7 fallimenti/1 classe Lua skip, 16,144 s. Tutti i fallimenti sono LuaParseError non sollevato sui file malformati; formati validi passano. Parser produttivo ancora invariato.

RED CI 38137476301 confermato: Ubuntu 111 test/7 fallimenti/1 skip Windows, 14,060 s; Windows 97/7 fallimenti/1 classe Lua skip, 14,200 s. Solo dopo RED richiesti keyword esatti e consumo documento completo. GREEN/revisione in attesa.

Locale GREEN: 97 test OK/1 classe Lua skip, 16,133 s. Revisione statica indipendente senza blocchi; subset non grammatica Lua generale, terminatori statement/formati alternativi esclusi. CI GREEN in attesa.

GREEN CI 38137669139: Ubuntu 111 test/1 skip Windows, 14,299 s; Windows 97/1 classe Lua skip, 14,309 s; mock normale 104/0. Revisione senza blocchi e locale 97 OK. Avviso build DIVERSO conservato, mod invariata; integrazione dopo controllo main remoto. Nessuna prova userdata reale TF3.
