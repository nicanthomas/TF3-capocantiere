"""
Compone lo script della mod da dev-notes/cc_lib.lua + dev-notes/cc_actions.lua.

Lo script della mod (mod/.../capocantiere.script.lua) contiene una copia dei due file tra i marcatori
    -- ===...=== CC sim library      (prima riga di cc_lib.lua)
    -- ===...=== fine azioni         (ultima riga di cc_actions.lua)
Questo script sostituisce quella parte con il contenuto attuale dei due file e lascia invariato il resto.

Uso (dalla cartella del progetto):
    python dev-notes/build_script.py            # scrive lo script aggiornato
    python dev-notes/build_script.py --check    # controlla soltanto che lo script sia gia' allineato (codice 1 se no)
    python dev-notes/build_script.py --bozza    # include anche dev-notes/bozza/b*.lua (azioni NON ancora provate) e le
                                          # modifiche al lato interfaccia della v14 (vedi GUI_PATCHES)
    python dev-notes/build_script.py --release [--bozza]
                                          # versione DA DISTRIBUIRE: copia della mod in dist/tfcapocantiere_1 con
                                          # DEV_MODE = false (niente lua_eval/sim_eval) e zip dist/tfcapocantiere_1.zip;
                                          # la mod di sviluppo in mod/ resta com'e' (DEV_MODE = true per le prove)

Prima di scrivere fa una copia di backup dello script (capocantiere.script.lua.bak_<data>) e
controlla la sintassi Lua del risultato se sul sistema c'e' liblua (vedi luachk.py).

Numero di versione: lo script riceve la riga  local CC_VERSION = "..."  (v14 + "bozza-" se c'e' la bozza + le prime
8 cifre dell'impronta SHA-1 del codice composto). Con la bozza la versione finisce anche in state.lua (modVersion),
cosi' il middleware sa quale mod sta girando.
"""

from __future__ import annotations

import datetime
import glob
import hashlib
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "dev-notes", "cc_lib.lua")
ACT = os.path.join(ROOT, "dev-notes", "cc_actions.lua")
SCRIPT = os.path.join(ROOT, "mod", "tfcapocantiere_1", "content", "capocantiere", "capocantiere.script.lua")

START = "CC sim library"
END = "fine azioni"
BOZZA = sorted(glob.glob(os.path.join(ROOT, "dev-notes", "bozza", "b[0-9]_*.lua")))

# Modifiche al lato interfaccia dello script (fuori dai marcatori) per la v14. Idempotenti: (testo da cercare,
# testo nuovo, segno che la modifica c'e' gia').
GUI_PATCHES = [
    # velocita' del gioco in state.lua (0 = pausa): il middleware avvisa invece di aspettare 5 minuti
    ("\tif okY then s.year = year end\n",
     "\tif okY then s.year = year end\n"
     "\tpcall(function() s.speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup end)\n",
     "s.speed = "),
    # ogni azione che non e' gestita dall'interfaccia passa al lato simulazione (azioni nuove senza toccare SIM_TYPES)
    ("\t\tif type(a) == \"table\" and SIM_TYPES[a.type] then\n",
     "\t\tif type(a) == \"table\" and (SIM_TYPES[a.type] or (a.type and not handlers[a.type])) then\n",
     "not handlers[a.type]"),
    # versione della mod, tempo di gioco (collaudo dopo 1-2 mesi) e build del gioco in state.lua.
    # date e gameBuild: DA VERIFICARE in gioco (se le funzioni non esistono restano vuoti, senza errori)
    ("\tif okY then s.year = year end\n",
     "\tif okY then s.year = year end\n"
     "\ts.modVersion = CC_VERSION\n"
     "\tpcall(function() s.gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime end)\n"
     "\tpcall(function() local d = game.interface.getGameTime().date; s.date = { year = d.year, month = d.month, day = d.day } end)\n"
     "\tpcall(function() s.gameBuild = api.util.getBuildVersion() end)\n",
     "s.modVersion = CC_VERSION"),
    # state.lua su mappe grandi: se l'esportazione e' lenta, la si fa piu' di rado (10-60 s, 100 volte la sua durata)
    ("\tif not g.lastExport or now - g.lastExport >= EXPORT_INTERVAL then\n",
     "\tif not g.lastExport or now - g.lastExport >= (g.exportInterval or EXPORT_INTERVAL) then\n",
     "(g.exportInterval or EXPORT_INTERVAL)"),
    ("\t\tlocal ok, st, dt = pcall(exportState)\n",
     "\t\tlocal ok, st, dt = pcall(exportState)\n"
     "\t\tif ok and dt then g.exportInterval = math.max(EXPORT_INTERVAL, math.min(60, math.floor(dt * 100))) end\n",
     "g.exportInterval = math.max"),
    # riprendere il gioco dal middleware
    ("handlers.ping = function(a)\n",
     "handlers.set_speed = function(a)\n"
     "\tapi.cmd.sendCommand(api.cmd.makeGameSetSpeedCmd(tonumber(a.speed) or 1))\n"
     "\treturn { ok = true }\n"
     "end\n\n"
     "handlers.ping = function(a)\n",
     "handlers.set_speed"),
]


