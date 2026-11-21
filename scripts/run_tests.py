"""Esegue i test di regressione ed esporta risultati leggibili."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.build_transpiler import (  # noqa: E402
    DEFAULT_BINARY_PATH,
    BuildError,
    build_parser,
)
from scripts.c_to_js import PipelineError, compile_to_js  # noqa: E402

FRONTEND_DIR = ROOT / "transpiler" / "Front-end"
TESTS_DIR = ROOT / "tests"
OK_TESTS_DIR = TESTS_DIR / "ok"
ERR_TESTS_DIR = TESTS_DIR / "error"
RESULTS_DIR = TESTS_DIR / "results"
RESULTS_OK_DIR = RESULTS_DIR / "ok"
RESULTS_ERR_DIR = RESULTS_DIR / "err"
INPUT_DIR = ROOT / "transpiler" / "input"
OUTPUT_DIR = ROOT / "transpiler" / "output"
TRANSPILER_DIR = ROOT / "transpiler" / "build"

@dataclass
class CaseResult:
    name: str
    passed: bool
    message: str
    result_path: Path | None = None
    source_path: Path | None = None
    ast_path: Path | None = None
    artifact_label: str = ""


class TestRunError(RuntimeError):
    """Errore sollevato quando l'esecuzione dei test non può completarsi."""


def _ensure_base_directories() -> None:
    for directory in (
        INPUT_DIR,
        OUTPUT_DIR,
        RESULTS_DIR,
        RESULTS_OK_DIR,
        RESULTS_ERR_DIR,
        TRANSPILER_DIR,
    ):
        directory.mkdir(parents=True, exist_ok=True)


def _clear_directory(path: Path) -> None:
    if path.exists():
        for item in path.iterdir():
            if item.is_file():
                item.unlink()
            elif item.is_dir():
                shutil.rmtree(item)
    path.mkdir(parents=True, exist_ok=True)


def _iter_test_files(path: Path) -> Iterable[Path]:
    if not path.exists():
        return []
    return sorted(p for p in path.glob("*.c") if p.is_file())


def _run_parser_raw(parser_binary: Path, source_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(parser_binary)],
        input=source_path.read_text(encoding="utf-8"),
        text=True,
        capture_output=True,
        cwd=FRONTEND_DIR,
        check=False,
    )


def run_ok_tests(parser_binary: Path) -> list[CaseResult]:
    _clear_directory(RESULTS_OK_DIR)
    results: list[CaseResult] = []

    for source in _iter_test_files(OK_TESTS_DIR):
        name = source.stem
        output_file = RESULTS_OK_DIR / f"{name}.js"

        try:
            compile_to_js(
                source,
                output_file,
                parser_path=parser_binary,
                keep_ast=True,
            )
        except (PipelineError, FileNotFoundError) as exc:
            results.append(
                CaseResult(
                    name=name,
                    passed=False,
                    message=str(exc),
                    source_path=source,
                    artifact_label="JavaScript",
                )
            )
            continue

        if not output_file.exists():
            results.append(
                CaseResult(
                    name=name,
                    passed=False,
                    message="Pipeline completata ma non è stato prodotto alcun JavaScript.",
                    source_path=source,
                    artifact_label="JavaScript",
                )
            )
            continue

        ast_candidate = output_file.with_suffix(".ast.json")
        ast_path = ast_candidate if ast_candidate.exists() else None
        message = "JavaScript generato"

        results.append(
            CaseResult(
                name=name,
                passed=True,
                message=message,
                result_path=output_file,
                source_path=source,
                ast_path=ast_path,
                artifact_label="JavaScript",
            )
        )

    return results


def run_error_tests(parser_binary: Path) -> list[CaseResult]:
    _clear_directory(RESULTS_ERR_DIR)
    results: list[CaseResult] = []

    for source in _iter_test_files(ERR_TESTS_DIR):
        name = source.stem

        result = _run_parser_raw(parser_binary, source)
        output_file = RESULTS_ERR_DIR / f"{name}.txt"
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        diagnostic = stderr or stdout or "il parser non ha prodotto diagnostica"

        output_file.write_text(diagnostic + "\n", encoding="utf-8")

        passed = result.returncode != 0
        message = (
            "Diagnostica acquisita" if passed else "Il parser è terminato con successo inaspettatamente"
        )

        results.append(
            CaseResult(
                name=name,
                passed=passed,
                message=message,
                result_path=output_file,
                source_path=source,
                artifact_label="Diagnostica",
            )
        )

    return results


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Esegue le suite di regressione OK/ERROR.")
    parser.add_argument(
        "--parser",
        type=Path,
        help="Eseguibile del parser personalizzato; default transpiler/build/myTranspiler[.exe].",
    )
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="Forza la ricompilazione del parser prima di eseguire i test.",
    )
    parser.add_argument(
        "--skip-error",
        action="store_true",
        help="Salta la suite di errore (esegue solo i test OK).",
    )
    parser.add_argument(
        "--skip-ok",
        action="store_true",
        help="Salta la suite OK (esegue solo i test di errore).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    cli = build_cli()
    args = cli.parse_args(argv)

    _ensure_base_directories()

    parser_binary = (args.parser or DEFAULT_BINARY_PATH).resolve()
    try:
        build_parser(
            force=args.rebuild,
            skip_generation=not args.rebuild,
            output_path=parser_binary,
        )
    except BuildError as exc:
        cli.error(str(exc))

    overall_success = True

    if not args.skip_ok:
        ok_results = run_ok_tests(parser_binary)
        print("== Test OK ==")
        for case in ok_results:
            status = "OK" if case.passed else "FALLITO"
            print(f"[{status}] {case.name}: {case.message}")
        overall_success = overall_success and all(case.passed for case in ok_results)

    if not args.skip_error:
        err_results = run_error_tests(parser_binary)
        print("\n== Test ERRORE ==")
        for case in err_results:
            status = "OK" if case.passed else "FALLITO"
            print(f"[{status}] {case.name}: {case.message}")
        overall_success = overall_success and all(case.passed for case in err_results)

    return 0 if overall_success else 1


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = ["run_ok_tests", "run_error_tests", "main"]
