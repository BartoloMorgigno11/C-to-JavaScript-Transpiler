/* ast.h */
#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *xstrdup(const char *src);

// Enumerazione per i tipi di nodi AST
typedef enum {
    AST_PROGRAM,
    AST_STATEMENT_LIST,
    AST_VARIABLE_DECLARATION,
    AST_ASSIGNMENT,
    AST_FUNCTION_DECLARATION,
    AST_FUNCTION_CALL,
    AST_IF_STATEMENT,
    AST_WHILE_STATEMENT,
    AST_RETURN_STATEMENT,
    AST_PRINTF_STATEMENT,
    AST_SCANF_STATEMENT,
    AST_BINARY_OP,
    AST_LITERAL,
    AST_IDENTIFIER,
    AST_PARAMETER_LIST,
    AST_ARGUMENT_LIST,
    AST_CONDITION,
    AST_BLOCK
} ASTNodeType;

// Enumerazione per i tipi di operatori binari
typedef enum {
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,
    OP_GT,
    OP_LT,
    OP_GTE,
    OP_LTE,
    OP_EQ,
    OP_NEQ
} OperatorType;

// Enumerazione per i tipi di letterali
typedef enum {
    LITERAL_INT,
    LITERAL_FLOAT,
    LITERAL_CHAR,
    LITERAL_STRING
} LiteralType;

// Struttura per i valori dei letterali
typedef union {
    int int_val;
    double float_val;
    char char_val;
    char *string_val;
} LiteralValue;

// Struttura principale del nodo AST
typedef struct ASTNode {
    ASTNodeType type;
    
    // Dati specifici del nodo
    union {
        struct {
            char *name;
            int data_type;  // DataType dal parser
            struct ASTNode *init_value;
        } var_decl;
        
        struct {
            char *name;
            struct ASTNode *value;
        } assignment;
        
        struct {
            char *name;
            int return_type;  // DataType dal parser
            struct ASTNode *params;
            struct ASTNode *body;
        } func_decl;
        
        struct {
            char *name;
            struct ASTNode *args;
        } func_call;
        
        struct {
            struct ASTNode *condition;
            struct ASTNode *then_stmt;
            struct ASTNode *else_stmt;  // NULL se non c'è else
        } if_stmt;
        
        struct {
            struct ASTNode *condition;
            struct ASTNode *body;
        } while_stmt;
        
        struct {
            struct ASTNode *value;
        } return_stmt;
        
        struct {
            char *format_string;
            struct ASTNode *args;
        } printf_stmt;
        
        struct {
            char *format_string;
            struct ASTNode *args;
        } scanf_stmt;
        
        struct {
            OperatorType op;
            struct ASTNode *left;
            struct ASTNode *right;
        } binary_op;
        
        struct {
            LiteralType lit_type;
            LiteralValue value;
        } literal;
        
        struct {
            char *name;
        } identifier;
        
        struct {
            OperatorType op;
            struct ASTNode *left;
            struct ASTNode *right;
        } condition;
    } data;
    
    // Lista di figli (per nodi che hanno più figli)
    struct ASTNode **children;
    int children_count;
    int children_capacity;
    
    // Prossimo nodo (per liste)
    struct ASTNode *next;
} ASTNode;

// Funzioni per la creazione dei nodi AST
ASTNode* create_ast_node(ASTNodeType type);
ASTNode* create_program_node();
ASTNode* create_statement_list_node();
ASTNode* create_var_decl_node(char *name, int data_type, ASTNode *init_value);
ASTNode* create_assignment_node(char *name, ASTNode *value);
ASTNode* create_func_decl_node(char *name, int return_type, ASTNode *params, ASTNode *body);
ASTNode* create_func_call_node(char *name, ASTNode *args);
ASTNode* create_if_node(ASTNode *condition, ASTNode *then_stmt, ASTNode *else_stmt);
ASTNode* create_while_node(ASTNode *condition, ASTNode *body);
ASTNode* create_return_node(ASTNode *value);
ASTNode* create_printf_node(char *format_string, ASTNode *args);
ASTNode* create_scanf_node(char *format_string, ASTNode *args);
ASTNode* create_binary_op_node(OperatorType op, ASTNode *left, ASTNode *right);
ASTNode* create_literal_int_node(int value);
ASTNode* create_literal_float_node(double value);
ASTNode* create_literal_char_node(char value);
ASTNode* create_literal_string_node(char *value);
ASTNode* create_identifier_node(char *name);
ASTNode* create_condition_node(OperatorType op, ASTNode *left, ASTNode *right);
ASTNode* create_block_node();

// Funzioni per la gestione dei figli
void add_child(ASTNode *parent, ASTNode *child);
void add_sibling(ASTNode *node, ASTNode *sibling);

// Funzioni per la generazione JSON
void ast_to_json(ASTNode *root, FILE *output);
void ast_to_json_file(ASTNode *root, const char *filename);
char* ast_to_json_string(ASTNode *root);

// Funzioni di utilità
void free_ast(ASTNode *node);
const char* node_type_to_string(ASTNodeType type);
const char* operator_to_string(OperatorType op);
const char* literal_type_to_string(LiteralType type);
const char* data_type_to_string(int data_type);

// Variabile globale per il root dell'AST
extern ASTNode *ast_root;

#endif /* AST_H */