def read(p: str) -> str:
    with open(p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def marker_line_start(text: str, marker: str) -> int:
    """Inizio della riga di commento '-- ===... <marker>'."""
    i = text.find(marker)
    if i < 0:
        raise SystemExit(f"marcatore '{marker}' non trovato")
    return text.rfind("\n", 0, i) + 1


def marker_line_end(text: str, marker: str) -> int:
    """Fine (dopo il ritorno a capo) della riga che contiene il marcatore."""
    i = text.find(marker)
    if i < 0:
        raise SystemExit(f"marcatore '{marker}' non trovato")
    j = text.find("\n", i)
    return len(text) if j < 0 else j + 1


def compose(bozza: bool = False) -> tuple[str, str]:
    lib, act, old = read(LIB), read(ACT), read(SCRIPT)
    if START not in lib.splitlines()[0]:
        raise SystemExit("cc_lib.lua non inizia con il marcatore 'CC sim library'")
    if END not in act.rstrip("\n").splitlines()[-1]:
        raise SystemExit("cc_actions.lua non finisce con il marcatore 'fine azioni'")
    if bozza:
        # la bozza va prima dell'ultima riga di cc_actions (il marcatore 'fine azioni'), cosi' resta tra i marcatori
        body = act.rstrip("\n")
        cut = body.rfind("\n") + 1
        act = body[:cut] + "".join(read(p) for p in BOZZA) + body[cut:] + "\n"
    a = marker_line_start(old, START)
    b = marker_line_end(old, END)
    new = old[:a] + lib + act + old[b:]
    new = set_version(new, version_of(lib + act, bozza))
    if bozza:
        for find, repl, done in GUI_PATCHES:
            if done in new:
                continue
            if new.count(find) != 1:
                raise SystemExit("punto di modifica non trovato nello script: " + find.strip()[:60])
            new = new.replace(find, repl)
    return old, new


def version_of(code: str, bozza: bool) -> str:
    """Versione deterministica: stessa composizione = stessa versione (cosi' --check resta affidabile)."""
    return "v14-" + ("bozza-" if bozza else "") + hashlib.sha1(code.encode("utf-8")).hexdigest()[:8]


def set_version(script: str, version: str) -> str:
    """Scrive (o aggiorna) la riga 'local CC_VERSION = ...' subito dopo 'local STATE_VERSION = ...'."""
    line = f'local CC_VERSION = "{version}"'
    if re.search(r'^local CC_VERSION = ".*"$', script, flags=re.M):
        return re.sub(r'^local CC_VERSION = ".*"$', line, script, count=1, flags=re.M)
    m = re.search(r"^local STATE_VERSION = .*$", script, flags=re.M)
    if not m:
        raise SystemExit("riga 'local STATE_VERSION' non trovata: non so dove scrivere la versione")
    return script[:m.end()] + "\n" + line + script[m.end():]


def lua_syntax_ok(code: str) -> tuple[bool, str]:
    libs = glob.glob("/usr/lib/x86_64-linux-gnu/liblua5.*.so*") + glob.glob("/usr/lib/liblua5.*.so*")
    if not libs:
        return True, "liblua non trovata: controllo sintassi saltato"
    import ctypes
    lua = ctypes.CDLL(sorted(libs)[-1])
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    L = lua.luaL_newstate()
    b = code.encode("utf-8")
    r = lua.luaL_loadbufferx(L, b, len(b), b"capocantiere.script", b"t")
    return r == 0, "" if r == 0 else lua.lua_tolstring(L, -1, None).decode("utf-8", "replace")


DIST = os.path.join(ROOT, "dist")
MOD_DIR = os.path.join(ROOT, "mod", "tfcapocantiere_1")


def release(code: str) -> int:
    """Scrive la versione da distribuire in dist/ (DEV_MODE = false) e la comprime; non tocca mod/."""
    rel, n = re.subn(r"^local DEV_MODE = true", "local DEV_MODE = false", code, flags=re.M)
    if n != 1:
        print("ERRORE: riga 'local DEV_MODE = true' non trovata (o trovata piu' volte):", n)
        return 3
    ok, msg = lua_syntax_ok(rel)
    if not ok:
        print("ERRORE di sintassi Lua nella versione da distribuire:", msg)
        return 2
    out = os.path.join(DIST, "tfcapocantiere_1")
    if os.path.exists(out):
        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        shutil.move(out, out + ".bak_" + stamp)
    shutil.copytree(MOD_DIR, out, ignore=shutil.ignore_patterns("*.bak_*"))
    target = os.path.join(out, os.path.relpath(SCRIPT, MOD_DIR))
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(rel)
    zipped = shutil.make_archive(os.path.join(DIST, "tfcapocantiere_1"), "zip", DIST, "tfcapocantiere_1")
    v = re.search(r'^local CC_VERSION = "(.*)"$', rel, flags=re.M)
    print("Versione da distribuire:", v.group(1) if v else "?", "- DEV_MODE = false")
    print("Cartella:", out)
    print("Zip:", zipped)
    return 0


def main() -> int:
    old, new = compose("--bozza" in sys.argv)
    ok, msg = lua_syntax_ok(new)
    if not ok:
        print("ERRORE di sintassi Lua:", msg)
        return 2
    if msg:
        print(msg)
    if "--release" in sys.argv:
        return release(new)
    if "--check" in sys.argv:
        if old == new:
            print("OK: lo script della mod e' allineato a cc_lib.lua + cc_actions.lua")
            return 0
        print("DIVERSO: lo script della mod non e' allineato (esegui senza --check)")
        return 1
    if old == new:
        print("Nessuna modifica: lo script e' gia' allineato")
        return 0
    v = re.search(r'^local CC_VERSION = "(.*)"$', new, flags=re.M)
    print("Versione della mod:", v.group(1) if v else "?")
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    shutil.copy2(SCRIPT, SCRIPT + ".bak_" + stamp)
    with open(SCRIPT, "w", encoding="utf-8", newline="") as f:
        f.write(new)
    print(f"Script aggiornato ({len(new)} caratteri); backup: capocantiere.script.lua.bak_{stamp}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
