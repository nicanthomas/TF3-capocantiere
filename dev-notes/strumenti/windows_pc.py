"""Controllo esplicito delle sole finestre Steam/TF3, senza avvio automatico.

SendInput e' globale: i controlli riducono ma non eliminano le race del focus.
Non usare con input concorrente; acquisire e ispezionare screenshot prima dei clic.
Solo stdlib; nessun accesso a salvataggi, mod, chiavi API o configurazioni Steam.
"""
from dataclasses import dataclass, asdict
from pathlib import Path
import argparse
import ctypes as c
from ctypes import wintypes as w
import json
import os
import struct
import time


class ControlError(RuntimeError):
    pass


@dataclass(frozen=True)
class Window:
    hwnd: int
    pid: int
    title: str
    window_class: str
    exe: str
    rect: tuple
    kind: str


def choose(windows):
    if len(windows) != 1:
        raise ControlError("Serve esattamente una finestra verificata; selezione ambigua o assente")
    return windows[0]


class Controller:
    def __init__(self, backend, window):
        self.backend, self.window = backend, window

    def validate(self, *, foreground=True):
        current = self.backend.inspect(self.window.hwnd, self.window.kind)
        if current != self.window:
            raise ControlError("Identita' o geometria cambiata: acquisire di nuovo la finestra")
        if foreground and self.backend.root_foreground() != self.window.hwnd:
            raise ControlError("Focus fuori dalla finestra autorizzata")
        if foreground and self.backend.input_busy():
            raise ControlError("Tasto modificatore o pulsante mouse premuto: input rifiutato")

    def focus(self):
        self.validate(foreground=False)
        self.backend.focus(self.window.hwnd)
        time.sleep(0.1)
        self.validate()

    def click(self, x, y):
        self.validate()
        width, height = self.backend.client_size(self.window.hwnd)
        if not (0 <= x < width and 0 <= y < height):
            raise ControlError("Coordinate fuori dal client")
        point = self.backend.screen_point(self.window.hwnd, x, y)
        if self.backend.root_at(*point) != self.window.hwnd:
            raise ControlError("Punto coperto da un'altra finestra")
        self.backend.move(*point)
        self.validate()
        if self.backend.root_at(*point) != self.window.hwnd:
            raise ControlError("Finestra sotto il puntatore cambiata")
        if self.backend.cursor_point() != point:
            raise ControlError("Puntatore spostato da input concorrente")
        self.backend.mouse_pair()
        self.validate()

    def text(self, text):
        if len(text) > 256 or any(ord(ch) < 32 or 127 <= ord(ch) < 160 for ch in text):
            raise ControlError("Solo testo stampabile, massimo 256 caratteri")
        try:
            encoded = text.encode("utf-16-le")
        except UnicodeEncodeError as exc:
            raise ControlError("Testo Unicode non valido") from exc
        for (unit,) in struct.iter_unpack("<H", encoded):
            self.validate()
            self.backend.unicode_pair(unit)
            self.validate()

    def backspace(self, count):
        if not 1 <= count <= 100:
            raise ControlError("Backspace limitato a 1..100")
        for _ in range(count):
            self.validate()
            self.backend.backspace_pair()
            self.validate()

    def screenshot(self):
        self.validate(foreground=False)
        result = self.backend.capture(self.window)
        self.validate(foreground=False)
        return result


