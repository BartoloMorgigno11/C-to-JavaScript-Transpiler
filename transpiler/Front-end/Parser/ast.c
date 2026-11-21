/* ast.c */
#include "ast.h"

// Variabile globale per il root dell'AST
ASTNode *ast_root = NULL;

char *xstrdup(const char *src) {
    if (!src) {
        return NULL;
    }
    size_t len = strlen(src) + 1;
    char *copy = malloc(len);
    if (!copy) {
        fprintf(stderr, "Errore: memoria insufficiente\n");
        exit(EXIT_FAILURE);
    }
    memcpy(copy, src, len);
    return copy;
}

static char* escape_json_string(const char *value) {
    if (!value) {
        return xstrdup("");
    }

    size_t len = 0;
    for (const unsigned char *p = (const unsigned char *)value; *p; ++p) {
        switch (*p) {
            case '\"':
            case '\\':
                len += 2;
                break;
            case '\b':
            case '\f':
            case '\n':
            case '\r':
            case '\t':
                len += 2;
                break;
            default:
                if (*p < 0x20) {
                    len += 6;
                } else {
                    len += 1;
                }
                break;
        }
    }

    char *result = malloc(len + 1);
    if (!result) {
        return NULL;
    }

    char *w = result;
    for (const unsigned char *p = (const unsigned char *)value; *p; ++p) {
        switch (*p) {
            case '\"':
                *w++ = '\\';
                *w++ = '\"';
                break;
            case '\\':
                *w++ = '\\';
                *w++ = '\\';
                break;
            case '\b':
                *w++ = '\\';
                *w++ = 'b';
                break;
            case '\f':
                *w++ = '\\';
                *w++ = 'f';
                break;
            case '\n':
                *w++ = '\\';
                *w++ = 'n';
                break;
            case '\r':
                *w++ = '\\';
                *w++ = 'r';
                break;
            case '\t':
                *w++ = '\\';
                *w++ = 't';
                break;
            default:
                if (*p < 0x20) {
                    sprintf(w, "\\u%04x", *p);
                    w += 6;
                } else {
                    *w++ = (char)*p;
                }
                break;
        }
    }
    *w = '\0';
    return result;
}

static void print_quoted_json_string(FILE *output, const char *value) {
    char *escaped = escape_json_string(value);
    if (!escaped) {
        fprintf(output, "\"\"");
        return;
    }
    fprintf(output, "\"%s\"", escaped);
    free(escaped);
}

// Funzione base per creare un nodo AST
ASTNode* create_ast_node(ASTNodeType type) {
    ASTNode *node = malloc(sizeof(ASTNode));
    if (!node) {
        fprintf(stderr, "Errore: impossibile allocare memoria per nodo AST\n");
        exit(1);
    }
    
    node->type = type;
    node->children = NULL;
    node->children_count = 0;
    node->children_capacity = 0;
    node->next = NULL;
    
    // Inizializza tutti i campi dell'union a zero
    memset(&node->data, 0, sizeof(node->data));
    
    return node;
}

// Funzioni per la creazione di nodi specifici
ASTNode* create_program_node() {
    return create_ast_node(AST_PROGRAM);
}

ASTNode* create_statement_list_node() {
    return create_ast_node(AST_STATEMENT_LIST);
}

ASTNode* create_var_decl_node(char *name, int data_type, ASTNode *init_value) {
    ASTNode *node = create_ast_node(AST_VARIABLE_DECLARATION);
    node->data.var_decl.name = xstrdup(name);
    node->data.var_decl.data_type = data_type;
    node->data.var_decl.init_value = init_value;
    return node;
}

ASTNode* create_assignment_node(char *name, ASTNode *value) {
    ASTNode *node = create_ast_node(AST_ASSIGNMENT);
    node->data.assignment.name = xstrdup(name);
    node->data.assignment.value = value;
    return node;
}

ASTNode* create_func_decl_node(char *name, int return_type, ASTNode *params, ASTNode *body) {
    ASTNode *node = create_ast_node(AST_FUNCTION_DECLARATION);
    node->data.func_decl.name = xstrdup(name);
    node->data.func_decl.return_type = return_type;
    node->data.func_decl.params = params;
    node->data.func_decl.body = body;
    return node;
}

