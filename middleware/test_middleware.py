"""
Test del middleware senza gioco e senza API (una finta mod e un finto Claude).

    python test_middleware.py
"""

from __future__ import annotations

import os
import shutil
import tempfile
import threading
import time
import types
import unittest
from unittest import mock

import lua_table
from conversation import cached_request, trim_history, validate_args
from game_bridge import GameBridge, find_entities
from tools import TOOLS

TOOL = {t["name"]: t for t in TOOLS}

STATE = {
    "lastActionId": 5, "year": 2300, "noCosts": True,
    "towns": [{"id": 101, "name": "Caprifoglio", "pos": {"x": 0, "y": 0, "z": 10}},
              {"id": 102, "name": "Assalve", "pos": {"x": 3000, "y": 0, "z": 12}}],
    "industries": [], "stations": [], "lines": [], "depots": [],
}


class FakeMod(threading.Thread):
    """Fa la parte della mod: legge actions_<id>_*, scrive results e aggiorna lastActionId."""

    def __init__(self, folder, reply=None):
        super().__init__(daemon=True)
        self.folder, self.stop, self.seen = folder, False, []
        self.reply = reply or (lambda a: {"ok": True, "type": a["type"]})

    def run(self):
        while not self.stop:
            st = lua_table.load_userdata(os.path.join(self.folder, "state.lua"))
            nxt = st["lastActionId"] + 1
            for fn in os.listdir(self.folder):
                if fn.startswith(f"actions_{nxt}_"):
                    req = lua_table.load_userdata(os.path.join(self.folder, fn))
                    self.seen.append(req)
                    os.remove(os.path.join(self.folder, fn))
                    st["lastActionId"] = nxt
                    lua_table.save_userdata(os.path.join(self.folder, "state.lua"), st)
                    res = {"id": nxt, "nonce": req["nonce"], "results": [self.reply(a) for a in req["actions"]]}
                    lua_table.save_userdata(os.path.join(self.folder, f"results_{nxt}_{req['nonce']}.lua"), res)
            time.sleep(0.05)


class Base(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        lua_table.save_userdata(os.path.join(self.dir, "state.lua"), STATE)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)


class TestLuaTable(unittest.TestCase):
    def test_roundtrip(self):
        obj = {"a": [1, 2.5, "x\"y\n"], "b": {"c": True, "d": None}, "nome": "Città", 3: "tre"}
        back = lua_table.loads(lua_table.dumps(obj))
        self.assertEqual(back["a"], [1, 2.5, "x\"y\n"])
        self.assertEqual(back["b"]["c"], True)
        self.assertEqual(back["nome"], "Città")
        self.assertEqual(back[3], "tre")

    def test_game_format(self):
        txt = 'function data()\nreturn { \n\t\tid = 240,\n\t\tlista = { 1, 2, },\n\t\t["k k"] = -3.5,\n\t}\nend\n'
        self.assertEqual(lua_table.loads(txt), {"id": 240, "lista": [1, 2], "k k": -3.5})


class TestValidation(unittest.TestCase):
    def test_ok(self):
        self.assertEqual(validate_args(TOOL["build_rail_line"], {"town_ids": [1, 2], "num_trains": 2}), [])

    def test_errors(self):
        e = validate_args(TOOL["build_rail_line"], {"town_ids": [1], "num_trains": 9})
        self.assertTrue(any("almeno 2" in x for x in e))
        self.assertTrue(any("massimo 6" in x for x in e))
        self.assertTrue(validate_args(TOOL["build_bus_line"], {}))                     # town_id mancante
        self.assertTrue(validate_args(TOOL["build_bus_line"], {"town_id": "101"}))     # tipo sbagliato
        self.assertTrue(validate_args(TOOL["build_bus_line"], {"town_id": True}))      # bool non e' integer
        self.assertTrue(validate_args(TOOL["find_entity"], {"query": "a", "kind": "nave"}))

    def test_extra_fields_ignored(self):
        self.assertEqual(validate_args(TOOL["build_bus_line"], {"town_id": 1, "colore": "rosso"}), [])


