"""Unit tests for the Python backend, independent of Flex/Bison artifacts."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CODEGEN_PATH = ROOT / "transpiler" / "Back-end" / "codegen.py"
spec = importlib.util.spec_from_file_location("codegen", CODEGEN_PATH)
assert spec and spec.loader
codegen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(codegen)


def literal(value: int) -> dict[str, object]:
    return {"node_type": "literal", "literal_type": "integer", "value": value}


class CodegenTests(unittest.TestCase):
    def test_main_program_is_valid_javascript(self) -> None:
        ast = {
            "ast": {
                "node_type": "program",
                "children": [
                    {
                        "node_type": "statement_sequence",
                        "children": [
                            {
                                "node_type": "function_declaration",
                                "function_name": "main",
                                "return_type": "int",
                                "parameters": {"children": []},
                                "body": {
                                    "node_type": "block",
                                    "children": [{"node_type": "return", "return_value": literal(7)}],
                                },
                            }
                        ],
                    }
                ],
            }
        }
        javascript = codegen.transpile_ast(ast)
        self.assertIn("function main()", javascript)
        self.assertIn("return 7;", javascript)
        self.assertIn("main();", javascript)
        if shutil.which("node"):
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / "program.js"
                output.write_text(javascript, encoding="utf-8")
                subprocess.run(["node", "--check", str(output)], check=True)

    def test_unknown_ast_node_is_an_error(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unsupported AST node type"):
            codegen.transpile_ast({"ast": {"node_type": "unsupported"}})

    def test_integer_division_uses_c_truncation_toward_zero(self) -> None:
        transpiler = codegen.CToJSTranspiler()
        transpiler.variable_types.update(a="int", b="int")
        expression = {
            "node_type": "binary_operation",
            "operator": "/",
            "left_operand": {"node_type": "identifier", "identifier_name": "a"},
            "right_operand": {"node_type": "identifier", "identifier_name": "b"},
        }
        self.assertEqual(transpiler.transpile_binary_operation(expression), "Math.trunc((a) / (b))")

    def test_float_division_remains_javascript_division(self) -> None:
        transpiler = codegen.CToJSTranspiler()
        expression = {
            "node_type": "binary_operation",
            "operator": "/",
            "left_operand": {"node_type": "literal", "literal_type": "float", "value": 5.0},
            "right_operand": {"node_type": "literal", "literal_type": "integer", "value": 2},
        }
        self.assertEqual(transpiler.transpile_binary_operation(expression), "(5.0 / 2)")

    def test_function_parameters_and_local_ints_use_integer_division(self) -> None:
        ast = {
            "ast": {
                "node_type": "program",
                "children": [
                    {
                        "node_type": "function_declaration",
                        "function_name": "divide",
                        "parameters": {
                            "children": [
                                {"node_type": "variable_declaration", "variable_name": "a", "data_type": "int"},
                                {"node_type": "variable_declaration", "variable_name": "b", "data_type": "int"},
                            ]
                        },
                        "body": {
                            "node_type": "block",
                            "children": [
                                {
                                    "node_type": "variable_declaration",
                                    "variable_name": "local_value",
                                    "data_type": "int",
                                    "initial_value": {
                                        "node_type": "binary_operation",
                                        "operator": "/",
                                        "left_operand": {"node_type": "identifier", "identifier_name": "a"},
                                        "right_operand": {"node_type": "identifier", "identifier_name": "b"},
                                    },
                                }
                            ],
                        },
                    }
                ],
            }
        }
        self.assertIn("Math.trunc((a) / (b))", codegen.transpile_ast(ast))

    def test_negative_integer_division_truncates_toward_zero_in_node(self) -> None:
        if not shutil.which("node"):
            self.skipTest("Node.js is not available")
        result = subprocess.run(
            ["node", "--eval", "console.log(Math.trunc(-5 / 2))"],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.stdout.strip(), "-2")

    def test_parameter_types_do_not_leak_between_functions(self) -> None:
        function = lambda name, data_type: {
            "node_type": "function_declaration",
            "function_name": name,
            "parameters": {"children": [{"node_type": "variable_declaration", "variable_name": "x", "data_type": data_type}]},
            "body": {
                "node_type": "block",
                "children": [
                    {
                        "node_type": "return",
                        "return_value": {
                            "node_type": "binary_operation",
                            "operator": "/",
                            "left_operand": {"node_type": "identifier", "identifier_name": "x"},
                            "right_operand": {"node_type": "literal", "literal_type": "integer", "value": 2},
                        },
                    }
                ],
            },
        }
        javascript = codegen.transpile_ast(
            {"ast": {"node_type": "program", "children": [function("integer", "int"), function("float", "float")]}}
        )
        self.assertIn("function integer(x)", javascript)
        self.assertIn("return Math.trunc((x) / (2));", javascript)
        self.assertIn("function float(x)", javascript)
        self.assertIn("return (x / 2);", javascript)


if __name__ == "__main__":
    unittest.main()