class Native:
    def __init__(self, *, steam_root, tf3_exe=None):
        if os.name != "nt":
            raise ControlError("Backend nativo disponibile solo su Windows")
        self.steam_root = Path(steam_root).resolve()
        self.tf3_exe = Path(tf3_exe).resolve() if tf3_exe else None
        self.u = c.WinDLL("user32", use_last_error=True)
        self.k = c.WinDLL("kernel32", use_last_error=True)
        self.g = c.WinDLL("gdi32", use_last_error=True)
        # All pointer-returning functions need explicit prototypes on x64.
        def bind(dll, name, result, *args):
            fn = getattr(dll, name)
            fn.restype, fn.argtypes = result, list(args)
            return fn
        self.callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
        bind(self.u, "EnumWindows", w.BOOL, self.callback_type, w.LPARAM)
        for name in ("IsWindow", "IsWindowVisible", "IsIconic", "SetForegroundWindow"):
            bind(self.u, name, w.BOOL, w.HWND)
        bind(self.u, "GetForegroundWindow", w.HWND)
        bind(self.u, "GetAncestor", w.HWND, w.HWND, w.UINT)
        bind(self.u, "GetWindowThreadProcessId", w.DWORD, w.HWND, c.POINTER(w.DWORD))
        for name in ("GetWindowTextW", "GetClassNameW"):
            bind(self.u, name, c.c_int, w.HWND, w.LPWSTR, c.c_int)
        for name in ("GetWindowRect", "GetClientRect"):
            bind(self.u, name, w.BOOL, w.HWND, c.POINTER(w.RECT))
        bind(self.u, "ClientToScreen", w.BOOL, w.HWND, c.POINTER(w.POINT))
        bind(self.u, "WindowFromPoint", w.HWND, w.POINT)
        bind(self.u, "GetCursorPos", w.BOOL, c.POINTER(w.POINT))
        bind(self.u, "SetCursorPos", w.BOOL, c.c_int, c.c_int)
        bind(self.u, "GetAsyncKeyState", c.c_short, c.c_int)
        bind(self.k, "OpenProcess", w.HANDLE, w.DWORD, w.BOOL, w.DWORD)
        bind(self.k, "CloseHandle", w.BOOL, w.HANDLE)
        bind(self.k, "QueryFullProcessImageNameW", w.BOOL, w.HANDLE, w.DWORD, w.LPWSTR, c.POINTER(w.DWORD))
        # Make client/screen coordinates physical pixels when supported.
        if hasattr(self.u, "SetThreadDpiAwarenessContext"):
            bind(self.u, "SetThreadDpiAwarenessContext", w.HANDLE, w.HANDLE)(w.HANDLE(-4))
        class Mouse(c.Structure):
            _fields_ = [("dx", w.LONG), ("dy", w.LONG), ("data", w.DWORD), ("flags", w.DWORD), ("time", w.DWORD), ("extra", w.WPARAM)]
        class Key(c.Structure):
            _fields_ = [("vk", w.WORD), ("scan", w.WORD), ("flags", w.DWORD), ("time", w.DWORD), ("extra", w.WPARAM)]
        class Union(c.Union):
            _fields_ = [("mouse", Mouse), ("key", Key)]
        class Input(c.Structure):
            _fields_ = [("kind", w.DWORD), ("data", Union)]
        self.Mouse, self.Key, self.Union, self.Input = Mouse, Key, Union, Input
        bind(self.u, "SendInput", w.UINT, w.UINT, c.POINTER(Input), c.c_int)
        bind(self.u, "GetWindowDC", w.HDC, w.HWND)
        bind(self.u, "ReleaseDC", c.c_int, w.HWND, w.HDC)
        bind(self.u, "PrintWindow", w.BOOL, w.HWND, w.HDC, w.UINT)
        bind(self.g, "CreateCompatibleDC", w.HDC, w.HDC)
        bind(self.g, "CreateCompatibleBitmap", w.HBITMAP, w.HDC, c.c_int, c.c_int)
        bind(self.g, "SelectObject", w.HANDLE, w.HDC, w.HANDLE)
        bind(self.g, "DeleteObject", w.BOOL, w.HANDLE)
        bind(self.g, "DeleteDC", w.BOOL, w.HDC)
        bind(self.g, "GetDIBits", c.c_int, w.HDC, w.HBITMAP, w.UINT, w.UINT, c.c_void_p, c.c_void_p, w.UINT)

    def inspect(self, hwnd, kind):
        if not self.u.IsWindow(hwnd) or not self.u.IsWindowVisible(hwnd) or self.u.IsIconic(hwnd):
            raise ControlError("Finestra assente, nascosta o minimizzata")
        pid = w.DWORD()
        self.u.GetWindowThreadProcessId(hwnd, c.byref(pid))
        handle = self.k.OpenProcess(0x1000, False, pid.value)
        if not handle:
            raise ControlError("Processo non verificabile")
        try:
            buffer, size = c.create_unicode_buffer(32768), w.DWORD(32768)
            if not self.k.QueryFullProcessImageNameW(handle, 0, buffer, c.byref(size)):
                raise ControlError("Percorso eseguibile non verificabile")
            exe = Path(buffer.value).resolve()
        finally:
            self.k.CloseHandle(handle)
        title, cls = c.create_unicode_buffer(1024), c.create_unicode_buffer(256)
        self.u.GetWindowTextW(hwnd, title, len(title))
        self.u.GetClassNameW(hwnd, cls, len(cls))
        if kind == "steam":
            if title.value != "Steam" or exe.name.lower() not in ("steam.exe", "steamwebhelper.exe") or self.steam_root not in exe.parents:
                raise ControlError("Finestra non appartiene a Steam autorizzato")
        elif kind == "tf3":
            if self.tf3_exe is None or exe != self.tf3_exe:
                raise ControlError("Percorso TF3 non corrisponde al target esplicito")
        else:
            raise ControlError("Target non autorizzato")
        rect = w.RECT()
        if not self.u.GetWindowRect(hwnd, c.byref(rect)):
            raise ControlError("Geometria non disponibile")
        return Window(int(hwnd), pid.value, title.value, cls.value, str(exe), (rect.left, rect.top, rect.right, rect.bottom), kind)

    def windows(self, kind):
        result = []
        @self.callback_type
        def collect(hwnd, unused):
            try:
                result.append(self.inspect(hwnd, kind))
            except ControlError:
                pass
            return True
        if not self.u.EnumWindows(collect, 0):
            raise ControlError("Enumerazione finestre fallita")
        return result

    def root_foreground(self):
        return self.u.GetAncestor(self.u.GetForegroundWindow(), 2)

    def input_busy(self):
        return any(self.u.GetAsyncKeyState(key) & 0x8000 for key in (1, 2, 4, 5, 6, 16, 17, 18, 91, 92))

    def focus(self, hwnd):
        self.u.SetForegroundWindow(hwnd)  # Controller verifies actual foreground.

    def client_size(self, hwnd):
        rect = w.RECT()
        if not self.u.GetClientRect(hwnd, c.byref(rect)):
            raise ControlError("Client non disponibile")
        return (rect.right, rect.bottom)

    def screen_point(self, hwnd, x, y):
        point = w.POINT(x, y)
        if not self.u.ClientToScreen(hwnd, c.byref(point)):
            raise ControlError("Conversione coordinate fallita")
        return (point.x, point.y)

    def root_at(self, x, y):
        return self.u.GetAncestor(self.u.WindowFromPoint(w.POINT(x, y)), 2)

    def cursor_point(self):
        point = w.POINT()
        if not self.u.GetCursorPos(c.byref(point)):
            raise ControlError("Posizione puntatore non verificabile")
        return (point.x, point.y)

    def move(self, x, y):
        if not self.u.SetCursorPos(x, y):
            raise ControlError("Spostamento puntatore fallito")

    def pair(self, down, up):
        events = (self.Input * 2)(down, up)
        if self.u.SendInput(2, events, c.sizeof(self.Input)) != 2:
            raise ControlError("SendInput incompleto: interrompere e verificare lo stato dei tasti")
        time.sleep(0.025)

    def mouse_pair(self):
        self.pair(self.Input(0, self.Union(mouse=self.Mouse(0, 0, 0, 2, 0, 0))), self.Input(0, self.Union(mouse=self.Mouse(0, 0, 0, 4, 0, 0))))

    def unicode_pair(self, code):
        self.pair(self.Input(1, self.Union(key=self.Key(0, code, 4, 0, 0))), self.Input(1, self.Union(key=self.Key(0, code, 6, 0, 0))))

    def backspace_pair(self):
        self.pair(self.Input(1, self.Union(key=self.Key(8, 0, 0, 0, 0))), self.Input(1, self.Union(key=self.Key(8, 0, 2, 0, 0))))

    def capture(self, window):
        width, height = window.rect[2] - window.rect[0], window.rect[3] - window.rect[1]
        if not (0 < width <= 16384 and 0 < height <= 16384):
            raise ControlError("Dimensioni screenshot non valide")
        dc = self.u.GetWindowDC(window.hwnd)
        memory = bitmap = previous = None
        try:
            if not dc:
                raise ControlError("DC finestra non disponibile")
            memory = self.g.CreateCompatibleDC(dc)
            bitmap = self.g.CreateCompatibleBitmap(dc, width, height)
            if not memory or not bitmap:
                raise ControlError("Allocazione screenshot fallita")
            previous = self.g.SelectObject(memory, bitmap)
            if not previous or previous == c.c_void_p(-1).value:
                previous = None
                raise ControlError("Selezione bitmap fallita")
            if not self.u.PrintWindow(window.hwnd, memory, 2):
                raise ControlError("PrintWindow fallito")
            self.g.SelectObject(memory, previous)
            previous = None
            size = width * height * 4
            info = c.create_string_buffer(struct.pack("<IiiHHIIiiII", 40, width, -height, 1, 32, 0, size, 0, 0, 0, 0))
            pixels = c.create_string_buffer(size)
            if self.g.GetDIBits(memory, bitmap, 0, height, pixels, info, 0) != height:
                raise ControlError("Lettura bitmap incompleta")
            header = struct.pack("<2sIHHI", b"BM", 54 + size, 0, 0, 54)
            return header + info.raw[:40] + pixels.raw
        finally:
            if previous:
                self.g.SelectObject(memory, previous)
            if bitmap:
                self.g.DeleteObject(bitmap)
            if memory:
                self.g.DeleteDC(memory)
            if dc:
                self.u.ReleaseDC(window.hwnd, dc)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "focus", "screenshot", "click", "text", "backspace"))
    parser.add_argument("--target", choices=("steam", "tf3"), default="steam")
    parser.add_argument("--steam-root", default=r"C:\Program Files (x86)\Steam")
    parser.add_argument("--tf3-exe")
    parser.add_argument("--hwnd", type=int)
    parser.add_argument("--pid", type=int)
    parser.add_argument("--x", type=int)
    parser.add_argument("--y", type=int)
    parser.add_argument("--rect", type=int, nargs=4, metavar=("LEFT", "TOP", "RIGHT", "BOTTOM"))
    parser.add_argument("--text")
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--output")
    args = parser.parse_args()
    backend = Native(steam_root=args.steam_root, tf3_exe=args.tf3_exe)
    candidates = backend.windows(args.target)
    if args.action == "list":
        print(json.dumps([asdict(window) for window in candidates], ensure_ascii=True))
        return
    if args.hwnd is None or args.pid is None:
        raise ControlError("Specificare --hwnd e --pid da una recente identificazione")
    window = choose([item for item in candidates if item.hwnd == args.hwnd and item.pid == args.pid])
    controller = Controller(backend, window)
    if args.action == "focus":
        controller.focus()
    elif args.action == "screenshot":
        if not args.output:
            raise ControlError("Specificare --output BMP in una cartella artefatti autorizzata")
        data = controller.screenshot()
        with open(args.output, "xb") as output:  # Never overwrite screenshots.
            output.write(data)
    elif args.action == "click":
        if args.x is None or args.y is None:
            raise ControlError("Specificare coordinate client --x e --y")
        if args.rect is None or tuple(args.rect) != window.rect:
            raise ControlError("Per clic serve --rect corrispondente allo screenshot recente")
        controller.click(args.x, args.y)
    elif args.action == "text":
        if args.text is None:
            raise ControlError("Specificare --text")
        controller.text(args.text)
    elif args.action == "backspace":
        controller.backspace(args.count)
    print(json.dumps({"action": args.action, "target": asdict(window)}, ensure_ascii=True))


if __name__ == "__main__":
    try:
        main()
    except (ControlError, OSError) as exc:
        raise SystemExit(str(exc))
