#!/usr/bin/env python3
"""
Logica principale di generazione del codice per il transpiler C → JavaScript.

Il modulo espone la classe riutilizzabile ``CToJSTranspiler`` e piccoli helper
che caricano un AST da disco e salvano il JavaScript generato. Funziona anche
come entry point da CLI, così da poter essere richiamato dagli script di
automazione.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List


class CToJSTranspiler:
    def __init__(self):
        self.indent_level = 0
        self.indent_size = 2
        self.output_lines = []
        self.declared_variables = set()
        self.variable_types = {}
        self.function_declarations = {}
        self.current_function_name = None
        self.last_printf_message = ""  # Memorizza l'ultimo messaggio di printf per i prompt di scanf
        
    def indent(self) -> str:
        """Genera la stringa di indentazione"""
        return " " * (self.indent_level * self.indent_size)
    
    def add_line(self, line: str = ""):
        """Aggiunge una riga all'output con l'indentazione corretta"""
        if line.strip():
            self.output_lines.append(self.indent() + line)
        else:
            self.output_lines.append("")
    
    def increase_indent(self):
        """Incrementa il livello di indentazione"""
        self.indent_level += 1
    
    def decrease_indent(self):
        """Decrementa il livello di indentazione"""
        self.indent_level = max(0, self.indent_level - 1)

    def strip_enclosing_parens(self, expr: str) -> str:
        """
        Rimuove le parentesi esterne ridondanti da un'espressione.

        Mantiene intatti i raggruppamenti interni e rimuove solo quando la coppia
        più esterna copre l'intera stringa (ad esempio '((a > b))' -> 'a > b').
        """
        result = expr.strip()
        while result.startswith("(") and result.endswith(")"):
            depth = 0
            balanced = True
            for index, char in enumerate(result):
                if char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth < 0:
                        balanced = False
                        break
                    if depth == 0 and index != len(result) - 1:
                        balanced = False
                        break
            if not balanced or depth != 0:
                break
            result = result[1:-1].strip()
        return result
    
    def convert_operator(self, op: str) -> str:
        """Converte gli operatori di C negli operatori di JavaScript"""
        op_map = {
            "==": "===",
            "!=": "!==",
            ">=": ">=",
            "<=": "<=",
            ">": ">",
            "<": "<",
            "+": "+",
            "-": "-",
            "*": "*",
            "/": "/",
        }
        return op_map.get(op, op)
    
    def escape_js_string(self, s: str) -> str:
        """Esegue l'escape di una stringa per l'uso tra doppi apici JavaScript"""
        s = s.replace('\\', '\\\\')
        s = s.replace('"', '\\"')
        s = s.replace('\n', '\\n')
        s = s.replace('\t', '\\t')
        return s
    
    def process_format_string(self, format_str: str) -> tuple[str, List[str]]:
        """Elabora la stringa di formato di printf/scanf ed estrae i placeholder"""
        if not format_str:
            return "", []
        
        conversion_chars = set("diouxXfFeEgGaAcspn")
        placeholders: List[str] = []
        result_parts: List[str] = []
        
        i = 0
        length = len(format_str)
        while i < length:
            ch = format_str[i]
            if ch == '%' and i + 1 < length:
                next_char = format_str[i + 1]
                if next_char == '%':
                    result_parts.append('%')
                    i += 2
                    continue
                
                j = i + 1
                while j < length and format_str[j] not in conversion_chars:
                    j += 1
                if j < length:
                    j += 1  # include lo specificatore di conversione
                    placeholders.append(format_str[i:j])
                    result_parts.append('${}')
                    i = j
                    continue
            result_parts.append(ch)
            i += 1
        
        return "".join(result_parts), placeholders
    
    def transpile_node(self, node: Dict[str, Any]) -> str:
        """Traduce un singolo nodo dell'AST in JavaScript"""
        if not node:
            return ""
        
        node_type = node.get("node_type", "")
        
        if node_type == "program":
            return self.transpile_program(node)
        elif node_type == "statement_sequence":
            return self.transpile_statement_sequence(node)
        elif node_type == "function_declaration":
            return self.transpile_function_declaration(node)
        elif node_type == "variable_declaration":
            return self.transpile_variable_declaration(node)
        elif node_type == "assign":
            return self.transpile_assignment(node)
        elif node_type == "function_call":
            return self.transpile_function_call(node)
        elif node_type == "printf":
            return self.transpile_printf(node)
        elif node_type == "scanf":
            return self.transpile_scanf(node)
        elif node_type == "binary_operation":
            return self.transpile_binary_operation(node)
        elif node_type == "literal":
            return self.transpile_literal(node)
        elif node_type == "identifier":
            return self.transpile_identifier(node)
        elif node_type == "return":
            return self.transpile_return(node)
        elif node_type == "block":
            return self.transpile_block(node)
        elif node_type == "if":
            return self.transpile_if(node)
        elif node_type == "while":
            return self.transpile_while(node)
        elif node_type == "compare":
            return self.transpile_comparison(node)
        else:
            raise ValueError(f"Unsupported AST node type: {node_type or '<missing>'}")
    
    def transpile_program(self, node: Dict[str, Any]) -> str:
        """Traduce il nodo radice del programma"""
        self.add_line()
        
        # Elabora i figli
        children = node.get("children", [])
        for child in children:
            self.transpile_node(child)
        
        # Chiama la funzione main se esiste
        if "main" in self.function_declarations:
            self.add_line()
            self.add_line("// Punto di ingresso")
            self.add_line("main();")
        
        return "\n".join(self.output_lines)
    
    def transpile_statement_sequence(self, node: Dict[str, Any]) -> str:
        """Traduce una sequenza di statement"""
        children = node.get("children", [])
        for child in children:
            result = self.transpile_node(child)
            # Gestisce le chiamate di funzione con valore usate come statement
            if result and child.get("node_type") == "function_call":
                self.add_line(result + ";")
        return ""
    
    def transpile_function_declaration(self, node: Dict[str, Any]) -> str:
        """Traduce una dichiarazione di funzione"""
        func_name = node.get("function_name", "unnamed")
        return_type = node.get("return_type", "void")
        parameters = node.get("parameters", {})
        body = node.get("body", {})
        
        # Memorizza le informazioni della funzione
        self.function_declarations[func_name] = {
            "return_type": return_type,
            "parameters": parameters
        }

        # Genera la firma della funzione
        param_list = []
        if parameters and "children" in parameters:
            for param in parameters["children"]:
                if param.get("node_type") == "variable_declaration":
                    param_name = param.get("variable_name", "param")
                    param_list.append(param_name)
        
        params_str = ", ".join(param_list)
        
        # Salva l'output corrente e il livello di indentazione
        old_output = self.output_lines
        old_indent = self.indent_level
        old_variable_types = self.variable_types
        
        # Crea un buffer temporaneo per il corpo
        self.output_lines = []
        self.indent_level = 0  # Parte da indentazione 0, che verrà aggiunta in seguito
        self.variable_types = old_variable_types.copy()
        if parameters and "children" in parameters:
            for parameter in parameters["children"]:
                if parameter.get("node_type") == "variable_declaration":
                    self.variable_types[parameter.get("variable_name", "")] = parameter.get("data_type")
        
        # Imposta il nome della funzione corrente ed elabora il corpo
        prev_function = self.current_function_name
        self.current_function_name = func_name
        
        # Traduce il corpo della funzione
        if body:
            self.transpile_node(body)
        
        self.current_function_name = prev_function
        
        # Recupera le righe del corpo e ripristina l'output
        body_lines = self.output_lines
        self.output_lines = old_output
        self.indent_level = old_indent
        self.variable_types = old_variable_types
        
        # Scrive la firma della funzione
        self.add_line(f"function {func_name}({params_str}) {{")
        self.increase_indent()
        
        # Aggiunge le righe del corpo con l'indentazione corretta
        for line in body_lines:
            if line.strip():
                self.output_lines.append(self.indent() + line)
            else:
                self.output_lines.append("")
        
        self.decrease_indent()
        self.add_line("}")
        self.add_line()
        
        return ""
    
    def transpile_variable_declaration(self, node: Dict[str, Any]) -> str:
        """Traduce una dichiarazione di variabile"""
        var_name = node.get("variable_name", "var")
        data_type = node.get("data_type", "int")
        initial_value = node.get("initial_value")
        
        self.declared_variables.add(var_name)
        self.variable_types[var_name] = data_type
        
        if initial_value:
            init_val = self.transpile_node(initial_value)
            self.add_line(f"let {var_name} = {init_val};")
        else:
            # Inizializza con un valore predefinito appropriato
            default_values = {
                "int": "0",
                "float": "0.0",
                "char": "''",
                "void": "null"
            }
            default_val = default_values.get(data_type, "null")
            self.add_line(f"let {var_name} = {default_val};")
        
        return ""
    
    def transpile_assignment(self, node: Dict[str, Any]) -> str:
        """Traduce un'assegnazione"""
        target = node.get("target", "var")
        value = node.get("value", {})
        
        value_str = self.transpile_node(value)
        self.add_line(f"{target} = {value_str};")
        
        return ""
    
    def transpile_function_call(self, node: Dict[str, Any]) -> str:
        """Traduce una chiamata di funzione"""
        func_name = node.get("function_name", "func")
        arguments = node.get("arguments", {})
        
        args_list = []
        if arguments and "children" in arguments:
            for arg in arguments["children"]:
                arg_str = self.transpile_node(arg)
                if arg_str:
                    args_list.append(arg_str)
        
        args_str = ", ".join(args_list)
        
        # Per le espressioni restituisce la chiamata; per gli statement aggiunge una riga
        call_str = f"{func_name}({args_str})"
        
        # Restituisce la chiamata come stringa da usare nelle espressioni
        return call_str
    
    def transpile_printf(self, node: Dict[str, Any]) -> str:
        """Traduce una printf usando console.log"""
        format_str = node.get("format", "") or ""
        arguments = node.get("printf_arguments", {})
        
        # Elabora la stringa di formato
        clean_format, placeholders = self.process_format_string(format_str)
        # console.log terminates the line itself; retaining a final C newline would
        # produce an observable extra blank line in both Node and browser consoles.
        if clean_format.endswith("\n"):
            clean_format = clean_format[:-1]
        
        # Salva il messaggio per un eventuale utilizzo nella scanf successiva
        prompt_memory = clean_format.replace('${}', '').replace('\n', ' ').replace('\t', ' ').strip()
        self.last_printf_message = prompt_memory
        
        args_list = []
        if arguments and "children" in arguments:
            for arg in arguments["children"]:
                arg_str = self.transpile_node(arg)
                if arg_str:
                    args_list.append(arg_str)
        
        if args_list:
            # Usa template literal per l'output formattato
            # Esegue l'escape di backtick e ${ per evitare interpretazioni indesiderate
            clean_format = clean_format.replace('`', '\\`')
            clean_format = clean_format.replace('\r', '\\r').replace('\n', '\\n').replace('\t', '\\t')
            # Sostituisce temporaneamente i placeholder con un marcatore provvisorio
            temp_marker = "TEMP_MARKER"
            clean_format = clean_format.replace('${}', temp_marker)
            clean_format = clean_format.replace('${', '\\${')
            clean_format = clean_format.replace(temp_marker, '${}')
            
            template = clean_format
            for arg in args_list:
                template = template.replace('${}', f'${{{arg}}}', 1)
            self.add_line(f'console.log(`{template}`);')
        else:
            # Output di stringhe semplice: usa doppi apici ed esegue l'escape dei caratteri speciali
            clean_format = self.escape_js_string(clean_format)
            self.add_line(f'console.log("{clean_format}");')
        
        return ""
    
    def transpile_scanf(self, node: Dict[str, Any]) -> str:
        """Traduce una scanf usando prompt e conversioni tipizzate"""
        format_str = node.get("format", "") or ""
        arguments = node.get("scanf_arguments", {})
        
        clean_format, placeholders = self.process_format_string(format_str)
        prompt_seed = self.last_printf_message if self.last_printf_message else clean_format.replace('${}', '').strip()
        self.last_printf_message = ""
        
        args_children = arguments.get("children", []) if arguments and "children" in arguments else []
        if not args_children:
            return ""
        
        if len(placeholders) < len(args_children):
            placeholders.extend(['%s'] * (len(args_children) - len(placeholders)))
        elif len(placeholders) > len(args_children):
            placeholders = placeholders[:len(args_children)]
        
        conversion_defaults = {
            'd': ('Number.parseInt', 10),
            'i': ('Number.parseInt', 10),
            'u': ('Number.parseInt', 10),
            'o': ('Number.parseInt', 8),
            'x': ('Number.parseInt', 16),
            'X': ('Number.parseInt', 16),
            'f': ('Number.parseFloat', None),
            'F': ('Number.parseFloat', None),
            'e': ('Number.parseFloat', None),
            'E': ('Number.parseFloat', None),
            'g': ('Number.parseFloat', None),
            'G': ('Number.parseFloat', None),
            'a': ('Number.parseFloat', None),
            'A': ('Number.parseFloat', None),
            'c': ('char', None),
            's': ('string', None),
            'p': ('string', None)
        }
        
        total_args = len(args_children)
        prompt_seed = (prompt_seed or "").strip()
        
        for arg, placeholder in zip(args_children, placeholders):
            if arg.get("node_type") != "identifier":
                continue
            
            var_name = arg.get("identifier_name", "")
            if var_name.startswith("&"):
                var_name = var_name[1:]
            
            conversion_char = placeholder[-1] if placeholder else 's'
            conversion_info = conversion_defaults.get(conversion_char, ('string', None))
            
            base_prompt = prompt_seed
            if not base_prompt:
                base_prompt = f"Enter value for {var_name}"
            elif total_args > 1:
                base_prompt = f"{base_prompt} ({var_name})"
            base_prompt = base_prompt.strip()
            if not base_prompt:
                base_prompt = f"Enter value for {var_name}"
            
            escaped_prompt = self.escape_js_string(base_prompt)
            prompt_call = f'prompt("{escaped_prompt}")'
            
            if conversion_info[0] == 'Number.parseInt':
                base = conversion_info[1] or 10
                self.add_line(f'{var_name} = Number.parseInt({prompt_call}, {base}) || 0;')
            elif conversion_info[0] == 'Number.parseFloat':
                self.add_line(f'{var_name} = Number.parseFloat({prompt_call}) || 0.0;')
            elif conversion_info[0] == 'char':
                self.add_line(f'{var_name} = ({prompt_call} || "").charAt(0);')
            else:
                self.add_line(f'{var_name} = {prompt_call} || "";')
        
        return ""
    
    def transpile_binary_operation(self, node: Dict[str, Any]) -> str:
        """Traduce un'operazione binaria"""
        operator = node.get("operator", "+")
        left = node.get("left_operand", {})
        right = node.get("right_operand", {})
        
        left_str = self.transpile_node(left)
        right_str = self.transpile_node(right)
        if operator == "/" and self._is_integer_expression(left) and self._is_integer_expression(right):
            # C99 integer division truncates toward zero; JavaScript '/' does not.
            return f"Math.trunc(({left_str}) / ({right_str}))"

        js_op = self.convert_operator(operator)
        
        return f"({left_str} {js_op} {right_str})"

    def _is_integer_expression(self, node: Dict[str, Any]) -> bool:
        """Return whether the supported AST proves an expression has C int semantics."""
        node_type = node.get("node_type")
        if node_type == "literal":
            return node.get("literal_type") == "integer"
        if node_type == "identifier":
            return self.variable_types.get(node.get("identifier_name")) == "int"
        if node_type == "binary_operation":
            return (
                node.get("operator") in {"+", "-", "*", "/"}
                and self._is_integer_expression(node.get("left_operand", {}))
                and self._is_integer_expression(node.get("right_operand", {}))
            )
        return False
    
    def transpile_literal(self, node: Dict[str, Any]) -> str:
        """Traduce un valore letterale"""
        literal_type = node.get("literal_type", "integer")
        value = node.get("value")
        
        if literal_type == "integer":
            return str(value)
        elif literal_type == "float":
            return str(value)
        elif literal_type == "character":
            char_value = value if value is not None else ''
            escaped = self.escape_js_string(str(char_value))
            return f'"{escaped}"'
        elif literal_type == "string":
            text_value = value if value is not None else ''
            escaped = self.escape_js_string(str(text_value))
            return f'"{escaped}"'
        else:
            return str(value)
    
    def transpile_identifier(self, node: Dict[str, Any]) -> str:
        """Traduce un identificatore"""
        name = node.get("identifier_name", "var")
        # Rimuove il prefisso & per gli indirizzi
        if name.startswith("&"):
            name = name[1:]
        return name
    
    def transpile_return(self, node: Dict[str, Any]) -> str:
        """Traduce un'istruzione return"""
        return_value = node.get("return_value", {})
        
        if return_value:
            value_str = self.transpile_node(return_value)
            self.add_line(f"return {value_str};")
        else:
            self.add_line("return;")
        
        return ""
    
    def transpile_block(self, node: Dict[str, Any]) -> str:
        """Traduce un blocco di codice"""
        children = node.get("children", [])
        for child in children:
            self.transpile_node(child)
        return ""
    
    def transpile_if(self, node: Dict[str, Any]) -> str:
        """Traduce un'istruzione if"""
        condition = node.get("condition", {})
        then_branch = node.get("then_branch", {})
        else_branch = node.get("else_branch", {})
        
        cond_str = self.strip_enclosing_parens(self.transpile_node(condition))
        
        self.add_line(f"if ({cond_str}) {{")
        self.increase_indent()
        self.transpile_node(then_branch)
        self.decrease_indent()
        
        if else_branch:
            self.add_line("} else {")
            self.increase_indent()
            self.transpile_node(else_branch)
            self.decrease_indent()
        
        self.add_line("}")
        return ""
    
    def transpile_while(self, node: Dict[str, Any]) -> str:
        """Traduce un ciclo while"""
        condition = node.get("condition", {})
        body = node.get("body", {})
        
        cond_str = self.strip_enclosing_parens(self.transpile_node(condition))
        
        self.add_line(f"while ({cond_str}) {{")
        self.increase_indent()
        self.transpile_node(body)
        self.decrease_indent()
        self.add_line("}")
        
        return ""
    
    def transpile_comparison(self, node: Dict[str, Any]) -> str:
        """Traduce un'operazione di confronto"""
        operator = node.get("comparison_operator", "==")
        left = node.get("left_operand", {})
        right = node.get("right_operand", {})
        
        left_str = self.transpile_node(left)
        right_str = self.transpile_node(right)
        js_op = self.convert_operator(operator)
        
        return f"({left_str} {js_op} {right_str})"


