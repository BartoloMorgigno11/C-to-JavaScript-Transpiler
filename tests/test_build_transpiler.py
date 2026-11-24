"""Build freshness and clean-clone generation tests."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import build_transpiler as build


class BuildTranspilerTests(unittest.TestCase):
    def test_missing_generated_sources_override_skip_generation(self) -> None:
        output = Path("synthetic-parser")
        with (
            patch.object(build, "BISON_C", Path("missing-parser.tab.c")),
            patch.object(build, "BISON_H", Path("missing-parser.tab.h")),
            patch.object(build, "FLEX_C", Path("missing-lex.yy.c")),
            patch.object(build, "_ensure_grammar_sources") as generate,
            patch.object(build, "_select_compiler", return_value="gcc"),
            patch.object(build, "_compile"),
        ):
            build.build_parser(skip_generation=True, output_path=output)
        generate.assert_called_once_with(skip_generation=False)


if __name__ == "__main__":
    unittest.main()
