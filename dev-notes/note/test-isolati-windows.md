# Suite Windows isolata

Runner dev-notes/strumenti/test_isolati.py: venv esistente, -I -B, --fixtures-root con cartella artefatti autorizzata fuori da Steam/dati gioco. Solo stdlib, nessuna installazione. Ogni giro crea fixtures uniche.
In PowerShell, sostituire i percorsi segnaposto:

    $tf3VenvPython = 'PERCORSO_VENV\Scripts\python.exe'
    $tf3Fixtures = 'CARTELLA_ARTEFATTI_AUTORIZZATA'
    & $tf3VenvPython -I -B E:\Sviluppo\TF3-capocantiere\dev-notes\strumenti\test_isolati.py --fixtures-root $tf3Fixtures

Audit Python controlla scritture/modifiche/rinomine nelle nuove fixtures (entrambi gli estremi), blocca accessi Steam, rete e processi esterni previsti. Ricerca automatica Steam disabilitata, chiave Anthropic assegnata vuota nel solo processo figlio senza leggere quella reale. JSON espone errori/fallimenti, skip e motivi, destinazioni delle scritture tentate.
Non e' un sandbox OS per codice nativo/ostile: solo test revisionati e DLL fidate. La suite non invia input nativi al desktop. Senza DLL Windows la classe Lua reale e' skip, non test superato. Ubuntu CI impone CAPOCANTIERE_REQUIRE_LUA=1 per vietare skip da runtime mancante.
Verifica locale 10.10.2026: 72 test OK, zero errori/fallimenti, una classe Lua skip per DLL mancante, 14,681 s. Otto regressioni policy. Venv/fixtures nell'area work autorizzata, nessun dato gioco usato/modificato.
