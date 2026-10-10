"""Regressioni delle guardie audit: non eseguono operazioni vietate."""
from pathlib import Path
import os
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes/strumenti"))
import test_isolati


class IsolationPolicyTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve()
        self.writes = set()
        self.guard = test_isolati.make_guard(self.root, self.writes)

    def test_fixture_writes_allowed_and_counted(self):
        path = self.root / "state.lua"
        self.guard("open", (str(path), "w", os.O_WRONLY))
        self.assertEqual(self.writes, {str(path)})

    def test_outside_fixture_write_blocked(self):
        path = self.root.parent / "outside.lua"
        with self.assertRaises(test_isolati.IsolationError):
            self.guard("open", (str(path), "w", os.O_WRONLY))
        self.assertEqual(self.writes, set())

    def test_real_game_reads_blocked_even_without_write(self):
        with self.assertRaises(test_isolati.IsolationError):
            self.guard("open", (str(self.root / "Steam/userdata/state.lua"), "r", 0))

    def test_rename_destination_outside_fixture_blocked(self):
        with self.assertRaises(test_isolati.IsolationError):
            self.guard("os.rename", (str(self.root / "a"), str(self.root.parent / "b"), -1, -1))

    def test_external_operations_blocked(self):
        for event in ("socket.__new__", "socket.connect", "socket.getaddrinfo", "subprocess.Popen", "os.system"):
            with self.subTest(event=event), self.assertRaises(test_isolati.IsolationError):
                self.guard(event, ())

    def test_steam_directory_enumeration_and_library_load_blocked(self):
        path = str(self.root / "Steam")
        for event in ("os.listdir", "os.scandir", "ctypes.dlopen"):
            with self.subTest(event=event), self.assertRaises(test_isolati.IsolationError):
                self.guard(event, (path,))

    def test_binary_write_flags_are_checked(self):
        with self.assertRaises(test_isolati.IsolationError):
            self.guard("open", (str(self.root.parent / "outside"), None, os.O_CREAT | os.O_TRUNC))

    def test_source_read_allowed(self):
        self.guard("open", (str(Path(__file__)), "r", 0))
        self.assertEqual(self.writes, set())
