"""Sonda snapshot: fixture, niente bridge vivo, DLL, Steam o chiavi."""
import contextlib
import ctypes
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import lua_table

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes/strumenti"))
try:
    import bridge_snapshot as observer
except ModuleNotFoundError as exc:
    if exc.name != "bridge_snapshot":
        raise
    observer = SimpleNamespace()


class BridgeSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.path = self.root / "capocantiere_state.lua"

    def write(self, value):
        self.path.write_text(lua_table.dumps(value), encoding="utf-8")
        return self.path

    def state(self):
        return {"lastActionId":42, "modVersion":"fixture-private-name",
                "towns":[{"id":1,"name":"fixture-private-town"}],
                "industries":[],"stations":[],"lines":[{"id":2}],"depots":[],"errors":[]}

    def test_snapshot_metadata_preserves_files_and_no_data_directory(self):
        self.write(self.state())
        sibling = self.root / "capocantiere_actions_43_fixture.lua"
        sibling.write_bytes(b"fixture-action-unchanged")
        before = {p.name:p.read_bytes() for p in self.root.iterdir()}
        with patch.object(ctypes,"CDLL",side_effect=AssertionError("no DLL")):
            out = observer.observe_state(self.path)
        self.assertTrue(out["ok"])
        self.assertEqual(out["counts"], {"towns":1,"industries":0,"stations":0,"lines":1,"depots":0})
        self.assertTrue(out["last_action_id_valid"])
        self.assertTrue(out["read_only"])
        self.assertFalse(out["live_bridge_tested"])
        self.assertNotIn("fixture-private", json.dumps(out))
        self.assertNotIn(str(self.root), json.dumps(out))
        self.assertEqual(before,{p.name:p.read_bytes() for p in self.root.iterdir()})

    def test_legacy_filename_and_missing_optional_sections(self):
        self.write({"lastActionId":0})
        legacy = self.root / "state.lua"
        legacy.write_bytes(self.path.read_bytes())
        out = observer.observe_state(legacy)
        self.assertTrue(out["ok"])
        self.assertEqual(out["counts"],{k:None for k in ["towns","industries","stations","lines","depots"]})
        self.assertTrue(out["warnings"])

    def test_relative_wrong_name_and_network_refused_before_open(self):
        for path in [Path("state.lua"), self.root/"private-key.txt", "//server/share/state.lua"]:
            with self.subTest(path=path), patch.object(Path,"open",side_effect=AssertionError("no open")):
                out=observer.observe_state(path)
                self.assertFalse(out["ok"])
                self.assertTrue(out["errors"])

    def test_missing_directory_malformed_and_bad_encoding_report_fixed_errors(self):
        for payload in [b"function data() return {secret='fixture-private'}",
                        b"return 7",b"return {lastActionId=true}",b"return {lastActionId=-1}",
                        b"return {lastActionId=1.5}", b"return {lastActionId=1e999}", b"bad-private-content",bytes((255,))]:
            with self.subTest(payload=payload):
                self.path.write_bytes(payload)
                out=observer.observe_state(self.path)
                self.assertFalse(out["ok"])
                self.assertNotIn("private",json.dumps(out))
                self.assertNotIn(str(self.root),json.dumps(out))
        self.assertFalse(observer.observe_state(self.root/"state.lua")["ok"])
        directory=self.root/"other"/"state.lua";directory.mkdir(parents=True)
        self.assertFalse(observer.observe_state(directory)["ok"])

    def test_size_limit_refuses_before_open_and_reads_bounded(self):
        self.write(self.state())
        with patch.object(observer,"MAX_STATE_BYTES",8),patch.object(Path,"open",side_effect=AssertionError("no read")):
            self.assertFalse(observer.observe_state(self.path)["ok"])
        original = Path.open
        sizes=[]
        class Spy:
            def __init__(self, stream): self.stream=stream
            def __enter__(self): return self
            def __exit__(self,*args): return self.stream.__exit__(*args)
            def fileno(self): return self.stream.fileno()
            def read(self,size=-1):
                sizes.append(size)
                return self.stream.read(size)
        def spy(path,*args,**kwargs): return Spy(original(path,*args,**kwargs))
        with patch.object(Path,"open",spy):
            self.assertTrue(observer.observe_state(self.path)["ok"])
        self.assertTrue(sizes and all(0 < n <= observer.MAX_STATE_BYTES+1 for n in sizes))

    def test_change_during_read_and_invalid_section_are_not_silent(self):
        self.write(self.state())
        before=self.path.stat()
        changed=SimpleNamespace(st_mode=before.st_mode,st_size=before.st_size+1,
            st_mtime_ns=before.st_mtime_ns+1,st_ino=before.st_ino,st_dev=before.st_dev)
        with patch.object(os,"fstat",side_effect=[before,changed]):
            out=observer.observe_state(self.path)
        self.assertFalse(out["ok"])
        self.assertTrue(out["errors"])
        value=self.state();value["towns"]="fixture-private-invalid-section";self.write(value)
        out=observer.observe_state(self.path)
        self.assertFalse(out["ok"])
        self.assertIsNone(out["counts"]["towns"])
        self.assertNotIn("fixture-private",json.dumps(out))

    def test_cli_is_json_and_import_has_no_bridge_environment_search_or_native_load(self):
        self.write(self.state())
        output=io.StringIO()
        with contextlib.redirect_stdout(output):
            code=observer.main(["--state-file",str(self.path)])
        self.assertEqual(code,0)
        self.assertTrue(json.loads(output.getvalue())["ok"])
        source=Path(observer.__file__)
        spec=importlib.util.spec_from_file_location("snapshot_fresh_probe",source)
        module=importlib.util.module_from_spec(spec)
        class NoEnv:
            def get(self,*args): raise AssertionError("no environment lookup")
            def __getitem__(self,*args): raise AssertionError("no environment lookup")
        import builtins,glob
        original=builtins.__import__
        def safe_import(name,*args,**kwargs):
            if name == "game_bridge": raise AssertionError("no game bridge import")
            return original(name,*args,**kwargs)
        with patch.object(os,"environ",NoEnv()),patch.object(glob,"glob",side_effect=AssertionError("no search")):
            with patch.object(ctypes,"CDLL",side_effect=AssertionError("no DLL")),patch.object(builtins,"__import__",safe_import):
                spec.loader.exec_module(module)
