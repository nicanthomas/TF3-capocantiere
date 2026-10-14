"""Cache del bridge con file temporanei: nessun gioco o chiamata al modello."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import game_bridge
import lua_table


class BridgeStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name) / "mod_presets"
        self.folder.mkdir()
        self.path = self.folder / "capocantiere_state.lua"
        lua_table.save_userdata(str(self.path), {"lastActionId": 5})
        self.bridge = game_bridge.GameBridge(str(self.folder))

    def truncate_state(self):
        stamp = self.path.stat().st_mtime + 2
        self.path.write_text("function data() return {lastActionId =", encoding="utf-8")
        os.utime(self.path, (stamp, stamp))
        return stamp

    def test_failed_refresh_does_not_return_old_state_or_mark_it_current(self):
        before = self.bridge.state()
        stamp = self.bridge._state_mtime
        self.truncate_state()
        with patch.object(game_bridge.time, "sleep"), self.assertRaises(lua_table.LuaParseError):
            self.bridge.state()
        self.assertIs(self.bridge._state, before)
        self.assertEqual(self.bridge._state_mtime, stamp)

    def test_first_failed_read_raises_instead_of_returning_none(self):
        self.truncate_state()
        with patch.object(game_bridge.time, "sleep"), self.assertRaises(lua_table.LuaParseError):
            self.bridge.state()
        self.assertIsNone(self.bridge._state)
        self.assertEqual(self.bridge._state_mtime, 0)

    def test_repaired_file_with_same_failed_stamp_is_read_again(self):
        self.bridge.state()
        stamp = self.truncate_state()
        with patch.object(game_bridge.time, "sleep"):
            try:
                self.bridge.state()
            except lua_table.LuaParseError:
                pass
        lua_table.save_userdata(str(self.path), {"lastActionId": 6})
        os.utime(self.path, (stamp, stamp))
        self.assertEqual(self.bridge.state()["lastActionId"], 6)

    def test_send_does_not_publish_using_cached_id_after_failed_refresh(self):
        self.bridge.state()
        self.truncate_state()
        with patch.object(game_bridge.time, "sleep"), self.assertRaises(lua_table.LuaParseError):
            self.bridge.send([{"type": "ping"}], timeout=0)
        self.assertEqual(list(self.folder.glob("capocantiere_actions_*.lua")), [])
        self.assertFalse((self.folder / "capocantiere_vecchi").exists())

    def test_transient_truncation_recovers_on_next_attempt(self):
        self.bridge.state()
        stamp = self.truncate_state()
        def repair(_):
            lua_table.save_userdata(str(self.path), {"lastActionId": 6})
            os.utime(self.path, (stamp, stamp))
        with patch.object(game_bridge.time, "sleep", side_effect=repair):
            state = self.bridge.state()
        self.assertEqual(state["lastActionId"], 6)
        self.assertEqual(self.bridge._state_mtime, stamp)
