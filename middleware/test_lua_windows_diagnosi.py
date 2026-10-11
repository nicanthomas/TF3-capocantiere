"""Header PE sintetici: nessuna DLL caricata, file solo nelle fixture temporanee."""
import contextlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes/strumenti"))
try:
    import lua_windows_diagnosi as diag
except ModuleNotFoundError as exc:
    if exc.name != "lua_windows_diagnosi":
        raise
    diag = SimpleNamespace()


def image(machine=0x8664, magic=0x20B, dll=True, offset=128, optional_size=240):
    payload = bytearray(offset + 24 + optional_size + 40)
    payload[:2] = b"MZ"
    struct.pack_into("<I", payload, 60, offset)
    payload[offset:offset+4] = bytes((80,69,0,0))
    struct.pack_into("<HHIIIHH", payload, offset+4,
                     machine, 1, 0, 0, 0, optional_size, 0x0002 | (0x2000 if dll else 0))
    struct.pack_into("<H", payload, offset+24, magic)
    return payload


class PEDiagnosisTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()

    def fixture(self, name, payload):
        path = self.root / name
        path.write_bytes(payload)
        return path

    def test_known_machines_and_dlls_without_loading(self):
        with patch("ctypes.CDLL", side_effect=AssertionError("no DLL loading")):
            for machine, magic, name, bits in [
                (0x14C,0x10B,"i386",32), (0x8664,0x20B,"amd64",64), (0xAA64,0x20B,"arm64",64)
            ]:
                with self.subTest(machine=name):
                    lib=self.fixture(name+".dll",image(machine,magic))
                    before=lib.read_bytes()
                    info=diag.read_pe(lib,require_dll=True)
                    self.assertEqual(info,{"machine":name,"bits":bits,"dll":True})
                    self.assertEqual(before,lib.read_bytes())

    def test_machine_mismatch_includes_same_bitness(self):
        exe=self.fixture("python.exe",image(dll=False))
        for machine,magic in [(0x14C,0x10B),(0xAA64,0x20B)]:
            with self.subTest(machine=machine):
                lib=self.fixture("other.dll",image(machine,magic))
                out=diag.compare_architecture(exe,lib)
                self.assertFalse(out["architecture_matches"])
                self.assertFalse(out["runtime_loaded"])

    def test_executable_is_not_accepted_as_dll(self):
        exe=self.fixture("python.exe",image(dll=False))
        with self.assertRaisesRegex(diag.DiagnosisError,"DLL"):
            diag.read_pe(exe,require_dll=True)

    def test_relative_path_rejected_before_open(self):
        with patch.object(Path,"open",side_effect=AssertionError("must not open relative file")):
            with self.assertRaisesRegex(diag.DiagnosisError,"assoluto"):
                diag.read_pe(Path("relative.dll"))

    def test_truncated_or_invalid_signatures_rejected(self):
        good=image()
        wrong_dos=bytearray(good); wrong_dos[:2]=b"ZZ"
        wrong_pe=bytearray(good); wrong_pe[128:132]=b"NOPE"
        tiny_offset=bytearray(good); struct.pack_into("<I",tiny_offset,60,12)
        not_image=bytearray(good); struct.pack_into("<H",not_image,150,0x2000)
        for i,payload in enumerate([b"MZ",wrong_dos,wrong_pe,tiny_offset,good[:140],good[:170],not_image]):
            with self.subTest(case=i):
                with self.assertRaises(diag.DiagnosisError):
                    diag.read_pe(self.fixture("bad.dll",payload),require_dll=True)

    def test_optional_magic_machine_and_size_rejected(self):
        for i,payload in enumerate([
            image(0x8664,0x10B),image(0x14C,0x20B),image(0xFFFF,0x20B),
            image(0x8664,0x107),image(optional_size=2)
        ]):
            with self.subTest(case=i):
                with self.assertRaises(diag.DiagnosisError):
                    diag.read_pe(self.fixture("bad.dll",payload),require_dll=True)

    def test_large_header_offset_refused_with_bounded_reads(self):
        payload=image(); struct.pack_into("<I",payload,60,2**30)
        stream=io.BytesIO(payload)
        sizes=[]
        original=stream.read
        def bounded_read(size=-1):
            sizes.append(size)
            return original(size)
        stream.read=bounded_read
        with patch.object(Path,"open",return_value=stream):
            with self.assertRaisesRegex(diag.DiagnosisError,"limite"):
                diag.read_pe(self.root/"huge.dll")
        self.assertTrue(sizes and all(0 <= n <= 512 for n in sizes))

    def test_default_diagnosis_inspects_only_python_executable(self):
        bits=struct.calcsize("P")*8
        machine,magic=(0x8664,0x20B) if bits==64 else (0x14C,0x10B)
        exe=self.fixture("python.exe",image(machine,magic,dll=False))
        with patch.object(sys,"platform","win32"),patch.object(sys,"executable",str(exe)):
            with patch.dict("os.environ",{"CAPOCANTIERE_LUA_LIB":str(self.root/"must-not-be-read.dll")}):
                out=diag.diagnose()
        self.assertFalse(out["candidate_supplied"])
        self.assertFalse(out["runtime_loaded"])
        self.assertEqual(out["python_bits"],bits)
        self.assertEqual(out["errors"],[])
        self.assertNotIn(str(self.root),json.dumps(out))

    def test_cli_candidate_error_is_json_and_has_no_private_path(self):
        bits=struct.calcsize("P")*8
        machine,magic=(0x8664,0x20B) if bits==64 else (0x14C,0x10B)
        exe=self.fixture("python.exe",image(machine,magic,dll=False))
        buf=io.StringIO()
        with patch.object(sys,"platform","win32"),patch.object(sys,"executable",str(exe)):
            with contextlib.redirect_stdout(buf):
                code=diag.main(["--library",str(self.root/"private-missing.dll")])
        out=json.loads(buf.getvalue())
        self.assertNotEqual(code,0)
        self.assertTrue(out["errors"])
        self.assertFalse(out["runtime_loaded"])
        self.assertNotIn(str(self.root),buf.getvalue())