class TestHistory(unittest.TestCase):
    def conv(self, n):
        m = []
        for i in range(n):
            m += [{"role": "user", "content": f"ordine {i}"},
                  {"role": "assistant", "content": [{"type": "tool_use", "id": f"t{i}"}]},
                  {"role": "user", "content": [{"type": "tool_result", "tool_use_id": f"t{i}"}]},
                  {"role": "assistant", "content": [{"type": "text", "text": "fatto"}]}]
        return m

    def test_trim(self):
        m = self.conv(10)
        removed = trim_history(m, 3)
        self.assertEqual(removed, 28)
        self.assertEqual(m[0], {"role": "user", "content": "ordine 7"})
        self.assertEqual(len(m), 12)

    def test_no_trim(self):
        m = self.conv(2)
        self.assertEqual(trim_history(m, 3), 0)
        self.assertEqual(len(m), 8)

    def test_cache_does_not_modify(self):
        m = self.conv(1)
        r = cached_request("sistema", TOOLS, m)
        self.assertIn("cache_control", r["tools"][-1])
        self.assertNotIn("cache_control", TOOLS[-1])
        self.assertIn("cache_control", r["messages"][-1]["content"][-1])
        self.assertNotIn("cache_control", m[-1]["content"][-1])
        r2 = cached_request("sistema", TOOLS, [{"role": "user", "content": "ciao"}])
        self.assertEqual(r2["messages"][0]["content"][0]["text"], "ciao")


class TestBridge(Base):
    def test_send(self):
        mod = FakeMod(self.dir)
        mod.start()
        try:
            b = GameBridge(self.dir)
            res = b.send([{"type": "ping"}], timeout=5)
            self.assertEqual(res[0]["ok"], True)
            self.assertEqual(mod.seen[0]["id"], 6)
            self.assertEqual(b.send([{"type": "ping"}], timeout=5)[0]["type"], "ping")
            self.assertEqual(mod.seen[1]["id"], 7)
            self.assertFalse([f for f in os.listdir(self.dir) if f.startswith("results_")])
        finally:
            mod.stop = True

    def test_timeout(self):
        b = GameBridge(self.dir)
        with self.assertRaises(TimeoutError):
            b.send([{"type": "ping"}], timeout=1)

    def test_archive(self):
        for fn in ("actions_241_ab12.lua", "actions_242_cd34.lua", "results_9_ff.lua"):
            with open(os.path.join(self.dir, fn), "w") as f:
                f.write("function data() return {} end")
        moved = GameBridge(self.dir).archive_stale_actions()
        self.assertEqual(moved, ["actions_241_ab12.lua", "actions_242_cd34.lua"])
        self.assertEqual(sorted(os.listdir(os.path.join(self.dir, "vecchi"))), moved)
        self.assertTrue(os.path.exists(os.path.join(self.dir, "results_9_ff.lua")))

    def test_find(self):
        r = find_entities(STATE, "assalve")
        self.assertEqual(r[0]["id"], 102)
        self.assertEqual(find_entities(STATE, "caprif", "town")[0]["id"], 101)


def block(**kw):
    return types.SimpleNamespace(**kw)


class FakeClient:
    """Finto Claude: restituisce in ordine le risposte preparate e registra le richieste."""

    def __init__(self, replies):
        self.replies, self.calls = list(replies), []
        self.messages = types.SimpleNamespace(create=self.create)

    def create(self, **kw):
        self.calls.append(kw)
        return self.replies.pop(0)


class TestAskClaude(Base):
    def test_flow(self):
        import main
        mod = FakeMod(self.dir, reply=lambda a: {"ok": True, "line_id": 999, "type": a["type"]})
        mod.start()
        try:
            client = FakeClient([
                block(stop_reason="tool_use", content=[
                    block(type="tool_use", id="u1", name="find_entity", input={"query": "assalve"})]),
                block(stop_reason="tool_use", content=[
                    block(type="text", text="Costruisco la linea bus."),
                    block(type="tool_use", id="u2", name="build_bus_line", input={"town_id": "102"}),   # sbagliato
                    block(type="tool_use", id="u3", name="build_bus_line", input={"town_id": 102})]),
                block(stop_reason="end_turn", content=[block(type="text", text="Fatto: linea 999.")]),
            ])
            msgs = [{"role": "user", "content": "fammi una linea bus ad Assalve"}]
            with mock.patch.object(main, "confirm", return_value=True), mock.patch("builtins.print"):
                main.ask_claude(client, msgs, GameBridge(self.dir))
            # 1) risultato locale di find_entity
            r1 = msgs[2]["content"][0]
            self.assertIn("102", r1["content"])
            # 2) argomenti sbagliati bloccati prima del gioco; quelli giusti eseguiti
            r2, r3 = msgs[4]["content"]
            self.assertTrue(r2["is_error"])
            self.assertIn("argomenti non validi", r2["content"])
            self.assertFalse(r3["is_error"])
            self.assertIn("999", r3["content"])
            self.assertEqual(len(mod.seen), 1)
            self.assertEqual(mod.seen[0]["actions"][0], {"type": "build_bus_line", "town_id": 102})
            # 3) richieste con prompt caching
            self.assertIn("cache_control", client.calls[0]["system"][0])
            self.assertIn("cache_control", client.calls[0]["tools"][-1])
        finally:
            mod.stop = True

    def test_cancel(self):
        import main
        client = FakeClient([
            block(stop_reason="tool_use", content=[
                block(type="tool_use", id="u1", name="build_bus_line", input={"town_id": 101})]),
            block(stop_reason="end_turn", content=[block(type="text", text="Va bene, annullato.")]),
        ])
        msgs = [{"role": "user", "content": "linea bus a Caprifoglio"}]
        with mock.patch.object(main, "confirm", return_value=False), mock.patch("builtins.print"):
            main.ask_claude(client, msgs, GameBridge(self.dir))
        r = msgs[2]["content"][0]
        self.assertIn("cancelled", r["content"])
        self.assertFalse(r["is_error"])
        self.assertFalse([f for f in os.listdir(self.dir) if f.startswith("actions_")])


