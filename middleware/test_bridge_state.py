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
        with patch.object(game_bridge.time, "sleep"), self.assertRaisesRegex(RuntimeError, "state.lua non leggibile"):
            self.bridge.state()
        self.assertIs(self.bridge._state, before)
        self.assertEqual(self.bridge._state_mtime, stamp)

    def test_first_failed_read_raises_instead_of_returning_none(self):
        self.truncate_state()
        with patch.object(game_bridge.time, "sleep"), self.assertRaisesRegex(RuntimeError, "state.lua non leggibile"):
            self.bridge.state()
        self.assertIsNone(self.bridge._state)
        self.assertEqual(self.bridge._state_mtime, 0)

    def test_repaired_file_with_same_failed_stamp_is_read_again(self):
        self.bridge.state()
        stamp = self.truncate_state()
        with patch.object(game_bridge.time, "sleep"):
            try:
                self.bridge.state()
            except RuntimeError:
                pass
        lua_table.save_userdata(str(self.path), {"lastActionId": 6})
        os.utime(self.path, (stamp, stamp))
        self.assertEqual(self.bridge.state()["lastActionId"], 6)

    def test_send_does_not_publish_using_cached_id_after_failed_refresh(self):
        self.bridge.state()
        self.truncate_state()
        with patch.object(game_bridge.time, "sleep"), self.assertRaisesRegex(RuntimeError, "state.lua non leggibile"):
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

    def timeout_with_broken_state(self):
        real_save = lua_table.save_userdata
        def send_then_truncate(path, value):
            real_save(path, value)
            if Path(path).name.startswith("capocantiere_actions_"):
                self.truncate_state()
        with patch.object(game_bridge.time, "sleep"), \
                patch.object(lua_table, "save_userdata", side_effect=send_then_truncate):
            with self.assertRaises(game_bridge.GameTimeout) as caught:
                self.bridge.send([{"type": "ping"}], timeout=0)
        return caught.exception

    def test_timeout_unreadable_state_is_unknown_not_safe_to_retry(self):
        error = self.timeout_with_broken_state()
        self.assertEqual(error.status, "sconosciuta")
        self.assertIn("NON ripeterla", str(error))
        self.assertEqual(error.req_id, 6)
        self.assertIn(6, self.bridge.late)
        self.assertEqual(list(self.folder.glob("capocantiere_actions_*.lua")), [])

    def test_unreadable_recheck_after_withdrawal_is_not_safe_to_retry(self):
        real_withdraw = self.bridge._withdraw
        def withdraw_then_truncate(req_id, nonce=None):
            result = real_withdraw(req_id, nonce)
            if nonce is not None:
                self.truncate_state()
            return result
        with patch.object(game_bridge.time, "sleep"), \
                patch.object(self.bridge, "_withdraw", side_effect=withdraw_then_truncate):
            with self.assertRaises(game_bridge.GameTimeout) as caught:
                self.bridge.send([{"type": "ping"}], timeout=0)
        self.assertEqual(caught.exception.status, "sconosciuta")
        self.assertIn(6, self.bridge.late)

    def test_unknown_pending_request_blocks_same_id_reuse(self):
        self.bridge.late[6] = "abcd"
        with patch.object(game_bridge.time, "sleep"), \
                self.assertRaises(game_bridge.GameTimeout) as caught:
            self.bridge.send([{"type": "ping"}], timeout=0)
        self.assertEqual(caught.exception.status, "sconosciuta")
        self.assertEqual(self.bridge.late, {6: "abcd"})
        self.assertEqual(list(self.folder.glob("capocantiere_actions_*.lua")), [])
        self.assertFalse((self.folder / "capocantiere_vecchi").exists())

    def test_unknown_request_keeps_late_result_correlation(self):
        import main
        with patch.dict(main.LATE_INFO, {}, clear=True), \
                patch.object(self.bridge, "send", side_effect=game_bridge.GameTimeout(
                    "Esito sconosciuto; NON ripeterla", 6, "sconosciuta")):
            result = main.run_game_tool("check_line", {"line_id": 7}, self.bridge)
            self.assertEqual(result["request_status"], "sconosciuta")
            self.assertEqual(main.LATE_INFO[6], ("check_line", {"line_id": 7}))

    def test_acceptance_missing_or_invalid_id_is_unknown(self):
        for value in (None, True, -1, 5.5, "6"):
            with self.subTest(value=value):
                lua_table.save_userdata(str(self.path), {"lastActionId": value})
                self.bridge._state = None
                self.assertIsNone(self.bridge._accepted(6))

    def test_pending_guard_does_not_replace_original_tool_metadata(self):
        import main
        original = ("build_bus_line", {"town_id": 101})
        self.bridge.late[6] = "abcd"
        with patch.dict(main.LATE_INFO, {6: original}, clear=True):
            result = main.run_game_tool("check_line", {"line_id": 7}, self.bridge)
            self.assertEqual(result["request_status"], "sconosciuta")
            self.assertEqual(main.LATE_INFO[6], original)
        self.assertEqual(self.bridge.late, {6: "abcd"})
        self.assertEqual(list(self.folder.glob("capocantiere_actions_*.lua")), [])

    def test_unknown_timeout_delivers_late_result_once(self):
        self.timeout_with_broken_state()
        nonce = self.bridge.late[6]
        result_path = self.folder / f"capocantiere_results_6_{nonce}.lua"
        lua_table.save_userdata(str(result_path), {
            "id": 6, "nonce": nonce, "results": [{"ok": True, "type": "ping"}]})
        self.assertEqual(self.bridge.take_late_results(), {6: [{"ok": True, "type": "ping"}]})
        self.assertEqual(self.bridge.take_late_results(), {})

    def test_acceptance_valid_ids_preserve_true_and_false(self):
        for last, expected in ((0, False), (5, False), (6, True), (7, True)):
            with self.subTest(last=last):
                lua_table.save_userdata(str(self.path), {"lastActionId": last})
                self.bridge._state = None
                self.assertIs(self.bridge._accepted(6), expected)

    def write_late_result(self):
        self.bridge.late[6] = "abcd"
        lua_table.save_userdata(str(self.folder / "capocantiere_results_6_abcd.lua"), {
            "id": 6, "nonce": "abcd", "results": [{"ok": True}]})

    def assert_send_blocked_without_writes(self):
        before = sorted(p.name for p in self.folder.iterdir())
        with patch.object(game_bridge.time, "sleep"), self.assertRaises(game_bridge.GameTimeout) as caught:
            self.bridge.send([{"type": "ping"}], timeout=0)
        self.assertEqual(caught.exception.status, "sconosciuta")
        self.assertFalse(caught.exception.request_sent)
        self.assertEqual(sorted(p.name for p in self.folder.iterdir()), before)

    def test_collected_late_result_blocks_id_reuse_until_state_catches_up(self):
        self.write_late_result()
        self.assert_send_blocked_without_writes()
        self.assertEqual(self.bridge.take_late_results(), {6: [{"ok": True}]})

    def test_delivered_late_result_still_blocks_id_reuse(self):
        self.write_late_result()
        self.assertEqual(self.bridge.take_late_results(), {6: [{"ok": True}]})
        self.assert_send_blocked_without_writes()

    def test_state_catches_up_and_next_request_uses_seven(self):
        self.write_late_result()
        self.bridge.take_late_results()
        lua_table.save_userdata(str(self.path), {"lastActionId": 6})
        self.bridge._state = None
        self.assertEqual(self.bridge._next_id(), 7)

    def test_state_reset_does_not_silently_skip_unconfirmed_result(self):
        self.write_late_result()
        self.bridge.take_late_results()
        lua_table.save_userdata(str(self.path), {"lastActionId": 0})
        self.bridge._state = None
        self.assert_send_blocked_without_writes()

    def test_success_result_without_state_ack_blocks_following_request(self):
        real_save = lua_table.save_userdata
        def send_and_reply(path, value):
            real_save(path, value)
            if Path(path).name.startswith("capocantiere_actions_"):
                result = dict(value, results=[{"ok": True}])
                result.pop("actions")
                reply_path = str(path).replace("capocantiere_actions_", "capocantiere_results_")
                real_save(reply_path, result)
        with patch.object(lua_table, "save_userdata", side_effect=send_and_reply), \
                patch.object(self.bridge, "_wait_state_id"), patch.object(game_bridge.time, "sleep"):
            self.assertEqual(self.bridge.send([{"type": "ping"}], timeout=1), [{"ok": True}])
        self.assert_send_blocked_without_writes()

    def test_invalid_state_id_cannot_publish_actions(self):
        for state in ({}, {"lastActionId": True}, {"lastActionId": -1},
                      {"lastActionId": 5.5}, {"lastActionId": "6"}, [1, 2]):
            with self.subTest(state=state):
                lua_table.save_userdata(str(self.path), state)
                self.bridge._state = None
                with patch.object(game_bridge.time, "sleep"), self.assertRaises(RuntimeError):
                    self.bridge.send([{"type": "ping"}], timeout=0)
                self.assertEqual(list(self.folder.glob("capocantiere_actions_*.lua")), [])
