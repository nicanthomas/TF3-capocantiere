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
        from tools_bozza import SPENDING_TOOLS_BOZZA, TOOLS_BOZZA, describe_bozza
        names = {t["name"] for t in TOOLS_BOZZA}
        self.assertEqual(names, SPENDING_TOOLS_BOZZA)
        self.assertFalse(names & set(TOOL))                          # nessun nome doppio con tools.py
        samples = {
            "build_intercity_bus": {"town_ids": [1, 2]}, "connect_station_to_town": {"station_id": 3},
            "add_vehicles": {"line_id": 1, "count": 2}, "remove_vehicles": {"line_id": 1, "count": 1},
            "replace_vehicles": {"line_id": 1}, "delete_line": {"line_id": 1}, "extend_line": {"line_id": 1, "town_id": 2},
            "build_cargo_rail_line": {"industry_id": 1, "target_id": 2}, "build_air_or_water_line": {"town_ids": [1, 2], "kind": "harbor"},
            "build_highway": {"town_ids": [1, 2]}, "undo_last_action": {},
        }
        for t in TOOLS_BOZZA:
            self.assertEqual(validate_args(t, samples[t["name"]]), [], t["name"])
            self.assertTrue(describe_bozza(t["name"], samples[t["name"]], lambda i: f"#{i}"), t["name"])
        self.assertTrue(validate_args(next(t for t in TOOLS_BOZZA if t["name"] == "build_air_or_water_line"),
                                      {"town_ids": [1, 2], "kind": "razzo"}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
