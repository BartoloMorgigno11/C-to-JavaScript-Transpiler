%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "symbol_table.h"
#include "type_checking.h"

extern int yylex();
extern void yyerror(const char *s);

DataType current_expression_type = TYPE_UNKNOWN;

%}

%union {
    char *sval;
    int ival;
    double fval;
    int type_val;
    ASTNode *ast_node;
    OperatorType op_val;
}

%token <sval> ID STRINGA_NORMALE STRINGA_PLACEHOLDER INDIRIZZO
%token <ival> INTERO
%token <fval> FLOATING
%token <ival> CARATTERE
%token SEMICOLON ASSEGNAZIONE
%token GRAFFA_APERTA GRAFFA_CHIUSA TONDA_APERTA TONDA_CHIUSA
%token WHILE IF ELSE INT FLOAT CHAR VOID RETURN
%token SOMMA DIFFERENZA MOLTIPLICAZIONE DIVISIONE
%token MAGGIORE MINORE MAGGIORE_UGUALE MINORE_UGUALE UGUALE DIVERSO COMA
%token PRINT SCANF LEXICAL_ERROR

%type <ast_node> program statement_list statement espressione costruttii
%type <ast_node> assegnazione definizione output input chiamata_funzione
%type <ast_node> while_stmt if_stmt funzione_return funzione_no_return
%type <ast_node> letterale somma differenza moltiplicazione divisione
%type <ast_node> condizione condizione_logica corpo corpo_funzione_return
%type <ast_node> corpo_funzione parametri argomenti return_stmt
%type <ast_node> argomento parametro lista_indirizzi
%type <type_val> tipologia_variabile
%type <op_val> espressione_logica

%start program

%%

program: statement_list 
        {
            $$ = create_program_node();
            add_child($$, $1);
            ast_root = $$;
        }
        ;

statement_list: statement
              {
                $$ = create_statement_list_node();
                add_child($$, $1);
              }
              | statement_list statement
              {
                add_child($1, $2);
                $$ = $1;
              }
              ;

statement: espressione SEMICOLON
         {
            $$ = $1;
         }
         | costruttii
         {
            $$ = $1;
         }
         | /* epsilon */
         {
            $$ = NULL;
         }
         ;

espressione: assegnazione
           {
                $$ = $1;
           }
           | definizione
           {
                $$ = $1;
           }
           | output
           {
                $$ = $1;
           }
           | input
           {
                $$ = $1;
           }
           | chiamata_funzione
           {
                $$ = $1;
           }
           ;

costruttii: while_stmt
          {
            $$ = $1;
          }
          | if_stmt
          {
            $$ = $1;
          }
          | funzione_return
          {
            $$ = $1;
          }
          | funzione_no_return
          {
            $$ = $1;
          }
          ;

