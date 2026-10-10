"""Regressioni delle scritture atomiche; solo directory temporanee."""
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

import lua_table


class AtomicLuaTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "state.lua"
        lua_table.save_userdata(self.path, {"value": "old"})

    def test_transient_windows_sharing_errors_eventually_write(self):
        replace = os.replace
        for code in (5, 32, 33):
            error = PermissionError("sharing violation")
            error.winerror = code
            calls = [error, error]
            def locked(source, destination):
                if calls:
                    raise calls.pop()
                return replace(source, destination)
            with patch.object(lua_table.os, "replace", side_effect=locked):
                lua_table.save_userdata(self.path, {"value": code})
            self.assertEqual(lua_table.load_userdata(self.path), {"value": code})
            self.assertEqual(list(self.path.parent.glob(".tmp_*.lua")), [])

    @unittest.skipUnless(os.name == "nt", "richiede condivisione file Windows")
    def test_real_windows_reader_releases_lock(self):
        reader = self.path.open("r", encoding="utf-8")
        self.addCleanup(reader.close)
        timer = threading.Timer(0.08, reader.close)
        timer.start()
        self.addCleanup(timer.join)
        lua_table.save_userdata(self.path, {"value": "new"})
        self.assertEqual(lua_table.load_userdata(self.path), {"value": "new"})

    def test_permanent_lock_preserves_original_and_cleans_temp(self):
        original = self.path.read_bytes()
        error = PermissionError("permanent sharing violation")
        error.winerror = 32
        with patch.object(lua_table.os, "replace", side_effect=error):
            with self.assertRaises(PermissionError):
                lua_table.save_userdata(self.path, {"value": "new"})
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.glob(".tmp_*.lua")), [])

    def test_unrelated_permission_error_is_not_retried(self):
        attempts = []
        def denied(*args):
            attempts.append(args)
            raise PermissionError("non Windows")
        with patch.object(lua_table.os, "replace", side_effect=denied):
            with self.assertRaises(PermissionError):
                lua_table.save_userdata(self.path, {})
        self.assertEqual(len(attempts), 1)
        self.assertEqual(lua_table.load_userdata(self.path), {"value": "old"})

    def test_read_handle_closed_before_parsing(self):
        def parse_after_replace(text):
            lua_table.save_userdata(self.path, {"value": "new"})
            return {"value": "old"}
        with patch.object(lua_table, "loads", side_effect=parse_after_replace):
            self.assertEqual(lua_table.load_userdata(self.path), {"value": "old"})
        self.assertEqual(lua_table.load_userdata(self.path), {"value": "new"})


if __name__ == "__main__":
    unittest.main()
