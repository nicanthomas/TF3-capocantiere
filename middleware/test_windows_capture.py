"""Gestione screenshot GDI simulata: nessuna DLL/finestra reale."""
import ctypes
import importlib.util
from pathlib import Path
import struct
import sys
from types import SimpleNamespace
import unittest

path=Path(__file__).resolve().parents[1]/'dev-notes'/'strumenti'/'windows_pc.py'
spec=importlib.util.spec_from_file_location('pc_capture_tests',path)
pc=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=pc
spec.loader.exec_module(pc)


class GdiFixture:
    def __init__(self, failure=None):
        self.failure=failure
        self.events=[]
        self.resources=set()
        self.selected=False
        self.old=2**40+1
        self.bitmap=2**40+2
        self.memory=2**40+3
        self.window_dc=2**40+4

    def GetWindowDC(self, hwnd):
        if self.failure=='window_dc': return 0
        self.resources.add('window_dc'); return self.window_dc

    def ReleaseDC(self, hwnd, dc):
        self.resources.remove('window_dc'); return 1

    def CreateCompatibleDC(self, dc):
        if self.failure=='memory_dc': return 0
        self.resources.add('memory_dc'); return self.memory

    def CreateCompatibleBitmap(self, dc, width, height):
        if self.failure=='bitmap': return 0
        self.resources.add('bitmap'); return self.bitmap

    def SelectObject(self, dc, obj):
        if obj==self.bitmap:
            if self.failure=='select': return 0
            self.selected=True; return self.old
        if self.failure in ('restore_zero','restore_error','print_and_restore'):
            self.events.append('restore_failed')
            return ctypes.c_void_p(-1).value if self.failure=='restore_error' else 0
        self.selected=False; self.events.append('deselected'); return self.bitmap

    def PrintWindow(self, hwnd, dc, flags):
        return 0 if self.failure in ('print','print_and_restore') else 1

    def GetDIBits(self, dc, bitmap, start, height, pixels, info, usage):
        self.events.append('read_selected' if self.selected else 'read')
        return height-1 if self.failure=='read' else height

    def DeleteObject(self, bitmap):
        self.events.append('delete_bitmap')
        if self.selected: return 0
        self.resources.remove('bitmap'); return 1

    def DeleteDC(self, dc):
        self.events.append('delete_dc')
        self.selected=False; self.resources.remove('memory_dc'); return 1


def capture_fixture(failure=None):
    fixture=GdiFixture(failure)
    native=pc.Native.__new__(pc.Native)
    native.u=native.g=fixture
    window=pc.Window(1,2,'fixture','fixture','fixture.exe',(0,0,2,3),'steam')
    return native,window,fixture


class ScreenshotResourceTests(unittest.TestCase):
    def test_valid_bmp_reads_deselected_bitmap_and_releases_resources(self):
        native,window,fixture=capture_fixture()
        bmp=native.capture(window)
        self.assertEqual(bmp[:2],b'BM')
        self.assertEqual(struct.unpack_from('<I',bmp,2)[0],len(bmp))
        self.assertEqual(struct.unpack_from('<ii',bmp,18),(2,-3))
        self.assertEqual(len(bmp),54+2*3*4)
        self.assertEqual(fixture.resources,set())
        self.assertNotIn('read_selected',fixture.events)
        self.assertLess(fixture.events.index('deselected'),fixture.events.index('read'))

    def test_failed_capture_releases_every_successfully_allocated_resource(self):
        for stage in ['window_dc','memory_dc','bitmap','select','print','read','print_and_restore']:
            with self.subTest(stage=stage):
                native,window,fixture=capture_fixture(stage)
                with self.assertRaises(pc.ControlError): native.capture(window)
                self.assertEqual(fixture.resources,set())

    def test_failed_bitmap_restore_stops_read_and_releases_selected_bitmap(self):
        for stage in ['restore_zero','restore_error']:
            with self.subTest(stage=stage):
                native,window,fixture=capture_fixture(stage)
                with self.assertRaises(pc.ControlError): native.capture(window)
                self.assertNotIn('read',fixture.events)
                self.assertNotIn('read_selected',fixture.events)
                self.assertEqual(fixture.resources,set())
                self.assertLess(fixture.events.index('delete_dc'),fixture.events.index('delete_bitmap'))