class TestJournal(Base):
    def test_record_and_undo(self):
        import json
        import main
        created = {"vehicles": [11, 12], "lines": [5], "constructions": [70], "tracks": [], "roads": [80]}

        def reply(a):
            if a["type"] == "undo":
                return {"ok": True, "type": "undo", "got": a["created"]}
            return {"ok": True, "type": a["type"], "line_id": 5, "created": created}

        mod = FakeMod(self.dir, reply=reply)
        mod.start()
        try:
            with mock.patch.object(main, "confirm", return_value=True), mock.patch("builtins.print"):
                r = main.run_game_tool("build_bus_line", {"town_id": 101}, GameBridge(self.dir))
                self.assertTrue(r["ok"])
                self.assertNotIn("created", r)                       # a Claude non arriva l'elenco
                entries = json.load(open(os.path.join(self.dir, "journal.json"), encoding="utf-8"))
                self.assertEqual(len(entries), 1)
                self.assertEqual(entries[0]["created"]["vehicles"], [11, 12])
                u = main.run_game_tool("undo_last_action", {}, GameBridge(self.dir))
                self.assertTrue(u["ok"])
                self.assertEqual(mod.seen[-1]["actions"][0]["type"], "undo")
                self.assertEqual(mod.seen[-1]["actions"][0]["created"]["constructions"], [70])
                again = main.run_game_tool("undo_last_action", {}, GameBridge(self.dir))
                self.assertFalse(again["ok"])                        # niente altro da annullare
        finally:
            mod.stop = True

    def test_nothing_created_not_recorded(self):
        from journal import Journal
        j = Journal(self.dir)
        self.assertFalse(j.record("ping", {}, {"ok": True}))
        self.assertFalse(j.record("x", {}, {"ok": True, "created": {"vehicles": [], "roads": [3]}}))
        self.assertIsNone(j.last_undoable())

    def test_pause(self):
        import main
        st = dict(STATE, speed=0)
        lua_table.save_userdata(os.path.join(self.dir, "state.lua"), st)
        with mock.patch("builtins.print"):
            r = main.run_game_tool("build_bus_line", {"town_id": 101}, GameBridge(self.dir))
        self.assertFalse(r["ok"])
        self.assertIn("pausa", r["error"])


