# Screenshot GDI: errori e risorse - 11.10.2026

Riproduzione solo backend simulato, nessuna DLL o finestra reale: SelectObject ripristino restituisce zero, capture procede a GetDIBits e produce BMP; DeleteObject prima DeleteDC fallisce con bitmap ancora selezionata, risorsa rimane allocata nel modello.

Design circoscritto: verificare il ripristino prima lettura (NULL/HGDI_ERROR => ControlError); nel finally rilasciare DC memoria prima bitmap anche quando il secondo tentativo di deselect fallisce, poi ReleaseDC finestra. Nessuna modifica focus/input, selezione target, formato BMP o gioco. Non garantisce recupero se DeleteDC/DeleteObject/ReleaseDC stessi falliscono; simula ritorni delle API e verifica tentativi/ordine, non prova ogni driver Windows.

Tre regressioni prima codice: BMP top-down/handle grandi/lettura dopo deselect/rilascio; guasti allocazione/selezione/PrintWindow/lettura/ripristino in cleanup; ripristino zero/HGDI_ERROR blocca lettura e libera bitmap selezionata. Backup privato. RED prima fix, revisione e CI prima merge.

Fonti Microsoft: [GetDIBits](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getdibits) richiede bitmap non selezionata; [DeleteObject](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-deleteobject) fallisce se oggetto selezionato; [DeleteDC](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-deletedc) per DC creato, ReleaseDC per quello finestra.

RED locale: 119 test/3 fallimenti/1 classe Lua skip, 16,324 s; due ripristini accettati e bitmap rimasta in cleanup dopo PrintWindow+restore guasti.

RED CI 38139758423 confermato: Ubuntu 133/3 fallimenti/1 skip Windows, Windows 119/3 fallimenti/1 classe Lua skip. Solo dopo RED modifica minima restore e cleanup.

Locale GREEN 119 OK/1 classe Lua skip, 16,280 s; CI e revisione prima merge.