ASTNode* create_func_call_node(char *name, ASTNode *args) {
    ASTNode *node = create_ast_node(AST_FUNCTION_CALL);
    node->data.func_call.name = xstrdup(name);
    node->data.func_call.args = args;
    return node;
}

ASTNode* create_if_node(ASTNode *condition, ASTNode *then_stmt, ASTNode *else_stmt) {
    ASTNode *node = create_ast_node(AST_IF_STATEMENT);
    node->data.if_stmt.condition = condition;
    node->data.if_stmt.then_stmt = then_stmt;
    node->data.if_stmt.else_stmt = else_stmt;
    return node;
}

ASTNode* create_while_node(ASTNode *condition, ASTNode *body) {
    ASTNode *node = create_ast_node(AST_WHILE_STATEMENT);
    node->data.while_stmt.condition = condition;
    node->data.while_stmt.body = body;
    return node;
}

ASTNode* create_return_node(ASTNode *value) {
    ASTNode *node = create_ast_node(AST_RETURN_STATEMENT);
    node->data.return_stmt.value = value;
    return node;
}

ASTNode* create_printf_node(char *format_string, ASTNode *args) {
    ASTNode *node = create_ast_node(AST_PRINTF_STATEMENT);
    node->data.printf_stmt.format_string = xstrdup(format_string);
    node->data.printf_stmt.args = args;
    return node;
}

ASTNode* create_scanf_node(char *format_string, ASTNode *args) {
    ASTNode *node = create_ast_node(AST_SCANF_STATEMENT);
    node->data.scanf_stmt.format_string = xstrdup(format_string);
    node->data.scanf_stmt.args = args;
    return node;
}

ASTNode* create_binary_op_node(OperatorType op, ASTNode *left, ASTNode *right) {
    ASTNode *node = create_ast_node(AST_BINARY_OP);
    node->data.binary_op.op = op;
    node->data.binary_op.left = left;
    node->data.binary_op.right = right;
    return node;
}

ASTNode* create_literal_int_node(int value) {
    ASTNode *node = create_ast_node(AST_LITERAL);
    node->data.literal.lit_type = LITERAL_INT;
    node->data.literal.value.int_val = value;
    return node;
}

ASTNode* create_literal_float_node(double value) {
    ASTNode *node = create_ast_node(AST_LITERAL);
    node->data.literal.lit_type = LITERAL_FLOAT;
    node->data.literal.value.float_val = value;
    return node;
}

ASTNode* create_literal_char_node(char value) {
    ASTNode *node = create_ast_node(AST_LITERAL);
    node->data.literal.lit_type = LITERAL_CHAR;
    node->data.literal.value.char_val = value;
    return node;
}

ASTNode* create_literal_string_node(char *value) {
    ASTNode *node = create_ast_node(AST_LITERAL);
    node->data.literal.lit_type = LITERAL_STRING;
    node->data.literal.value.string_val = xstrdup(value);
    return node;
}

ASTNode* create_identifier_node(char *name) {
    ASTNode *node = create_ast_node(AST_IDENTIFIER);
    node->data.identifier.name = xstrdup(name);
    return node;
}

ASTNode* create_condition_node(OperatorType op, ASTNode *left, ASTNode *right) {
    ASTNode *node = create_ast_node(AST_CONDITION);
    node->data.condition.op = op;
    node->data.condition.left = left;
    node->data.condition.right = right;
    return node;
}

ASTNode* create_block_node() {
    return create_ast_node(AST_BLOCK);
}

// Funzioni per la gestione dei figli
void add_child(ASTNode *parent, ASTNode *child) {
    if (!parent || !child) return;
    
    if (parent->children_count >= parent->children_capacity) {
        parent->children_capacity = parent->children_capacity == 0 ? 4 : parent->children_capacity * 2;
        parent->children = realloc(parent->children, parent->children_capacity * sizeof(ASTNode*));
        if (!parent->children) {
            fprintf(stderr, "Errore: impossibile riallocare memoria per figli\n");
            exit(1);
        }
    }
    
    parent->children[parent->children_count++] = child;
}

