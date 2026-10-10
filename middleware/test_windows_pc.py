"""Controlli di sicurezza senza desktop, eventi nativi o processi esterni."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from dataclasses import replace
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes/strumenti"))
import windows_pc as pc


class Backend:
    def __init__(self):
        self.current = pc.Window(100, 200, "Steam", "SDL_app", "C:/Steam/steam.exe", (0, 0, 800, 600), "steam")
        self.foreground = 100
        self.cover = 100
        self.busy = False
        self.cursor = (0, 0)
        self.events = []
    def inspect(self, handle, kind):
        return self.current
    def root_foreground(self):
        return self.foreground
    def input_busy(self):
        return self.busy
    def client_size(self, handle):
        return (800, 600)
    def screen_point(self, handle, x, y):
        return (x, y)
    def root_at(self, x, y):
        return self.cover
    def cursor_point(self):
        return self.cursor
    def windows(self, kind):
        return [self.current]
    def move(self, x, y):
        self.cursor = (x, y)
        self.events.append(("move", x, y))
    def mouse_pair(self):
        self.events.append(("click",))
    def unicode_pair(self, code):
        self.events.append(("text", code))
    def backspace_pair(self):
        self.events.append(("backspace",))


class WindowControlTests(unittest.TestCase):
    def setUp(self):
        self.backend = Backend()
        self.controller = pc.Controller(self.backend, self.backend.current)

    def test_foreign_focus_blocks_all_input(self):
        self.backend.foreground = 999
        with self.assertRaises(pc.ControlError):
            self.controller.click(10, 10)
        self.assertEqual(self.backend.events, [])

    def test_pid_reuse_blocks_all_input(self):
        self.backend.current = replace(self.backend.current, pid=201)
        with self.assertRaises(pc.ControlError):
            self.controller.text("probe")
        self.assertEqual(self.backend.events, [])

    def test_geometry_change_blocks_stale_coordinates(self):
        self.backend.current = replace(self.backend.current, rect=(10, 10, 810, 610))
        with self.assertRaises(pc.ControlError):
            self.controller.click(10, 10)
        self.assertEqual(self.backend.events, [])

    def test_covered_point_blocks_pointer_and_click(self):
        self.backend.cover = 999
        with self.assertRaises(pc.ControlError):
            self.controller.click(10, 10)
        self.assertEqual(self.backend.events, [])

    def test_outside_client_bounds_blocks_pointer(self):
        for point in ((-1, 10), (800, 10), (10, 600)):
            with self.assertRaises(pc.ControlError):
                self.controller.click(*point)
        self.assertEqual(self.backend.events, [])

    def test_held_modifier_or_mouse_button_blocks_input(self):
        self.backend.busy = True
        with self.assertRaises(pc.ControlError):
            self.controller.text("probe")
        self.assertEqual(self.backend.events, [])

    def test_focus_loss_between_characters_stops_next_event(self):
        original = self.backend.unicode_pair
        def first(code):
            original(code)
            self.backend.foreground = 999
        self.backend.unicode_pair = first
        with self.assertRaises(pc.ControlError):
            self.controller.text("ab")
        self.assertEqual(self.backend.events, [("text", 97)])

    def test_text_rejects_control_characters_before_any_event(self):
        for text in ("a\n", "a\t", "a\x1b", "a\x00"):
            with self.assertRaises(pc.ControlError):
                self.controller.text(text)
        self.assertEqual(self.backend.events, [])

    def test_unicode_surrogate_pair_and_safe_click(self):
        self.controller.text("\U0001f600")
        self.controller.click(20, 30)
        self.assertEqual(self.backend.events, [("text", 0xd83d), ("text", 0xde00), ("move", 20, 30), ("click",)])

    def test_ambiguous_or_missing_target_refused(self):
        with self.assertRaises(pc.ControlError):
            pc.choose([])
        with self.assertRaises(pc.ControlError):
            pc.choose([self.backend.current, self.backend.current])

    def test_executable_or_title_change_blocks_input(self):
        for changed in (replace(self.backend.current, exe="C:/other.exe"), replace(self.backend.current, title="other")):
            self.backend.current = changed
            with self.assertRaises(pc.ControlError):
                self.controller.backspace(1)
        self.assertEqual(self.backend.events, [])

    def test_native_side_mouse_buttons_block_input(self):
        native = pc.Native.__new__(pc.Native)
        for pressed in (5, 6):
            class User32:
                GetAsyncKeyState = staticmethod(lambda key: 0x8000 if key == pressed else 0)
            native.u = User32()
            self.assertTrue(native.input_busy())

    def test_pointer_drift_within_target_blocks_click(self):
        original = self.backend.move
        def concurrent_move(x, y):
            original(x, y)
            self.backend.cursor = (x + 50, y)
        self.backend.move = concurrent_move
        with self.assertRaises(pc.ControlError):
            self.controller.click(20, 30)
        self.assertEqual(self.backend.events, [("move", 20, 30)])

    def test_cli_click_requires_recent_geometry(self):
        args = ["windows_pc", "click", "--hwnd", "100", "--pid", "200", "--x", "20", "--y", "30"]
        with patch.object(pc, "Native", return_value=self.backend), patch.object(sys, "argv", args):
            with self.assertRaises(pc.ControlError):
                pc.main()
        self.assertEqual(self.backend.events, [])
