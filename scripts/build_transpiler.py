"""Compila o ricompila il front-end C (scanner + parser) dentro ``transpiler/``."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRONTEND_DIR = ROOT / "transpiler" / "Front-end"
TRANSPILER_DIR = ROOT / "transpiler" / "build"

IS_WINDOWS = os.name == "nt"
DEFAULT_BINARY_NAME = "myTranspiler.exe" if IS_WINDOWS else "myTranspiler"
DEFAULT_BINARY_PATH = TRANSPILER_DIR / DEFAULT_BINARY_NAME

BISON_SOURCE = FRONTEND_DIR / "Parser" / "parser.y"
FLEX_SOURCE = FRONTEND_DIR / "Scanner" / "scanner.l"
BISON_C = FRONTEND_DIR / "Parser" / "parser.tab.c"
BISON_H = FRONTEND_DIR / "Parser" / "parser.tab.h"
FLEX_C = FRONTEND_DIR / "Scanner" / "lex.yy.c"

SOURCE_FILES = [
    "Parser/parser.tab.c",
    "Parser/ast.c",
    "Parser/symbol_table.c",
    "Parser/type_checking.c",
    "Scanner/lex.yy.c",
]

BUILD_INPUTS = [
    BISON_SOURCE,
    FLEX_SOURCE,
    *[FRONTEND_DIR / source for source in SOURCE_FILES[1:]],
    FRONTEND_DIR / "Parser" / "ast.h",
    FRONTEND_DIR / "Parser" / "symbol_table.h",
    FRONTEND_DIR / "Parser" / "type_checking.h",
]


class BuildError(RuntimeError):
    """Errore sollevato quando il processo di build fallisce."""


def _resolve_tool(name: str, *, env_var: str | None = None) -> str:
    if env_var:
        candidate = os.getenv(env_var)
        if candidate and shutil.which(candidate):
            return candidate
    path = shutil.which(name)
    if path:
        return path
    hint = f" (override con ${env_var})" if env_var else ""
    raise BuildError(f"Strumento '{name}' non trovato{hint}.")


def _ensure_grammar_sources(*, skip_generation: bool = False) -> None:
    if skip_generation:
        return

    bison = _resolve_tool("bison", env_var="BISON")
    flex = _resolve_tool("flex", env_var="FLEX")

    try:
        subprocess.run(
            [bison, "-d", "-o", str(BISON_C), str(BISON_SOURCE)],
            cwd=FRONTEND_DIR,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise BuildError(f"Bison fallito con codice di uscita {exc.returncode}.") from exc

    try:
        subprocess.run(
            [flex, "-o", str(FLEX_C), str(FLEX_SOURCE)],
            cwd=FRONTEND_DIR,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise BuildError(f"Flex fallito con codice di uscita {exc.returncode}.") from exc


def _select_compiler() -> str:
    cc = os.getenv("CC")
    if cc and shutil.which(cc):
        return cc
    for candidate in ("gcc", "clang"):
        if shutil.which(candidate):
            return candidate
    raise BuildError("Nessun compilatore C adatto trovato (cercati CC, gcc, clang).")


def _compose_compile_command(compiler: str, output_path: Path) -> list[str]:
    cmd: list[str] = [compiler, "-std=c11", "-D_POSIX_C_SOURCE=200809L"]
    if IS_WINDOWS:
        cmd.extend(["-DYY_NO_UNISTD_H"])
    cmd.extend(["-IParser", "-IScanner"])
    cmd.extend(SOURCE_FILES)
    cmd.extend(["-o", str(output_path)])
    if platform.system() != "Windows":
        cmd.append("-lfl")
    return cmd


def _compile(compiler: str, output_path: Path) -> None:
    TRANSPILER_DIR.mkdir(parents=True, exist_ok=True)
    cmd = _compose_compile_command(compiler, output_path)
    try:
        subprocess.run(cmd, cwd=FRONTEND_DIR, check=True)
    except subprocess.CalledProcessError as exc:
        cmd_str = " ".join(cmd)
        raise BuildError(
            f"Compilazione fallita (exit code {exc.returncode}). Comando: {cmd_str}"
        ) from exc


def build_parser(
    *,
    force: bool = False,
    skip_generation: bool = False,
    output_path: Path | None = None,
) -> Path:
    target = (output_path or DEFAULT_BINARY_PATH).resolve()
    if not force and target.exists() and all(
        source.exists() and source.stat().st_mtime <= target.stat().st_mtime
        for source in BUILD_INPUTS
    ):
        return target

    _ensure_grammar_sources(skip_generation=skip_generation)
    compiler = _select_compiler()
    _compile(compiler, target)
    return target


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Produce l'eseguibile del parser in transpiler/build/.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Forza la ricompilazione anche se l'eseguibile esiste già.",
    )
    parser.add_argument(
        "--skip-grammar",
        action="store_true",
        help="Salta l'esecuzione di flex/bison (utile se le sorgenti sono già generate).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_BINARY_PATH,
        help=f"Percorso di destinazione dell'eseguibile del parser (default: {DEFAULT_BINARY_NAME}).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_cli()
    args = parser.parse_args(argv)

    try:
        target = build_parser(
            force=args.force,
            skip_generation=args.skip_grammar,
            output_path=args.output,
        )
    except BuildError as exc:
        parser.error(str(exc))
    except Exception as exc:  # pragma: no cover - unexpected failure path
        parser.error(f"Errore di build imprevisto: {exc}")

    print(f"Transpiler disponibile in {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = ["BuildError", "build_parser", "DEFAULT_BINARY_PATH", "main"]