void add_sibling(ASTNode *node, ASTNode *sibling) {
    if (!node || !sibling) return;
    
    ASTNode *current = node;
    while (current->next != NULL) {
        current = current->next;
    }
    current->next = sibling;
}

// Funzioni di utilità per le stringhe
const char* node_type_to_string(ASTNodeType type) {
    switch (type) {
        case AST_PROGRAM: return "program";
        case AST_STATEMENT_LIST: return "statement_sequence";
        case AST_VARIABLE_DECLARATION: return "variable_declaration";
        case AST_ASSIGNMENT: return "assign";
        case AST_FUNCTION_DECLARATION: return "function_declaration";
        case AST_FUNCTION_CALL: return "function_call";
        case AST_IF_STATEMENT: return "if";
        case AST_WHILE_STATEMENT: return "while";
        case AST_RETURN_STATEMENT: return "return";
        case AST_PRINTF_STATEMENT: return "printf";
        case AST_SCANF_STATEMENT: return "scanf";
        case AST_BINARY_OP: return "binary_operation";
        case AST_LITERAL: return "literal";
        case AST_IDENTIFIER: return "identifier";
        case AST_PARAMETER_LIST: return "parameter_list";
        case AST_ARGUMENT_LIST: return "argument_list";
        case AST_CONDITION: return "compare";
        case AST_BLOCK: return "block";
        default: return "unknown";
    }
}

const char* operator_to_string(OperatorType op) {
    switch (op) {
        case OP_ADD: return "+";
        case OP_SUB: return "-";
        case OP_MUL: return "*";
        case OP_DIV: return "/";
        case OP_GT: return ">";
        case OP_LT: return "<";
        case OP_GTE: return ">=";
        case OP_LTE: return "<=";
        case OP_EQ: return "==";
        case OP_NEQ: return "!=";
        default: return "unknown";
    }
}

const char* literal_type_to_string(LiteralType type) {
    switch (type) {
        case LITERAL_INT: return "integer";
        case LITERAL_FLOAT: return "float";
        case LITERAL_CHAR: return "character";
        case LITERAL_STRING: return "string";
        default: return "unknown";
    }
}

const char* data_type_to_string(int data_type) {
    switch (data_type) {
        case 0: return "int";     // Costante TYPE_INT
        case 1: return "float";   // Costante TYPE_FLOAT
        case 2: return "char";    // Costante TYPE_CHAR
        case 3: return "void";    // Costante TYPE_VOID
        default: return "unknown";
    }
}

