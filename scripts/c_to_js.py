"""CLI per transpilare un file sorgente C in JavaScript."""

from __future__ import annotations

import argparse
import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.build_transpiler import (  # noqa: E402
    DEFAULT_BINARY_PATH,
    BuildError,
    build_parser,
)

_CODEGEN_PATH = ROOT / "transpiler" / "Back-end" / "codegen.py"
FRONTEND_DIR = ROOT / "transpiler" / "Front-end"
INPUT_DIR = ROOT / "transpiler" / "input"
OUTPUT_DIR = ROOT / "transpiler" / "output"
TRANSPILER_DIR = ROOT / "transpiler" / "build"

DEFAULT_SOURCE = INPUT_DIR / "input.c"
DEFAULT_OUTPUT = OUTPUT_DIR / "output.js"


class PipelineError(RuntimeError):
    """Errore sollevato quando fallisce la pipeline di front-end o back-end."""


def _ensure_directories(*extra: Path) -> None:
    """Garantisce l'esistenza delle directory principali prima di avviare la pipeline."""
    essential = {INPUT_DIR, OUTPUT_DIR, TRANSPILER_DIR, *extra}
    for directory in essential:
        directory.mkdir(parents=True, exist_ok=True)


def _run_parser(parser_binary: Path, source_path: Path, work_dir: Path) -> Path:
    try:
        result = subprocess.run(
            [str(parser_binary)],
            input=source_path.read_text(encoding="utf-8"),
            text=True,
            capture_output=True,
            cwd=work_dir,
            check=False,
        )
    except OSError as exc:
        raise PipelineError(f"Impossibile eseguire il parser: {exc}") from exc

    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or "il parser è terminato senza diagnostica"
        raise PipelineError(f"Errore del parser: {detail}")

    generated_ast = work_dir / "ast.json"
    if not generated_ast.exists():
        raise PipelineError("Il parser non ha generato ast.json")
    return generated_ast


def _load_codegen():
    spec = importlib.util.spec_from_file_location("backend_codegen", _CODEGEN_PATH)
    if spec is None or spec.loader is None:
        raise ImportError(f"Impossibile caricare il modulo codegen da {_CODEGEN_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[attr-defined]
    return module


codegen = _load_codegen()


def compile_to_js(
    source: Path,
    output: Path,
    *,
    parser_path: Optional[Path] = None,
    keep_ast: bool = False,
    rebuild_parser: bool = False,
) -> Path:
    source = source.resolve()
    output = output.resolve()
    _ensure_directories(source.parent, output.parent)

    if not source.exists():
        raise FileNotFoundError(f"Source file not found: {source}")

    parser_binary = (parser_path or DEFAULT_BINARY_PATH).resolve()
    try:
        build_parser(force=rebuild_parser, output_path=parser_binary)
    except BuildError as exc:
        raise PipelineError(str(exc)) from exc

    with tempfile.TemporaryDirectory() as tmpdir:
        ast_temp = _run_parser(parser_binary, source, Path(tmpdir))
        if keep_ast:
            backup_ast = output.with_suffix(".ast.json")
            shutil.copyfile(ast_temp, backup_ast)
        try:
            codegen.transpile_ast_file(ast_temp, output)
        except (OSError, ValueError) as exc:
            raise PipelineError(f"Generazione JavaScript fallita: {exc}") from exc

    return output


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Esegue l'intera pipeline C → JavaScript.",
    )
    parser.add_argument(
        "source",
        nargs="?",
        type=Path,
        default=DEFAULT_SOURCE,
    help=f"File sorgente C (default: {DEFAULT_SOURCE.relative_to(ROOT)})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
    help=f"File JavaScript in uscita (default: {DEFAULT_OUTPUT.relative_to(ROOT)})",
    )
    parser.add_argument(
        "--parser",
        type=Path,
    help="Percorso personalizzato dell'eseguibile del parser (default: transpiler/build/myTranspiler[.exe]).",
    )
    parser.add_argument(
        "--keep-ast",
        action="store_true",
    help="Copia l'AST generato accanto al file JavaScript.",
    )
    parser.add_argument(
        "--rebuild",
        action="store_true",
    help="Forza la ricompilazione del parser prima di eseguire la pipeline.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    cli = build_cli()
    args = cli.parse_args(argv)

    source = args.source if args.source.is_absolute() else args.source.resolve()
    output = args.output if args.output.is_absolute() else args.output.resolve()
    parser_path = (
        args.parser if args.parser is None else args.parser.resolve()
    )

    try:
        target = compile_to_js(
            source,
            output,
            parser_path=parser_path,
            keep_ast=args.keep_ast,
            rebuild_parser=args.rebuild,
        )
    except FileNotFoundError as exc:
        cli.error(str(exc))
    except PipelineError as exc:
        cli.error(str(exc))
    except Exception as exc:  # pragma: no cover - percorso di errore imprevisto
        cli.error(f"Pipeline fallita: {exc}")

    print(f"JavaScript generato in {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = ["PipelineError", "compile_to_js", "main"]
