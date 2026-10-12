"""Regressioni della versione esportata dalle copie mod Windows."""
import importlib.util
import contextlib
import io
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes"))
_spec = importlib.util.spec_from_file_location(
    "cc_build_version", Path(__file__).resolve().parents[1] / "dev-notes" / "build_script.py"
)
build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(build)


class BuildVersionTests(unittest.TestCase):
    def test_dev_copy_reports_the_version_it_writes_with_crlf(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            mod = root / "mod"
            mod.mkdir()
            source = mod / "script.lua"
            code = 'local CC_VERSION = "new"\r\nlocal DEV_MODE = false\r\n'
            source.write_bytes(code.encode("utf-8"))
            output = io.StringIO()
            with patch.object(build, "MOD_DIR", str(mod)), patch.object(build, "SCRIPT", str(source)), \
                    patch.object(build, "DIST", str(root / "dist")), contextlib.redirect_stdout(output):
                self.assertEqual(build.build_copy(code, dev=True), 0)
            self.assertIn("Versione: new - DEV_MODE = true", output.getvalue())
            target = root / "dist" / "tfcapocantiere_1_dev" / "script.lua"
            self.assertEqual(target.read_bytes(), code.replace("false", "true").encode("utf-8"))

    def test_existing_version_is_replaced_without_shadowing_on_windows(self):
        for newline in ("\n", "\r\n"):
            with self.subTest(newline=repr(newline)):
                script = newline.join([
                    "local STATE_VERSION = 1",
                    'local CC_VERSION = "old"',
                    "local exported = { modVersion = CC_VERSION }",
                    "",
                ])
                expected = script.replace('CC_VERSION = "old"', 'CC_VERSION = "new"')
                self.assertEqual(build.set_version(script, "new"), expected)

    def test_inserting_version_is_idempotent_with_crlf(self):
        script = "local STATE_VERSION = 1\r\nlocal value = 3\r\n"
        once = build.set_version(script, "new")
        self.assertEqual(once.count('local CC_VERSION = "new"'), 1)
        self.assertEqual(build.set_version(once, "new"), once)

    def test_mixed_line_endings_do_not_leave_the_old_effective_version(self):
        script = 'local STATE_VERSION = 1\nlocal CC_VERSION = "old"\r\nreturn CC_VERSION\n'
        result = build.set_version(script, "new")
        self.assertEqual(result, 'local STATE_VERSION = 1\nlocal CC_VERSION = "new"\r\nreturn CC_VERSION\n')


if __name__ == "__main__":
    unittest.main()