// Funzioni per la generazione JSON
static void print_json_node(ASTNode *node, FILE *output, int indent) {
    if (!node) return;
    
    // Indentazione
    for (int i = 0; i < indent; i++) {
        fprintf(output, "  ");
    }
    
    fprintf(output, "{\n");
    
    // Tipo del nodo
    for (int i = 0; i <= indent; i++) fprintf(output, "  ");
    fprintf(output, "\"node_type\": \"%s\"", node_type_to_string(node->type));
    
    // Dati specifici del nodo
    switch (node->type) {
        case AST_VARIABLE_DECLARATION:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"variable_name\": ");
            print_quoted_json_string(output, node->data.var_decl.name);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"data_type\": \"%s\"", data_type_to_string(node->data.var_decl.data_type));
            if (node->data.var_decl.init_value) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"initial_value\": ");
                print_json_node(node->data.var_decl.init_value, output, indent + 1);
            }
            break;
            
        case AST_ASSIGNMENT:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"target\": ");
            print_quoted_json_string(output, node->data.assignment.name);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"value\": ");
            print_json_node(node->data.assignment.value, output, indent + 1);
            break;
            
        case AST_FUNCTION_DECLARATION:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"function_name\": ");
            print_quoted_json_string(output, node->data.func_decl.name);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"return_type\": \"%s\"", data_type_to_string(node->data.func_decl.return_type));
            if (node->data.func_decl.params) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"parameters\": ");
                print_json_node(node->data.func_decl.params, output, indent + 1);
            }
            if (node->data.func_decl.body) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"body\": ");
                print_json_node(node->data.func_decl.body, output, indent + 1);
            }
            break;
            
        case AST_FUNCTION_CALL:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"function_name\": ");
            print_quoted_json_string(output, node->data.func_call.name);
            if (node->data.func_call.args) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"arguments\": ");
                print_json_node(node->data.func_call.args, output, indent + 1);
            }
            break;
            
        case AST_IF_STATEMENT:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"condition\": ");
            print_json_node(node->data.if_stmt.condition, output, indent + 1);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"then_branch\": ");
            print_json_node(node->data.if_stmt.then_stmt, output, indent + 1);
            if (node->data.if_stmt.else_stmt) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"else_branch\": ");
                print_json_node(node->data.if_stmt.else_stmt, output, indent + 1);
            }
            break;
            
        case AST_WHILE_STATEMENT:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"condition\": ");
            print_json_node(node->data.while_stmt.condition, output, indent + 1);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"body\": ");
            print_json_node(node->data.while_stmt.body, output, indent + 1);
            break;
            
        case AST_RETURN_STATEMENT:
            if (node->data.return_stmt.value) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"return_value\": ");
                print_json_node(node->data.return_stmt.value, output, indent + 1);
            }
            break;
            
        case AST_PRINTF_STATEMENT:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"format\": ");
            print_quoted_json_string(output, node->data.printf_stmt.format_string);
            if (node->data.printf_stmt.args) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"printf_arguments\": ");
                print_json_node(node->data.printf_stmt.args, output, indent + 1);
            }
            break;
            
        case AST_SCANF_STATEMENT:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"format\": ");
            print_quoted_json_string(output, node->data.scanf_stmt.format_string);
            if (node->data.scanf_stmt.args) {
                fprintf(output, ",\n");
                for (int i = 0; i <= indent; i++) fprintf(output, "  ");
                fprintf(output, "\"scanf_arguments\": ");
                print_json_node(node->data.scanf_stmt.args, output, indent + 1);
            }
            break;
            
        case AST_BINARY_OP:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"operator\": \"%s\",\n", operator_to_string(node->data.binary_op.op));
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"left_operand\": ");
            print_json_node(node->data.binary_op.left, output, indent + 1);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"right_operand\": ");
            print_json_node(node->data.binary_op.right, output, indent + 1);
            break;
            
        case AST_LITERAL:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"literal_type\": \"%s\",\n", literal_type_to_string(node->data.literal.lit_type));
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"value\": ");
            switch (node->data.literal.lit_type) {
                case LITERAL_INT:
                    fprintf(output, "%d", node->data.literal.value.int_val);
                    break;
                case LITERAL_FLOAT:
                    fprintf(output, "%.6f", node->data.literal.value.float_val);
                    break;
                case LITERAL_CHAR: {
                    char buffer[2];
                    buffer[0] = (char)node->data.literal.value.char_val;
                    buffer[1] = '\0';
                    print_quoted_json_string(output, buffer);
                    break;
                }
                case LITERAL_STRING:
                    print_quoted_json_string(output, node->data.literal.value.string_val);
                    break;
            }
            break;
            
        case AST_IDENTIFIER:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"identifier_name\": ");
            print_quoted_json_string(output, node->data.identifier.name);
            break;
            
        case AST_CONDITION:
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"comparison_operator\": \"%s\",\n", operator_to_string(node->data.condition.op));
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"left_operand\": ");
            print_json_node(node->data.condition.left, output, indent + 1);
            fprintf(output, ",\n");
            for (int i = 0; i <= indent; i++) fprintf(output, "  ");
            fprintf(output, "\"right_operand\": ");
            print_json_node(node->data.condition.right, output, indent + 1);
            break;
            
        default:
            break;
    }
    
    // Figli del nodo
    if (node->children_count > 0) {
        fprintf(output, ",\n");
        for (int i = 0; i <= indent; i++) fprintf(output, "  ");
        fprintf(output, "\"children\": [\n");
        
        for (int i = 0; i < node->children_count; i++) {
            print_json_node(node->children[i], output, indent + 1);
            if (i < node->children_count - 1) {
                fprintf(output, ",");
            }
            fprintf(output, "\n");
        }
        
        for (int i = 0; i <= indent; i++) fprintf(output, "  ");
        fprintf(output, "]");
    }
    
    // Nodi fratelli (per liste)
    if (node->next) {
        fprintf(output, ",\n");
        for (int i = 0; i <= indent; i++) fprintf(output, "  ");
        fprintf(output, "\"next_statement\": ");
        print_json_node(node->next, output, indent);
    }
    
    fprintf(output, "\n");
    for (int i = 0; i < indent; i++) {
        fprintf(output, "  ");
    }
    fprintf(output, "}");
}