class TestBozzaTools(unittest.TestCase):
    def test_schemas_and_descriptions(self):
        from tools_bozza import LOCAL_TOOLS_BOZZA, READ_TOOLS_BOZZA, SPENDING_TOOLS_BOZZA, TOOLS_BOZZA, describe_bozza
        names = {t["name"] for t in TOOLS_BOZZA}
        self.assertEqual(names, SPENDING_TOOLS_BOZZA | READ_TOOLS_BOZZA | LOCAL_TOOLS_BOZZA)
        self.assertFalse(SPENDING_TOOLS_BOZZA & READ_TOOLS_BOZZA)
        self.assertFalse(names & set(TOOL))                          # nessun nome doppio con tools.py
        samples = {
            "build_intercity_bus": {"town_ids": [1, 2]}, "connect_station_to_town": {"station_id": 3},
            "add_vehicles": {"line_id": 1, "count": 2}, "remove_vehicles": {"line_id": 1, "count": 1},
            "replace_vehicles": {"line_id": 1}, "delete_line": {"line_id": 1}, "extend_line": {"line_id": 1, "town_id": 2},
            "build_cargo_rail_line": {"industry_id": 1, "target_id": 2}, "build_air_or_water_line": {"town_ids": [1, 2], "kind": "harbor"},
            "build_highway": {"town_ids": [1, 2]}, "undo_last_action": {},
            "build_depot": {"kind": "rail", "station_id": 4},
            "build_rail_line2": {"town_ids": [1, 2, 3], "double_track": True, "express_town_ids": [1, 3]},
            "build_rail_ring": {"town_ids": [1, 2, 3, 4]},
            "build_cargo_rail_network": {"pickup_ids": [5, 6], "delivery_ids": [7]},
            "create_line_from_stations": {"station_ids": [8, 9], "pattern": "ring", "both_directions": True, "cargo": "carbone"},
            "build_rail_station": {"near_id": 5, "kind": "cargo"},
            "check_line": {"line_id": 1}, "check_network": {}, "read_map": {"grid": 8},
            "propose_plan": {"steps": [{"description": "ferrovia A-B", "action": "build_rail_line2"}]},
        }
        for t in TOOLS_BOZZA:
            self.assertEqual(validate_args(t, samples[t["name"]]), [], t["name"])
            if t["name"] in SPENDING_TOOLS_BOZZA:
                self.assertTrue(describe_bozza(t["name"], samples[t["name"]], lambda i: f"#{i}"), t["name"])
        self.assertTrue(validate_args(next(t for t in TOOLS_BOZZA if t["name"] == "build_rail_ring"), {"town_ids": [1, 2]}))
        self.assertTrue(validate_args(next(t for t in TOOLS_BOZZA if t["name"] == "build_depot"), {"kind": "aereo"}))
        self.assertTrue(validate_args(next(t for t in TOOLS_BOZZA if t["name"] == "build_air_or_water_line"),
                                      {"town_ids": [1, 2], "kind": "razzo"}))

    def test_plan_text(self):
        from tools_bozza import format_plan
        txt = format_plan({"title": "Rete", "steps": [{"description": "anello", "action": "build_rail_ring"},
                                                      {"description": "navette"}], "notes": "prima le arterie"})
        self.assertIn("1. anello [build_rail_ring]", txt)
        self.assertIn("2. navette", txt)
        self.assertIn("prima le arterie", txt)


class TestSummary(unittest.TestCase):
    def conv(self, n):
        m = []
        for i in range(n):
            m += [{"role": "user", "content": f"ordine {i}"},
                  {"role": "assistant", "content": [block(type="tool_use", id=f"t{i}", name="build_bus_line", input={"town_id": i})]},
                  {"role": "user", "content": [{"type": "tool_result", "tool_use_id": f"t{i}", "content": '{"ok": true, "line_id": %d}' % (900 + i)}]},
                  {"role": "assistant", "content": [block(type="text", text="fatto")]}]
        return m

    def test_summary_replaces_old_turns(self):
        from conversation import SUMMARY_HEAD, summarize_history
        client = FakeClient([block(content=[block(type="text", text="Costruite linee 900-906.")])])
        m = self.conv(10)
        removed = summarize_history(client, "modello", m, 3)
        self.assertEqual(removed, 28)
        self.assertTrue(m[0]["content"].startswith(SUMMARY_HEAD))
        self.assertIn("900-906", m[0]["content"])
        self.assertEqual(m[1]["role"], "assistant")
        self.assertEqual(m[2], {"role": "user", "content": "ordine 7"})
        sent = client.calls[0]["messages"][0]["content"]
        self.assertIn("[tool build_bus_line", sent)                 # gli oggetti dell'SDK vengono letti
        self.assertIn("900", sent)

    def test_no_summary_when_short(self):
        from conversation import summarize_history
        client = FakeClient([])
        m = self.conv(2)
        self.assertEqual(summarize_history(client, "modello", m, 3), 0)
        self.assertEqual(client.calls, [])

    def test_empty_summary_raises(self):
        from conversation import summarize_history
        client = FakeClient([block(content=[])])
        with self.assertRaises(RuntimeError):
            summarize_history(client, "modello", self.conv(5), 2)


