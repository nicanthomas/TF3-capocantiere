# Parser letterali: numeri e separatori — 11.10.2026

Riproduzione su stringhe: 9007199254740993 diventa 9007199254740992 per int(float(v)); - true diventa -1 per negazione del bool Python; {id=1 name='fixture'} accettato senza separatore. Non Lua eseguito, dati reali o file gioco.

Design circoscritto: cifre decimali intere direttamente int prima di float, float solo per frazioni/esponenti e finito; meno separato soltanto davanti a token numerico; dopo ogni campo table richiedere virgola/punto e virgola o chiusura. Conservare hex, negativi, frazioni/esponenti finiti, underflow a zero, tabelle annidate e separatori finali. Parser subset Python, nessuna promessa di modello numerico Lua C++ o grammatica generale.

Cinque regressioni prima del codice: esattezza vicino 2^53 e limiti int64, meno non numerico, non finiti, separatori mancanti, formati validi. RED locale/CI, poi minima implementazione, GREEN/revisione e merge dopo verifica main. Backup privato prima dei file esistenti; nessuna installazione/chiave/bridge vivo.

RED locale: 109 test, 11 fallimenti/3 errori (subcase), 1 classe Lua skip, 16,354 s. Interi arrotondati, non finiti/separatori/booleani erroneamente accettati; meno di nil/table/string genera TypeError invece di LuaParseError. Formati validi passano, codice produttivo invariato.

RED CI 38138543778: Ubuntu 123 test/11 fallimenti/3 errori/1 skip Windows, 14,147 s; Windows 109/11 fallimenti/3 errori/1 classe Lua skip, 14,264 s. Solo dopo RED applicate correzioni circoscritte; GREEN/revisione prima integrazione.

Locale GREEN 109 test OK/1 classe Lua skip, 16,283 s. Revisione statica senza blocchi, limiti modello numerico Python distinti da runtime Lua C++. CI GREEN 38138777270: Ubuntu 123 test/1 skip Windows, 14,008 s; Windows 109/1 classe Lua skip, 14,385 s; mock normale 104/0. Main verificato prima integrazione, mod e dati reali invariati.
