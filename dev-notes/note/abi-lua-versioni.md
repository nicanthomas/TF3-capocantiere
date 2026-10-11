# Barriera minima API Lua — 11.10.2026

Il wrapper dev-notes/lua_runtime.py supporta il contratto Lua 5.3/5.4 ma configurava solo simboli comuni anche a 5.2. lua_pcallk ha inoltre contesto int in 5.2, lua_KContext in 5.3: non trattare gli stessi nomi come prova di ABI uguale. Header ufficiali: [Lua 5.2](https://www.lua.org/source/5.2/lua.h.html), [Lua 5.3](https://www.lua.org/source/5.3/lua.h.html). Lua 5.3 introduce lua_isinteger, assente in 5.2.

Design minimo: richiedere anche lua_isinteger nel contratto ctypes (lua_State*, int -> int), senza chiamarlo; una libreria senza l'export viene rifiutata da configure prima di creare uno stato. Nuova regressione usa interamente ABI simulata con i vecchi simboli ma senza lua_isinteger, verificando nessuna allocazione/caricamento/esecuzione/chiusura. Prima RED locale/CI, poi una riga nella lista firme, GREEN locale/CI nativa/revisione e merge.

Questa barriera esclude standard 5.2 e runtime senza sottotipo intero; non certifica provenienza/architettura/versione esatta o sicurezza di un binario, e non promette supporto Lua 5.5/future/custom. Rimane obbligatorio percorso assoluto a DLL fidata stessa architettura Python; nessuna ricerca/cartella gioco o installazione autorizzata. Nessuna DLL nuova caricata durante i test simulati.

## RED locale

Runner isolato: 81 test, 1 fallimento (LuaUnavailable non sollevata), 1 classe Lua skip; 15,906 s. Il runtime produttivo ancora invariato accetta la libreria simulata senza export interi. Nessuna DLL reale usata nella regressione. Checkpoint RED prima della correzione.

## RED CI e guardia

RED CI 38134872906: Ubuntu 95 test/1 fallimento/1 skip Windows, 13,920 s; Windows 81/1 fallimento/1 classe Lua skip, 14,315 s. Stesso difetto del locale: LuaUnavailable non sollevata. Solo dopo la prova aggiunta come prima firma configure lua_isinteger (lua_State*, int -> int); nessuna invocazione, tutti i simboli controllati prima di luaL_newstate. La regressione simula gli export vecchi, non carica davvero Lua 5.2. GREEN/revisione in attesa.
