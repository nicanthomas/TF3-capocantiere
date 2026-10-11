# Diagnosi statica DLL Lua Windows — 11.10.2026

Obiettivo: preparare la configurazione nativa senza installazioni o caricamenti DLL. Nuovo tool lua_windows_diagnosi.py, solo stdlib: legge header PE dell'eseguibile Python corrente e, soltanto con --library e percorso assoluto esplicito autorizzato, della DLL candidata. Non legge variabili ambiente, non fa ricerche, non usa CDLL/LoadLibrary, non modifica file e non stampa percorsi privati. Senza argomento nessun candidato ispezionato.

Formato documentato da [Microsoft PE Format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format): machine I386/AMD64/ARM64, firma PE, flag executable/DLL e magic PE32/PE32+. Stessa bitness non basta: AMD64 e ARM64 sono distinti. Header troncati/incoerenti/non DLL o offset PE oltre limite diagnostico 1 MiB vengono rifiutati prima di grandi letture. Letture bounded degli header, non del contenuto intero.

Output JSON: Windows/process bits, macchina Python, candidato esplicito o assente, macchina/bitness candidata e architecture_matches; runtime_loaded=false sempre. Compatibilita' header NON certifica versione Lua, export, dipendenze, codice o provenienza del binario. Macchine ibride/custom non supportate vanno indicate come non diagnosticate, senza indovinare.

Piano: nove regressioni fixture prima del codice (macchine note, mismatch anche 64/64, DLL flag, file relativo, DOS/PE/troncamento, magic incoerente/machine ignota, bounded read, default senza candidato, CLI errore JSON senza percorso). RED locale/CI, implementazione minima, GREEN/revisione, poi esecuzione locale senza --library: sola lettura Python.exe e nessuna DLL reale. Installazioni ancora richiedono autorizzazione.

## RED locale

Nove test nuovi, 90 test di suite/22 errori (subtest inclusi) da module/funzioni mancanti, una classe Lua skip. Firma della fixture PE corretta/verificata come P E NUL NUL prima del codice produttivo. Il tool resta assente: checkpoint RED prima dell'implementazione.

## RED CI e implementazione

RED CI 38135486992 confermato: module/funzioni mancanti, come nel locale isolato corretto (90 test/22 errori, 1 classe Lua skip, 16,069 s). Solo dopo RED creato il tool. Parser legge 64/24/2 byte di header e usa dimensione file senza leggerne contenuto; limite diagnostico offset 1 MiB e controllo SizeOfOptionalHeader/magic. Default non legge ambiente/candidato. Errori CLI fissi senza percorso/eccezione OS raw. GREEN e revisione in attesa.
