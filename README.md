# C to JavaScript Transpiler

An experimental compiler pipeline that translates a defined subset of C into JavaScript. The project combines a Flex scanner, Bison parser, C-based AST and semantic checks, Python code generation, regression tests, and a local Flask interface.

> This is an educational compiler project, not a full ISO C implementation. It accepts only the language constructs covered by its grammar and semantic rules.

## Highlights

- Scanner built with Flex and parser built with Bison.
- Abstract syntax tree, symbol table, and type-checking stages implemented in C.
- Python backend that converts the generated AST into JavaScript.
- CLI for build and transpilation.
- Regression suite with valid and invalid C programs.
- Local web interface for building, transpiling, inspecting the AST, and running the test suites.

## Requirements

- Linux, macOS, or WSL with Python 3.10+.
- Flex 2.6+, Bison 3.8+, and a C11 compiler such as GCC or Clang.
- Flask for the optional local web interface.

On Ubuntu/WSL:

```bash
sudo apt update
sudo apt install -y build-essential flex bison python3 python3-venv
```

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python scripts/run_tests.py --rebuild
```

The test command rebuilds the scanner/parser and runs three valid-input and three invalid-input regression cases.

## Transpile a C source file

```bash
python scripts/c_to_js.py transpiler/input/input.c \
  --output transpiler/output/output.js \
  --keep-ast
```

This creates the JavaScript output and, with `--keep-ast`, an adjacent JSON representation of the AST.

## Local web interface

```bash
python web/app.py
```

Open `http://127.0.0.1:5000`. The interface remains local-only and can build the parser, transpile pasted C code, display generated JavaScript/AST, and show regression-test artefacts.

## Architecture

```text
C source
  -> Flex scanner + Bison parser
  -> AST / symbol table / type checks (C)
  -> AST JSON
  -> JavaScript code generation (Python)
```

- `transpiler/Front-end/` contains grammar, scanner, AST, and semantic analysis.
- `transpiler/Back-end/codegen.py` emits JavaScript from AST JSON.
- `scripts/` provides reproducible build, transpilation, and test commands.
- `web/` hosts the local Flask demonstration interface.
- `tests/` contains accepted and rejected C inputs.

## Scope and limitations

- The project deliberately supports a subset of C, not the full standard library or all ISO C syntax.
- Bison currently reports shift/reduce and reduce/reduce conflicts while generating the grammar. The documented regression suite passes, but unsupported or ambiguous syntax should be treated as out of scope.
- The tests validate parsing, diagnostic behavior, AST generation, and JavaScript emission; they do not prove semantic equivalence for every C program.

## Additional setup notes

See [docs/SETUP.md](docs/SETUP.md) for Windows/WSL troubleshooting and detailed setup guidance.
