"""Diagnosi header PE Windows in sola lettura: mai caricare DLL o cercare candidati."""
import argparse
import json
from pathlib import Path
import struct
import sys


class DiagnosisError(RuntimeError):
    pass


MACHINES = {0x014C: ("i386", 32), 0x8664: ("amd64", 64), 0xAA64: ("arm64", 64)}
MAX_PE_OFFSET = 1024 * 1024


def read_pe(path, *, require_dll=False):
    path = Path(path)
    if not path.is_absolute():
        raise DiagnosisError("Richiesto percorso assoluto")
    try:
        with path.open("rb") as stream:
            dos = stream.read(64)
            if len(dos) != 64 or dos[:2] != b"MZ":
                raise DiagnosisError("Header DOS assente o troncato")
            offset = struct.unpack_from("<I", dos, 60)[0]
            if offset > MAX_PE_OFFSET:
                raise DiagnosisError("Offset PE oltre il limite diagnostico")
            size = stream.seek(0, 2)
            if offset < 64 or offset + 26 > size:
                raise DiagnosisError("Header PE assente o troncato")
            stream.seek(offset)
            header = stream.read(24)
            if len(header) != 24 or header[:4] != bytes((80, 69, 0, 0)):
                raise DiagnosisError("Firma PE non valida")
            machine = struct.unpack_from("<H", header, 4)[0]
            optional_size, flags = struct.unpack_from("<HH", header, 20)
            if not flags & 0x0002:
                raise DiagnosisError("Header non dichiara immagine eseguibile")
            if require_dll and not flags & 0x2000:
                raise DiagnosisError("Header non dichiara una DLL")
            if optional_size < 2 or offset + 24 + optional_size > size:
                raise DiagnosisError("Header opzionale troncato")
            magic_data = stream.read(2)
            if len(magic_data) != 2:
                raise DiagnosisError("Header opzionale troncato")
            magic = struct.unpack("<H", magic_data)[0]
            if machine not in MACHINES:
                raise DiagnosisError("Macchina PE non supportata dalla diagnosi")
            name, bits = MACHINES[machine]
            expected_magic, minimum = (0x10B, 96) if bits == 32 else (0x20B, 112)
            if magic != expected_magic or optional_size < minimum:
                raise DiagnosisError("Header opzionale incoerente con la macchina")
    except OSError as exc:
        # Never print a candidate path or the native exception details.
        raise DiagnosisError("File PE non leggibile") from exc
    return {"machine": name, "bits": bits, "dll": bool(flags & 0x2000)}


def compare_architecture(executable, library):
    python = read_pe(executable)
    candidate = read_pe(library, require_dll=True)
    return {
        "python_machine": python["machine"], "python_bits": python["bits"],
        "candidate_machine": candidate["machine"], "candidate_bits": candidate["bits"],
        "architecture_matches": python["machine"] == candidate["machine"],
        "runtime_loaded": False,
    }


def diagnose(library=None):
    out = {"windows": sys.platform == "win32", "python_bits": struct.calcsize("P") * 8,
           "candidate_supplied": library is not None, "runtime_loaded": False, "errors": []}
    if not out["windows"]:
        out["errors"].append("Diagnosi PE disponibile soltanto su Windows")
        return out
    try:
        python = read_pe(sys.executable)
        out["python_machine"] = python["machine"]
        if python["bits"] != out["python_bits"]:
            raise DiagnosisError("Header Python incoerente con il processo")
        if library is not None:
            out.update(compare_architecture(sys.executable, library))
            if not out["architecture_matches"]:
                out["errors"].append("Architettura candidata diversa da Python")
    except DiagnosisError as exc:
        out["errors"].append(str(exc))
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", help="DLL candidata su percorso assoluto esplicito autorizzato")
    args = parser.parse_args(argv)
    out = diagnose(args.library)
    print(json.dumps(out, ensure_ascii=True))
    return 1 if out["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