assegnazione: ID ASSEGNAZIONE letterale
            {
                if (!symbol_defined($1)) {
                    yyerror("Variabile non definita");
                    free($1);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType literal_type;
                if ($3->type == AST_LITERAL) {
                    literal_type = ($3->data.literal.lit_type == LITERAL_INT) ? TYPE_INT :
                                  ($3->data.literal.lit_type == LITERAL_FLOAT) ? TYPE_FLOAT :
                                  ($3->data.literal.lit_type == LITERAL_CHAR) ? TYPE_CHAR : TYPE_UNKNOWN;
                } else {
                    literal_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, literal_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità di tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(literal_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                $$ = create_assignment_node($1, $3);
                free($1);
            }
            | ID ASSEGNAZIONE ID
            {
                if (!symbol_defined($1) || !symbol_defined($3)) {
                    yyerror("Variabile non definita");
                    free($1);
                    free($3);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType value_type = get_symbol_type($3);
                if (!types_compatible(var_type, value_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità di tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(value_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free($3);
                    YYERROR;
                }
                ASTNode *id_node = create_identifier_node($3);
                $$ = create_assignment_node($1, id_node);
                free($1);
                free($3);
            }
            | ID ASSEGNAZIONE somma
            {
                if (!symbol_defined($1)) {
                    yyerror("Variabile non definita");
                    free($1);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType expr_type;
                if ($3->type == AST_BINARY_OP) {
                    if ($3->data.binary_op.op == OP_ADD || $3->data.binary_op.op == OP_SUB ||
                        $3->data.binary_op.op == OP_MUL || $3->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $3->data.binary_op.left;
                        ASTNode *right = $3->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità di tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                $$ = create_assignment_node($1, $3);
                free($1);
            }
            | ID ASSEGNAZIONE differenza
            {
                if (!symbol_defined($1)) {
                    yyerror("Variabile non definita");
                    free($1);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType expr_type;
                if ($3->type == AST_BINARY_OP) {
                    if ($3->data.binary_op.op == OP_ADD || $3->data.binary_op.op == OP_SUB ||
                        $3->data.binary_op.op == OP_MUL || $3->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $3->data.binary_op.left;
                        ASTNode *right = $3->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                $$ = create_assignment_node($1, $3);
                free($1);
            }
            | ID ASSEGNAZIONE moltiplicazione
            {
                if (!symbol_defined($1)) {
                    yyerror("Variabile non definita");
                    free($1);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType expr_type;
                if ($3->type == AST_BINARY_OP) {
                    if ($3->data.binary_op.op == OP_ADD || $3->data.binary_op.op == OP_SUB ||
                        $3->data.binary_op.op == OP_MUL || $3->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $3->data.binary_op.left;
                        ASTNode *right = $3->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                $$ = create_assignment_node($1, $3);
                free($1);
            }
            | ID ASSEGNAZIONE divisione
            {
                if (!symbol_defined($1)) {
                    yyerror("Variabile non definita");
                    free($1);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType expr_type;
                if ($3->type == AST_BINARY_OP) {
                    if ($3->data.binary_op.op == OP_ADD || $3->data.binary_op.op == OP_SUB ||
                        $3->data.binary_op.op == OP_MUL || $3->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $3->data.binary_op.left;
                        ASTNode *right = $3->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                $$ = create_assignment_node($1, $3);
                free($1);
            }
            | ID ASSEGNAZIONE chiamata_funzione
            {
                if (!symbol_defined($1)) {
                    yyerror("Variabile non definita");
                    free($1);
                    YYERROR;
                }
                DataType var_type = get_symbol_type($1);
                DataType func_type;
                
                if ($3->type == AST_FUNCTION_CALL) {
                    char *func_name = $3->data.func_call.name;
                    if (symbol_defined(func_name)) {
                        func_type = get_symbol_type(func_name);
                    } else {
                        func_type = TYPE_UNKNOWN;
                    }
                } else {
                    func_type = TYPE_UNKNOWN;
                }
                
                if (func_type == TYPE_VOID) {
                    yyerror("Impossibile assegnare il risultato de una funzione void a una variabile");
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                
                if (!types_compatible(var_type, func_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo: tentativo di assegnare %s a variabile %s", 
                        type_to_string(func_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($1);
                    free_ast($3);
                    YYERROR;
                }
                $$ = create_assignment_node($1, $3);
                free($1);
            }
            ;

letterale: INTERO
         {
            $$ = create_literal_int_node($1);
         }
         | FLOATING
         {
            $$ = create_literal_float_node($1);
         }
         | CARATTERE
         {
            $$ = create_literal_char_node((char)$1);
         }
         ;

definizione: tipologia_variabile ID ASSEGNAZIONE letterale
            {
                DataType var_type = $1;
                DataType literal_type;
                if ($4->type == AST_LITERAL) {
                    literal_type = ($4->data.literal.lit_type == LITERAL_INT) ? TYPE_INT :
                                  ($4->data.literal.lit_type == LITERAL_FLOAT) ? TYPE_FLOAT :
                                  ($4->data.literal.lit_type == LITERAL_CHAR) ? TYPE_CHAR : TYPE_UNKNOWN;
                } else {
                    literal_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, literal_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s a variabile %s", 
                        type_to_string(literal_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                $$ = create_var_decl_node($2, var_type, $4);
                free($2);
            }
           | tipologia_variabile ID ASSEGNAZIONE ID
            {
                DataType var_type = $1;
                if (!symbol_defined($4)) {
                    yyerror("Variabile non definita");
                    free($2);
                    free($4);
                    YYERROR;
                }
                DataType value_type = get_symbol_type($4);
                if (!types_compatible(var_type, value_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s to variabile %s", 
                        type_to_string(value_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                ASTNode *id_node = create_identifier_node($4);
                $$ = create_var_decl_node($2, var_type, id_node);
                free($2);
                free($4);
            }
           | tipologia_variabile ID ASSEGNAZIONE somma
            {
                DataType var_type = $1;
                DataType expr_type;
                if ($4->type == AST_BINARY_OP) {
                    if ($4->data.binary_op.op == OP_ADD || $4->data.binary_op.op == OP_SUB ||
                        $4->data.binary_op.op == OP_MUL || $4->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $4->data.binary_op.left;
                        ASTNode *right = $4->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                $$ = create_var_decl_node($2, var_type, $4);
                free($2);
            }
           | tipologia_variabile ID ASSEGNAZIONE differenza
            {
                DataType var_type = $1;
                DataType expr_type;
                if ($4->type == AST_BINARY_OP) {
                    if ($4->data.binary_op.op == OP_ADD || $4->data.binary_op.op == OP_SUB ||
                        $4->data.binary_op.op == OP_MUL || $4->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $4->data.binary_op.left;
                        ASTNode *right = $4->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                $$ = create_var_decl_node($2, var_type, $4);
                free($2);
            }
           | tipologia_variabile ID ASSEGNAZIONE moltiplicazione
            {
                DataType var_type = $1;
                DataType expr_type;
                if ($4->type == AST_BINARY_OP) {
                    if ($4->data.binary_op.op == OP_ADD || $4->data.binary_op.op == OP_SUB ||
                        $4->data.binary_op.op == OP_MUL || $4->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $4->data.binary_op.left;
                        ASTNode *right = $4->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                $$ = create_var_decl_node($2, var_type, $4);
                free($2);
            }
           | tipologia_variabile ID ASSEGNAZIONE divisione
            {
                DataType var_type = $1;
                DataType expr_type;
                if ($4->type == AST_BINARY_OP) {
                    if ($4->data.binary_op.op == OP_ADD || $4->data.binary_op.op == OP_SUB ||
                        $4->data.binary_op.op == OP_MUL || $4->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $4->data.binary_op.left;
                        ASTNode *right = $4->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(var_type, expr_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s a variabile %s", 
                        type_to_string(expr_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                $$ = create_var_decl_node($2, var_type, $4);
                free($2);
            }
           | tipologia_variabile ID ASSEGNAZIONE chiamata_funzione
            {
                DataType var_type = $1;
                DataType func_type;
                
                if ($4->type == AST_FUNCTION_CALL) {
                    char *func_name = $4->data.func_call.name;
                    if (symbol_defined(func_name)) {
                        func_type = get_symbol_type(func_name);
                    } else {
                        func_type = TYPE_UNKNOWN;
                    }
                } else {
                    func_type = TYPE_UNKNOWN;
                }
                
                if (func_type == TYPE_VOID) {
                    yyerror("Impossibile assegnare il risultato de una funzione void a a variabile");
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                
                if (!types_compatible(var_type, func_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nella definizione: tentativo de assegnare %s a variabile %s", 
                        type_to_string(func_type), type_to_string(var_type));
                    yyerror(error_msg);
                    free($2);
                    free_ast($4);
                    YYERROR;
                }
                add_symbol($2, var_type, 0);
                $$ = create_var_decl_node($2, var_type, $4);
                free($2);
            }
           | tipologia_variabile ID
            {
                add_symbol($2, $1, 0);
                $$ = create_var_decl_node($2, $1, NULL);
                free($2);
            }
           ;

tipologia_variabile: INT
                   {
                    $$ = TYPE_INT;
                   }
                   | FLOAT
                   {
                    $$ = TYPE_FLOAT;
                   }
                   | CHAR
                   {
                    $$ = TYPE_CHAR;
                   }
                   ;

chiamata_funzione: ID TONDA_APERTA 
        {
            free_param_list(current_call_params);
            current_call_params = NULL;
        }
        argomenti TONDA_CHIUSA
        {
            if (!symbol_defined($1)) {
                yyerror("Funzione non definita");
                free($1);
                YYERROR;
            }
            
            if (!is_function($1)) {
                yyerror("Simbolo non è una funzione");
                free($1);
                YYERROR;
            }
            
            Param *expected = get_function_params($1);
            Param *actual = current_call_params;
            
            int expected_count = count_params(expected);
            int actual_count = count_params(actual);
            
            if (expected_count != actual_count) {
                char error_msg[256];
                snprintf(error_msg, sizeof(error_msg), 
                    "Numero de parametri errato: attesi %d, forniti %d", 
                    expected_count, actual_count);
                yyerror(error_msg);
                free($1);
                free_param_list(actual);
                YYERROR;
            }
            
            if (!check_function_params(expected, actual)) {
                yyerror("Tipi dei parametri non corrispondono");
                free($1);
                free_param_list(actual);
                YYERROR;
            }
            
            free_param_list(actual);
            current_call_params = NULL;
            
            $$ = create_func_call_node($1, $4);
            free($1);
        }
        ;

argomenti: /* epsilon */
         { $$ = NULL; }
         | argomento
         {
            $$ = create_statement_list_node();
            add_child($$, $1);
         }
         | argomenti COMA argomento
         {
            add_child($1, $3);
            $$ = $1;
         }
         ;

argomento: ID
         {
            if (!symbol_defined($1)) {
                yyerror("Variabile non definita");
                free($1);
                YYERROR;
            }
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                var_types[var_count++] = get_symbol_type($1);
            }
            if (!in_printf_context && !in_scanf_context) {
                add_param_to_call(get_symbol_type($1));
            }
            $$ = create_identifier_node($1);
            free($1);
         }
         | letterale
         {
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                DataType literal_type;
                if ($1->type == AST_LITERAL) {
                    literal_type = ($1->data.literal.lit_type == LITERAL_INT) ? TYPE_INT :
                                  ($1->data.literal.lit_type == LITERAL_FLOAT) ? TYPE_FLOAT :
                                  ($1->data.literal.lit_type == LITERAL_CHAR) ? TYPE_CHAR : TYPE_UNKNOWN;
                } else {
                    literal_type = TYPE_UNKNOWN;
                }
                var_types[var_count++] = literal_type;
            }
            if (!in_printf_context && !in_scanf_context) {
                DataType literal_type;
                if ($1->type == AST_LITERAL) {
                    literal_type = ($1->data.literal.lit_type == LITERAL_INT) ? TYPE_INT :
                                  ($1->data.literal.lit_type == LITERAL_FLOAT) ? TYPE_FLOAT :
                                  ($1->data.literal.lit_type == LITERAL_CHAR) ? TYPE_CHAR : TYPE_UNKNOWN;
                } else {
                    literal_type = TYPE_UNKNOWN;
                }
                add_param_to_call(literal_type);
            }
            $$ = $1;
         }
         | somma
         {
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                var_types[var_count++] = expr_type;
            }
            if (!in_printf_context && !in_scanf_context) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                add_param_to_call(expr_type);
            }
            $$ = $1;
         }
         | differenza
         {
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                var_types[var_count++] = expr_type;
            }
            if (!in_printf_context && !in_scanf_context) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                add_param_to_call(expr_type);
            }
            $$ = $1;
         }
         | moltiplicazione
         {
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                var_types[var_count++] = expr_type;
            }
            if (!in_printf_context && !in_scanf_context) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                add_param_to_call(expr_type);
            }
            $$ = $1;
         }
         | divisione
         {
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                var_types[var_count++] = expr_type;
            }
            if (!in_printf_context && !in_scanf_context) {
                DataType expr_type;
                if ($1->type == AST_BINARY_OP) {
                    if ($1->data.binary_op.op == OP_ADD || $1->data.binary_op.op == OP_SUB ||
                        $1->data.binary_op.op == OP_MUL || $1->data.binary_op.op == OP_DIV) {
                        ASTNode *left = $1->data.binary_op.left;
                        ASTNode *right = $1->data.binary_op.right;
                        if (left->type == AST_LITERAL && left->data.literal.lit_type == LITERAL_FLOAT ||
                            right->type == AST_LITERAL && right->data.literal.lit_type == LITERAL_FLOAT) {
                            expr_type = TYPE_FLOAT;
                        } else {
                            expr_type = TYPE_INT;
                        }
                    } else {
                        expr_type = TYPE_UNKNOWN;
                    }
                } else {
                    expr_type = TYPE_UNKNOWN;
                }
                add_param_to_call(expr_type);
            }
            $$ = $1;
         }
         | chiamata_funzione
         {
            if (in_printf_context && var_count < MAX_PLACEHOLDERS) {
                DataType func_type;
                if ($1->type == AST_FUNCTION_CALL) {
                    char *func_name = $1->data.func_call.name;
                    if (symbol_defined(func_name)) {
                        func_type = get_symbol_type(func_name);
                    } else {
                        func_type = TYPE_UNKNOWN;
                    }
                } else {
                    func_type = TYPE_UNKNOWN;
                }
                var_types[var_count++] = func_type;
            }
            if (!in_printf_context && !in_scanf_context) {
                DataType func_type;
                if ($1->type == AST_FUNCTION_CALL) {
                    char *func_name = $1->data.func_call.name;
                    if (symbol_defined(func_name)) {
                        func_type = get_symbol_type(func_name);
                    } else {
                        func_type = TYPE_UNKNOWN;
                    }
                } else {
                    func_type = TYPE_UNKNOWN;
                }
                add_param_to_call(func_type);
            }
            $$ = $1;
         }
         ;

while_stmt: WHILE condizione corpo
          {
            $$ = create_while_node($2, $3);
          }
          ;

if_stmt: IF condizione corpo
       {
            $$ = create_if_node($2, $3, NULL);
       }
       | IF condizione corpo ELSE corpo
       {
            $$ = create_if_node($2, $3, $5);
       }
       ;

condizione: TONDA_APERTA condizione_logica TONDA_CHIUSA
          {
            $$ = $2;
          }
          ;

condizione_logica: ID espressione_logica letterale
                 {
                    if (!symbol_defined($1)) {
                        yyerror("Variabile non definita");
                        free($1);
                        YYERROR;
                    }
                    DataType left_type = get_symbol_type($1);
                    DataType right_type;
                    if ($3->type == AST_LITERAL) {
                        right_type = ($3->data.literal.lit_type == LITERAL_INT) ? TYPE_INT :
                                    ($3->data.literal.lit_type == LITERAL_FLOAT) ? TYPE_FLOAT :
                                    ($3->data.literal.lit_type == LITERAL_CHAR) ? TYPE_CHAR : TYPE_UNKNOWN;
                    } else {
                        right_type = TYPE_UNKNOWN;
                    }
                    
                    if (!comparison_types_compatible(left_type, right_type)) {
                        char error_msg[256];
                        snprintf(error_msg, sizeof(error_msg), 
                            "Tipi non compatibili per il confronto: %s e %s",
                            type_to_string(left_type), type_to_string(right_type));
                        yyerror(error_msg);
                        free($1);
                        free_ast($3);
                        YYERROR;
                    }
                    ASTNode *left = create_identifier_node($1);
                    ASTNode *right = $3;
                    OperatorType op = $2;
                    $$ = create_condition_node(op, left, right);
                    free($1);
                 }
                 | ID espressione_logica ID
                 {
                    if (!symbol_defined($1) || !symbol_defined($3)) {
                        yyerror("Variabile non definita");
                        free($1);
                        free($3);
                        YYERROR;
                    }
                    DataType left_type = get_symbol_type($1);
                    DataType right_type = get_symbol_type($3);
                    
                    if (!comparison_types_compatible(left_type, right_type)) {
                        char error_msg[256];
                        snprintf(error_msg, sizeof(error_msg), 
                            "Tipi non compatibili per il confronto: %s e %s",
                            type_to_string(left_type), type_to_string(right_type));
                        yyerror(error_msg);
                        free($1);
                        free($3);
                        YYERROR;
                    }
                    ASTNode *left = create_identifier_node($1);
                    ASTNode *right = create_identifier_node($3);
                    OperatorType op = $2;
                    $$ = create_condition_node(op, left, right);
                    free($1);
                    free($3);
                 }
                 ;

espressione_logica: MAGGIORE
                  { $$ = OP_GT; }
                  | MINORE
                  { $$ = OP_LT; }
                  | UGUALE
                  { $$ = OP_EQ; }
                  | DIVERSO
                  { $$ = OP_NEQ; }
                  | MAGGIORE_UGUALE
                  { $$ = OP_GTE; }
                  | MINORE_UGUALE
                  { $$ = OP_LTE; }
                  ;

corpo: GRAFFA_APERTA statement_list GRAFFA_CHIUSA
     {
        $$ = create_block_node();
        add_child($$, $2);
     }
     | statement
     {
        $$ = create_block_node();
        add_child($$, $1);
     }
     ;

funzione_return: tipologia_variabile ID TONDA_APERTA { current_function_params = NULL; } parametri TONDA_CHIUSA 
        {
            current_var_type = $1;
            add_symbol($2, $1, 1);
            Symbol *func = symbol_table;
            while (func != NULL) {
                if (strcmp(func->name, $2) == 0 && func->is_function) {
                    func->params = current_function_params;
                    break;
                }
                func = func->next;
            }
            current_function_params = NULL;
        }
        corpo_funzione_return
        {
            $$ = create_func_decl_node($2, $1, $5, $8);
            free($2);
            current_function_params = NULL;
        }
        ;

corpo_funzione_return: GRAFFA_APERTA statement_list return_stmt GRAFFA_CHIUSA
              {
                $$ = create_block_node();
                add_child($$, $2);
                add_child($$, $3);
              }
              ;

return_stmt: RETURN ID SEMICOLON
           {
                if (!symbol_defined($2)) {
                    yyerror("Variabile non definita");
                    free($2);
                    YYERROR;
                }
                DataType return_type = get_symbol_type($2);
                if (!types_compatible(current_var_type, return_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nel return: tentativo di ritornare %s da funzione %s", 
                        type_to_string(return_type), type_to_string(current_var_type));
                    yyerror(error_msg);
                    free($2);
                    YYERROR;
                }
                ASTNode *value = create_identifier_node($2);
                $$ = create_return_node(value);
                free($2);
           }
           | RETURN letterale SEMICOLON
           {
                DataType literal_type;
                if ($2->type == AST_LITERAL) {
                    literal_type = ($2->data.literal.lit_type == LITERAL_INT) ? TYPE_INT :
                                  ($2->data.literal.lit_type == LITERAL_FLOAT) ? TYPE_FLOAT :
                                  ($2->data.literal.lit_type == LITERAL_CHAR) ? TYPE_CHAR : TYPE_UNKNOWN;
                } else {
                    literal_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(current_var_type, literal_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nel return: tentativo di ritornare %s da funzione %s", 
                        type_to_string(literal_type), type_to_string(current_var_type));
                    yyerror(error_msg);
                    free_ast($2);
                    YYERROR;
                }
                $$ = create_return_node($2);
           }
           | RETURN chiamata_funzione SEMICOLON
           {
                DataType func_type;
                if ($2->type == AST_FUNCTION_CALL) {
                    char *func_name = $2->data.func_call.name;
                    if (symbol_defined(func_name)) {
                        func_type = get_symbol_type(func_name);
                    } else {
                        func_type = TYPE_UNKNOWN;
                    }
                } else {
                    func_type = TYPE_UNKNOWN;
                }
                
                if (!types_compatible(current_var_type, func_type)) {
                    char error_msg[256];
                    snprintf(error_msg, sizeof(error_msg), 
                        "Incompatibilità de tipo nel return: tentativo di ritornare %s da funzione %s", 
                        type_to_string(func_type), type_to_string(current_var_type));
                    yyerror(error_msg);
                    free_ast($2);
                    YYERROR;
                }
                $$ = create_return_node($2);
           }
           ;
           
funzione_no_return: VOID ID TONDA_APERTA { current_function_params = NULL; } parametri TONDA_CHIUSA 
        {
            add_symbol($2, TYPE_VOID, 1);
            Symbol *func = symbol_table;
            while (func != NULL) {
                if (strcmp(func->name, $2) == 0 && func->is_function) {
                    func->params = current_function_params;
                    break;
                }
                func = func->next;
            }
            current_function_params = NULL;
        }
        corpo_funzione
        {
            $$ = create_func_decl_node($2, TYPE_VOID, $5, $8);
            free($2);
            current_function_params = NULL;
        }
        ;
	
corpo_funzione: GRAFFA_APERTA statement_list GRAFFA_CHIUSA
              {
                $$ = create_block_node();
                add_child($$, $2);
              }
              ;

parametri: /* epsilon */
         { $$ = NULL; }
         | parametro
         {
            $$ = create_statement_list_node();
            add_child($$, $1);
         }
         | parametri COMA parametro
         {
            add_child($1, $3);
            $$ = $1;
         }
         ;

parametro: tipologia_variabile ID
         {
            add_symbol($2, $1, 0);
            Param *new_param = malloc(sizeof(Param));
            new_param->type = $1;
            new_param->next = current_function_params;
            current_function_params = new_param;
            $$ = create_var_decl_node($2, $1, NULL);
            free($2);
         }
         ;

somma: ID SOMMA ID
     {
        if (!symbol_defined($1) || !symbol_defined($3)) {
            yyerror("Variabile non definita");
            free($1);
            free($3);
            YYERROR;
        }
        DataType type1 = get_symbol_type($1);
        DataType type2 = get_symbol_type($3);
        
        if (type1 == TYPE_FLOAT || type2 == TYPE_FLOAT) {
        } else if (type1 == TYPE_INT && type2 == TYPE_INT) {
        } else {
            yyerror("Operazione aritmetica non valida: tipi non compatibili");
            free($1);
            free($3);
            YYERROR;
        }
        ASTNode *left = create_identifier_node($1);
        ASTNode *right = create_identifier_node($3);
        $$ = create_binary_op_node(OP_ADD, left, right);
        free($1);
        free($3);
     }
     | INTERO SOMMA INTERO
     {
        ASTNode *left = create_literal_int_node($1);
        ASTNode *right = create_literal_int_node($3);
        $$ = create_binary_op_node(OP_ADD, left, right);
     }
     | FLOATING SOMMA FLOATING
     {
        ASTNode *left = create_literal_float_node($1);
        ASTNode *right = create_literal_float_node($3);
        $$ = create_binary_op_node(OP_ADD, left, right);
     }
     | FLOATING SOMMA INTERO
     {
        ASTNode *left = create_literal_float_node($1);
        ASTNode *right = create_literal_int_node($3);
        $$ = create_binary_op_node(OP_ADD, left, right);
     }
     | INTERO SOMMA FLOATING
     {
        ASTNode *left = create_literal_int_node($1);
        ASTNode *right = create_literal_float_node($3);
        $$ = create_binary_op_node(OP_ADD, left, right);
     }
     ;

differenza: ID DIFFERENZA ID
          {
            if (!symbol_defined($1) || !symbol_defined($3)) {
                yyerror("Variabile non definita");
                free($1);
                free($3);
                YYERROR;
            }
            DataType type1 = get_symbol_type($1);
            DataType type2 = get_symbol_type($3);
            
            if (type1 == TYPE_FLOAT || type2 == TYPE_FLOAT) {
            } else if (type1 == TYPE_INT && type2 == TYPE_INT) {
            } else {
                yyerror("Operazione aritmetica non valida: tipi non compatibili");
                free($1);
                free($3);
                YYERROR;
            }
            ASTNode *left = create_identifier_node($1);
            ASTNode *right = create_identifier_node($3);
            $$ = create_binary_op_node(OP_SUB, left, right);
            free($1);
            free($3);
          }
          | INTERO DIFFERENZA INTERO
          {
            ASTNode *left = create_literal_int_node($1);
            ASTNode *right = create_literal_int_node($3);
            $$ = create_binary_op_node(OP_SUB, left, right);
          }
          | FLOATING DIFFERENZA FLOATING
          {
            ASTNode *left = create_literal_float_node($1);
            ASTNode *right = create_literal_float_node($3);
            $$ = create_binary_op_node(OP_SUB, left, right);
          }
          | FLOATING DIFFERENZA INTERO
          {
            ASTNode *left = create_literal_float_node($1);
            ASTNode *right = create_literal_int_node($3);
            $$ = create_binary_op_node(OP_SUB, left, right);
          }
          | INTERO DIFFERENZA FLOATING
          {
            ASTNode *left = create_literal_int_node($1);
            ASTNode *right = create_literal_float_node($3);
            $$ = create_binary_op_node(OP_SUB, left, right);
          }
          ;

moltiplicazione: ID MOLTIPLICAZIONE ID
               {
                if (!symbol_defined($1) || !symbol_defined($3)) {
                    yyerror("Variabile non definita");
                    free($1);
                    free($3);
                    YYERROR;
                }
                DataType type1 = get_symbol_type($1);
                DataType type2 = get_symbol_type($3);
                
                if (type1 == TYPE_FLOAT || type2 == TYPE_FLOAT) {
                } else if (type1 == TYPE_INT && type2 == TYPE_INT) {
                } else {
                    yyerror("Operazione aritmetica non valida: tipi non compatibili");
                    free($1);
                    free($3);
                    YYERROR;
                }
                ASTNode *left = create_identifier_node($1);
                ASTNode *right = create_identifier_node($3);
                $$ = create_binary_op_node(OP_MUL, left, right);
                free($1);
                free($3);
               }
               | INTERO MOLTIPLICAZIONE INTERO
               {
                ASTNode *left = create_literal_int_node($1);
                ASTNode *right = create_literal_int_node($3);
                $$ = create_binary_op_node(OP_MUL, left, right);
               }
               | FLOATING MOLTIPLICAZIONE FLOATING
               {
                ASTNode *left = create_literal_float_node($1);
                ASTNode *right = create_literal_float_node($3);
                $$ = create_binary_op_node(OP_MUL, left, right);
               }
               | FLOATING MOLTIPLICAZIONE INTERO
              {
                ASTNode *left = create_literal_float_node($1);
                ASTNode *right = create_literal_int_node($3);
                $$ = create_binary_op_node(OP_MUL, left, right);
               }
               | INTERO MOLTIPLICAZIONE FLOATING
               {
                ASTNode *left = create_literal_int_node($1);
                ASTNode *right = create_literal_float_node($3);
                $$ = create_binary_op_node(OP_MUL, left, right);
               }
               ;

divisione: ID DIVISIONE ID
         {
            if (!symbol_defined($1) || !symbol_defined($3)) {
                yyerror("Variabile non definita");
                free($1);
                free($3);
                YYERROR;
            }
            DataType type1 = get_symbol_type($1);
            DataType type2 = get_symbol_type($3);
            
            if (type1 == TYPE_FLOAT || type2 == TYPE_FLOAT) {
            } else if (type1 == TYPE_INT && type2 == TYPE_INT) {
           } else {
                yyerror("Operazione aritmetica non valida: tipi non compatibili");
                free($1);
                free($3);
                YYERROR;
            }
            ASTNode *left = create_identifier_node($1);
            ASTNode *right = create_identifier_node($3);
            $$ = create_binary_op_node(OP_DIV, left, right);
            free($1);
            free($3);
         }
         | INTERO DIVISIONE INTERO
         {
            ASTNode *left = create_literal_int_node($1);
            ASTNode *right = create_literal_int_node($3);
            $$ = create_binary_op_node(OP_DIV, left, right);
         }
         | FLOATING DIVISIONE FLOATING
         {
            ASTNode *left = create_literal_float_node($1);
            ASTNode *right = create_literal_float_node($3);
            $$ = create_binary_op_node(OP_DIV, left, right);
         }
         | FLOATING DIVISIONE INTERO
         {
            ASTNode *left = create_literal_float_node($1);
            ASTNode *right = create_literal_int_node($3);
            $$ = create_binary_op_node(OP_DIV, left, right);
         }
         | INTERO DIVISIONE FLOATING
         {
            ASTNode *left = create_literal_int_node($1);
            ASTNode *right = create_literal_float_node($3);
            $$ = create_binary_op_node(OP_DIV, left, right);
         }
         ;
         
output:
    PRINT TONDA_APERTA STRINGA_NORMALE TONDA_CHIUSA
    {
        $$ = create_printf_node($3, NULL);
    }
  | PRINT TONDA_APERTA STRINGA_PLACEHOLDER COMA
      {
          ph_count = 0;
          var_count = 0;
          in_printf_context = 1;
          extract_placeholders($3, ph_types, &ph_count);
      }
      argomenti TONDA_CHIUSA
      {
          in_printf_context = 0;
          if (ph_count != var_count) {
              char error_msg[256];
              snprintf(error_msg, sizeof(error_msg),
                       "Errore printf: numero placeholder (%d) != numero argomenti (%d)",
                       ph_count, var_count);
              yyerror(error_msg);
              YYERROR;
          }
          for (int i = 0; i < ph_count; ++i) {
              if (!placeholder_matches(ph_types[i], var_types[i])) {
                  char error_msg[256];
                  snprintf(error_msg, sizeof(error_msg),
                      "Errore printf: placeholder %d (%s) non compatibile con argomento %d (%s)",
                      i+1,
                      type_to_string((DataType)ph_types[i]),
                      i+1,
                      type_to_string((DataType)var_types[i]));
                  yyerror(error_msg);
                  YYERROR;
              }
          }
          $$ = create_printf_node($3, $6);
      }
    ;

input: SCANF TONDA_APERTA STRINGA_PLACEHOLDER COMA
      {
          scanf_ph_count = 0;
          extract_placeholders($3, scanf_ph_types, &scanf_ph_count);
          scanf_var_count = 0;
          in_scanf_context = 1;
      }
      lista_indirizzi TONDA_CHIUSA
      {
          in_scanf_context = 0;
          if (scanf_ph_count != scanf_var_count) {
              char error_msg[256];
              snprintf(error_msg, sizeof(error_msg),
                       "Errore scanf: numero placeholder (%d) != numero indirizzi (%d)",
                       scanf_ph_count, scanf_var_count);
              yyerror(error_msg);
              YYERROR;
          }
          for (int i = 0; i < scanf_ph_count; ++i) {
              if (!placeholder_matches(scanf_ph_types[i], scanf_var_types[i])) {
                  char error_msg[256];
                  snprintf(error_msg, sizeof(error_msg),
                      "Errore scanf: placeholder %d (%s) non compatibile con variabile di tipo %s",
                      i+1,
                      type_to_string((DataType)scanf_ph_types[i]),
                      type_to_string((DataType)scanf_var_types[i]));
                  yyerror(error_msg);
                  YYERROR;
              }
          }
          $$ = create_scanf_node($3, $6);
      }
    ;

lista_indirizzi: INDIRIZZO
               {
                  if (scanf_var_count < MAX_PLACEHOLDERS) {
                      char *var_name = extract_var_name_from_address($1);
                      if (var_name == NULL) {
                          yyerror("Formato indirizzo non valido");
                          YYERROR;
                      }
                      if (!symbol_defined(var_name)) {
                          yyerror("Variabile non definita in scanf");
                          free(var_name);
                          YYERROR;
                      }
                      scanf_var_types[scanf_var_count++] = get_symbol_type(var_name);
                      free(var_name);
                  }
                  ASTNode *arg = create_identifier_node($1);
                  $$ = create_statement_list_node();
                  add_child($$, arg);
                  free($1);
               }
               | lista_indirizzi COMA INDIRIZZO
               {
                  if (scanf_var_count < MAX_PLACEHOLDERS) {
                      char *var_name = extract_var_name_from_address($3);
                      if (var_name == NULL) {
                          yyerror("Formato indirizzo non valido");
                          YYERROR;
                      }
                      if (!symbol_defined(var_name)) {
                          yyerror("Variabile non definita in scanf");
                          free(var_name);
                          YYERROR;
                      }
                      scanf_var_types[scanf_var_count++] = get_symbol_type(var_name);
                      free(var_name);
                  }
                  ASTNode *arg = create_identifier_node($3);
                  add_child($1, arg);
                  $$ = $1;
                  free($3);
               }
               ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Errore: %s\n", s);
}

int main() {
    int result = yyparse();
    int ast_write_failed = 0;
    
    if (result == 0 && ast_root != NULL) {
        FILE *json_file = fopen("ast.json", "w");
        if (json_file) {
            ast_to_json(ast_root, json_file);
            fclose(json_file);
            printf("AST generato in ast.json\n");
        } else {
            fprintf(stderr, "Errore: impossibile creare il file ast.json\n");
            ast_write_failed = 1;
        }
    }
    
    Symbol *current = symbol_table;
    while (current != NULL) {
        Symbol *next = current->next;
        free(current->name);
        Param *param = current->params;
        while (param != NULL) {
            Param *temp = param;
            param = param->next;
            free(temp);
        }
        free(current);
        current = next;
    }
    
    free_ast(ast_root);
    
    if (result == 0 && !ast_write_failed) {
        printf("[OK] Parsing completato\n");
    } else {
        printf("[ERROR] Si è verificato un errore durante el parsing\n");
    }
    return result == 0 ? ast_write_failed : result;
}