def transpile_ast(ast_payload: Any) -> str:
    """
    Traduce in JavaScript un payload di AST già caricato come oggetto Python.

    Il payload può essere direttamente il nodo radice oppure un oggetto che
    contiene la chiave ``ast``, in linea con quanto prodotto dal front-end.
    """
    root = ast_payload.get("ast") if isinstance(ast_payload, dict) else ast_payload
    transpiler = CToJSTranspiler()
    return transpiler.transpile_node(root or {})


def transpile_ast_file(input_path: Path | str, output_path: Path | str) -> str:
    """
    Carica un AST da ``input_path``, genera il JavaScript e lo scrive in ``output_path``.

    Restituisce il codice sorgente JavaScript generato.
    """
    input_file = Path(input_path)
    output_file = Path(output_path)

    if not input_file.exists():
        raise FileNotFoundError(f"Input AST file not found: {input_file}")

    try:
        ast_payload = json.loads(input_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {input_file}: {exc}") from exc

    js_code = transpile_ast(ast_payload)
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(js_code, encoding="utf-8")
    return js_code


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Converte un AST JSON generato dal parser in codice JavaScript.",
    )
    parser.add_argument("input_ast", type=Path, help="AST JSON prodotto dal front-end C.")
    parser.add_argument("output_js", type=Path, help="Percorso di destinazione per il JavaScript generato.")
    return parser


def main(argv: List[str] | None = None) -> int:
    parser = build_cli()
    args = parser.parse_args(argv)

    try:
        transpile_ast_file(args.input_ast, args.output_js)
    except FileNotFoundError as exc:
        parser.error(str(exc))
    except ValueError as exc:
        parser.error(str(exc))
    except Exception as exc:  # pragma: no cover - percorso di errore imprevisto
        parser.error(f"Transpilazione fallita: {exc}")

    print(f"JavaScript scritto in {args.output_js.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = ["CToJSTranspiler", "transpile_ast", "transpile_ast_file", "main"]