class TestServices(Base):
    def test_action_log(self):
        from action_log import log_action
        p = log_action(self.dir, "build_rail_ring", {"town_ids": [1, 2, 3]},
                       {"ok": False, "error": "spazio", "line_id": 5, "created": {"x": 1},
                        "collaudo": [{"line_id": 5, "ok": False, "problems": ["fermo"]}]}, 12.34)
        import json
        rows = [json.loads(x) for x in open(p, encoding="utf-8")]
        self.assertEqual(rows[0]["action"], "build_rail_ring")
        self.assertEqual(rows[0]["error"], "spazio")
        self.assertEqual(rows[0]["result"]["collaudo"][0]["problems"], ["fermo"])
        self.assertNotIn("created", rows[0]["result"])
        self.assertTrue(p.endswith(".jsonl") and os.sep + "log" + os.sep in p)

    def test_collaudo_with_dates(self):
        from collaudo import Collaudo
        c = Collaudo(self.dir)
        self.assertEqual(c.add([5, 6, None], {"date": {"year": 2300, "month": 11}}), 2)
        self.assertEqual(c.add([5], {"date": {"year": 2300, "month": 11}}), 0)        # gia' in attesa
        self.assertEqual(c.due({"date": {"year": 2300, "month": 12}}), [])
        self.assertEqual(c.due({"date": {"year": 2301, "month": 1}}), [5, 6])
        c.mark_done([5])
        self.assertEqual(c.due({"date": {"year": 2301, "month": 1}}), [6])

    def test_collaudo_wall_fallback(self):
        import collaudo
        c = collaudo.Collaudo(self.dir)
        c.add([7], {}, now=1000.0)
        self.assertEqual(c.due({}, now=1000.0 + 60), [])
        self.assertEqual(c.due({}, now=1000.0 + collaudo.WALL_FALLBACK_S + 1), [7])

    def test_report(self):
        from collaudo import format_report
        txt = format_report({5: {"ok": True, "name": "Anello", "stats": {"itemsTransported": 120}},
                             6: {"ok": False, "problems": ["2 veicoli fermi"], "suggestions": ["segnali"]}, 7: None})
        self.assertIn("Anello (id 5): funziona", txt)
        self.assertIn("PROBLEMI: 2 veicoli fermi", txt)
        self.assertIn("linea 7: controllo non riuscito", txt)

    def test_versions(self):
        from versione import check_versions
        self.assertTrue(any("versione" in m for m in check_versions({}, self.dir)))
        self.assertEqual(check_versions({"modVersion": "a1", "gameBuild": 40408}, self.dir), [])
        msgs = check_versions({"modVersion": "b2", "gameBuild": 40500}, self.dir)
        self.assertTrue(any("40408 -> 40500" in m for m in msgs))
        self.assertTrue(any("a1 -> b2" in m for m in msgs))
        self.assertEqual(check_versions({"modVersion": "b2", "gameBuild": 40500}, self.dir), [])

    def test_plan_answer(self):
        import main
        with mock.patch("builtins.print"):
            with mock.patch("builtins.input", return_value="s"):
                self.assertEqual(main.ask_plan({"steps": [{"description": "x"}]}), {"approved": True})
            with mock.patch("builtins.input", return_value="no"):
                self.assertEqual(main.ask_plan({"steps": [{"description": "x"}]}), {"approved": False})
            with mock.patch("builtins.input", return_value="prima il porto"):
                self.assertEqual(main.ask_plan({"steps": [{"description": "x"}]}), {"approved": False, "feedback": "prima il porto"})

    def test_log_schedule_and_due_checks(self):
        import json
        import main
        st = dict(STATE, date={"year": 2300, "month": 3})
        lua_table.save_userdata(os.path.join(self.dir, "state.lua"), st)

        def reply(a):
            if a["type"] == "check_line":
                return {"ok": False, "line_id": a["line_id"], "name": "Anello", "problems": ["1 veicoli fermi"], "suggestions": []}
            return {"ok": True, "line_id": 41, "line_ids": [41, 42], "created": {"lines": [41, 42]}}

        mod = FakeMod(self.dir, reply=reply)
        mod.start()
        try:
            with mock.patch.object(main, "confirm", return_value=True), mock.patch("builtins.print"):
                r = main.run_game_tool("build_rail_ring", {"town_ids": [101, 102, 103]}, GameBridge(self.dir))
                self.assertTrue(r["ok"])
                logs = os.listdir(os.path.join(self.dir, "log"))
                self.assertEqual(len(logs), 1)
                entries = json.load(open(os.path.join(self.dir, "collaudo.json"), encoding="utf-8"))
                self.assertEqual(sorted(e["line_id"] for e in entries), [41, 42])
                self.assertEqual(main.run_due_checks(GameBridge(self.dir)), "")          # non ancora 2 mesi
                st2 = lua_table.load_userdata(os.path.join(self.dir, "state.lua"))
                st2["date"] = {"year": 2300, "month": 5}
                lua_table.save_userdata(os.path.join(self.dir, "state.lua"), st2)
                note = main.run_due_checks(GameBridge(self.dir))
                self.assertIn("[Collaudo automatico", note)
                self.assertIn("1 veicoli fermi", note)
                self.assertEqual(main.run_due_checks(GameBridge(self.dir)), "")          # gia' fatti
        finally:
            mod.stop = True


if __name__ == "__main__":
    unittest.main(verbosity=2)
