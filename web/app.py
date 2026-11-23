#!/usr/bin/env python3
"""
Interfaccia web Flask per il transpiler da C a JavaScript.
"""

from __future__ import annotations

import sys
import tempfile
import threading
import traceback
from pathlib import Path

from flask import Flask, abort, jsonify, render_template, request, send_from_directory

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.build_transpiler import (  # noqa: E402
    DEFAULT_BINARY_PATH,
    BuildError,
    build_parser,
)
from scripts.c_to_js import (  # noqa: E402
    PipelineError,
    compile_to_js,
)
import scripts.c_to_js as pipeline_module  # noqa: E402
import scripts.run_tests as regression  # noqa: E402

INPUT_DIR = ROOT / "transpiler" / "input"
OUTPUT_DIR = ROOT / "transpiler" / "output"
RESULTS_DIR = ROOT / "tests" / "results"
RESULTS_OK_DIR = RESULTS_DIR / "ok"
RESULTS_ERR_DIR = RESULTS_DIR / "err"
ALLOWED_FILE_ROOTS = (
    OUTPUT_DIR,
    RESULTS_OK_DIR,
    RESULTS_ERR_DIR,
)
PIPELINE_LOCK = threading.Lock()

app = Flask(
    __name__,
    template_folder=str(Path(__file__).parent / "templates"),
    static_folder=str(Path(__file__).parent / "static"),
)


def _ensure_directories() -> None:
    for directory in (
        INPUT_DIR,
        OUTPUT_DIR,
        RESULTS_DIR,
        RESULTS_OK_DIR,
        RESULTS_ERR_DIR,
        pipeline_module.TRANSPILER_DIR,
    ):
        directory.mkdir(parents=True, exist_ok=True)


def _resolve_artifact_path(relative_path: str) -> Path:
    target = (ROOT / relative_path).resolve()
    allowed = [root.resolve() for root in ALLOWED_FILE_ROOTS]
    if any(root == target or root in target.parents for root in allowed):
        return target
    raise ValueError(f"Access to '{relative_path}' is not permitted.")


def _read_text(path: Path | None) -> str:
    if not path:
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


@app.route("/", methods=["GET"])
def index() -> str:
    return render_template("index.html")


@app.post("/api/build")
def build_parser_endpoint():
    _ensure_directories()
    data = request.get_json(silent=True) or {}
    force = bool(data.get("force", False))
    try:
        with PIPELINE_LOCK:
            target = build_parser(
                force=force,
                skip_generation=not force,
                output_path=DEFAULT_BINARY_PATH,
            )
    except BuildError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500
    return jsonify({"ok": True, "parser": str(target.relative_to(ROOT))})


@app.post("/api/transpile")
def transpile_endpoint():
    data = request.get_json(silent=True) or {}
    source_code = data.get("source", "")

    if not isinstance(source_code, str) or not source_code.strip():
        return jsonify({"ok": False, "error": "Fornire un sorgente C non vuoto."}), 400

    _ensure_directories()
    try:
        with tempfile.TemporaryDirectory(prefix="c-to-js-") as temp_dir:
            workspace = Path(temp_dir)
            source_path = workspace / "input.c"
            output_path = workspace / "output.js"
            source_path.write_text(source_code, encoding="utf-8")
            result = compile_to_js(
                source_path,
                output_path,
                parser_path=None,
                keep_ast=True,
                rebuild_parser=False,
            )
            js_code = result.read_text(encoding="utf-8")
            ast_path = result.with_suffix(".ast.json")
            ast_code = ast_path.read_text(encoding="utf-8") if ast_path.exists() else ""
    except (PipelineError, FileNotFoundError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500
    except Exception as exc:  # pragma: no cover
        traceback.print_exc()
        return jsonify({"ok": False, "error": f"Errore imprevisto: {exc}"}), 500

    return jsonify(
        {
            "ok": True,
            "js": js_code,
            "js_path": "",
            "ast": ast_code,
            "ast_path": "",
        }
    )


@app.post("/api/run-tests")
def run_tests_endpoint():
    _ensure_directories()
    try:
        with PIPELINE_LOCK:
            parser_binary = build_parser(
                force=False,
                skip_generation=True,
                output_path=DEFAULT_BINARY_PATH,
            )
            ok_cases = regression.run_ok_tests(parser_binary)
            err_cases = regression.run_error_tests(parser_binary)
        all_cases = ok_cases + err_cases
        overall_success = all(case.passed for case in all_cases)

        def rel_path(path: Path | None) -> str:
            return str(path.relative_to(ROOT)) if path else ""

        def file_name(path: Path | None) -> str:
            return path.name if path else ""

        ok_payload = []
        for case in ok_cases:
            ok_payload.append(
                {
                    "name": case.name,
                    "passed": case.passed,
                    "message": case.message,
                    "artifact": rel_path(case.result_path),
                    "artifactLabel": case.artifact_label or "JavaScript",
                    "artifactName": file_name(case.result_path),
                    "artifactContent": _read_text(case.result_path),
                    "source": rel_path(case.source_path),
                    "sourceName": file_name(case.source_path),
                    "sourceContent": _read_text(case.source_path),
                    "ast": rel_path(case.ast_path),
                    "astContent": _read_text(case.ast_path),
                }
            )

        err_payload = []
        for case in err_cases:
            err_payload.append(
                {
                    "name": case.name,
                    "passed": case.passed,
                    "message": case.message,
                    "artifact": rel_path(case.result_path),
                    "artifactLabel": case.artifact_label or "Diagnostica",
                    "artifactName": file_name(case.result_path),
                    "artifactContent": _read_text(case.result_path),
                    "source": rel_path(case.source_path),
                    "sourceName": file_name(case.source_path),
                    "sourceContent": _read_text(case.source_path),
                }
            )

        results_payload = {"ok": ok_payload, "error": err_payload}

    except Exception as exc:  # pragma: no cover
        traceback.print_exc()
        return jsonify({"ok": False, "error": f"Errore imprevisto: {exc}"}), 500
    return jsonify(
        {
            "ok": True,
            "exitCode": 0 if overall_success else 1,
            "results": results_payload,
        }
    )


@app.get("/files/<path:relative_path>")
def serve_artifact(relative_path: str):
    _ensure_directories()
    try:
        target = _resolve_artifact_path(relative_path)
    except ValueError:
        abort(404)
    if not target.exists() or not target.is_file():
        abort(404)
    return send_from_directory(target.parent, target.name, as_attachment=False)


def main() -> int:
    _ensure_directories()
    app.run(host="127.0.0.1", port=5000, debug=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