void ast_to_json(ASTNode *root, FILE *output) {
    if (!root || !output) return;
    fprintf(output, "{\n  \"ast\": ");
    print_json_node(root, output, 1);
    fprintf(output, "\n}\n");
}

void ast_to_json_file(ASTNode *root, const char *filename) {
    if (!root || !filename) return;
    
    FILE *file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "Errore: impossibile aprire file %s per scrittura\n", filename);
        return;
    }
    
    ast_to_json(root, file);
    fclose(file);
}

char* ast_to_json_string(ASTNode *root) {
    if (!root) return NULL;
    
    // Usa un buffer temporaneo per calcolare la dimensione necessaria
    FILE *temp = tmpfile();
    if (!temp) return NULL;
    
    ast_to_json(root, temp);
    
    // Ottieni la dimensione del file
    fseek(temp, 0, SEEK_END);
    long size = ftell(temp);
    fseek(temp, 0, SEEK_SET);
    
    // Alloca memoria e leggi il contenuto
    char *json_string = malloc(size + 1);
    if (json_string) {
        fread(json_string, 1, size, temp);
        json_string[size] = '\0';
    }
    
    fclose(temp);
    return json_string;
}

// Funzione per liberare la memoria dell'AST
void free_ast(ASTNode *node) {
    if (!node) return;
    
    // Libera i figli
    for (int i = 0; i < node->children_count; i++) {
        free_ast(node->children[i]);
    }
    free(node->children);
    
    // Libera il nodo fratello
    free_ast(node->next);
    
    // Libera i dati specifici del nodo
    switch (node->type) {
        case AST_VARIABLE_DECLARATION:
            free(node->data.var_decl.name);
            free_ast(node->data.var_decl.init_value);
            break;
            
        case AST_ASSIGNMENT:
            free(node->data.assignment.name);
            free_ast(node->data.assignment.value);
            break;
            
        case AST_FUNCTION_DECLARATION:
            free(node->data.func_decl.name);
            free_ast(node->data.func_decl.params);
            free_ast(node->data.func_decl.body);
            break;
            
        case AST_FUNCTION_CALL:
            free(node->data.func_call.name);
            free_ast(node->data.func_call.args);
            break;
            
        case AST_IF_STATEMENT:
            free_ast(node->data.if_stmt.condition);
            free_ast(node->data.if_stmt.then_stmt);
            free_ast(node->data.if_stmt.else_stmt);
            break;
            
        case AST_WHILE_STATEMENT:
            free_ast(node->data.while_stmt.condition);
            free_ast(node->data.while_stmt.body);
            break;
            
        case AST_RETURN_STATEMENT:
            free_ast(node->data.return_stmt.value);
            break;
            
        case AST_PRINTF_STATEMENT:
            free(node->data.printf_stmt.format_string);
            free_ast(node->data.printf_stmt.args);
            break;
            
        case AST_SCANF_STATEMENT:
            free(node->data.scanf_stmt.format_string);
            free_ast(node->data.scanf_stmt.args);
            break;
            
        case AST_BINARY_OP:
            free_ast(node->data.binary_op.left);
            free_ast(node->data.binary_op.right);
            break;
            
        case AST_LITERAL:
            if (node->data.literal.lit_type == LITERAL_STRING) {
                free(node->data.literal.value.string_val);
            }
            break;
            
        case AST_IDENTIFIER:
            free(node->data.identifier.name);
            break;
            
        case AST_CONDITION:
            free_ast(node->data.condition.left);
            free_ast(node->data.condition.right);
            break;
            
        default:
            break;
    }
    
    free(node);
}
