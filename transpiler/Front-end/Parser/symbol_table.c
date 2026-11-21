#include "symbol_table.h"
#include "ast.h"
#include "type_checking.h"

Symbol *symbol_table = NULL;
DataType current_var_type = TYPE_UNKNOWN;

void add_symbol(char *name, DataType type, int is_function) {
    Symbol *new_symbol = malloc(sizeof(Symbol));
    new_symbol->name = xstrdup(name);
    new_symbol->type = type;
    new_symbol->is_function = is_function;
    new_symbol->params = NULL;
    new_symbol->next = symbol_table;
    symbol_table = new_symbol;
}

int symbol_defined(char *name) {
    Symbol *current = symbol_table;
    while (current != NULL) {
        if (strcmp(current->name, name) == 0) {
            return 1;
        }
        current = current->next;
    }
    return 0;
}

DataType get_symbol_type(char *name) {
    Symbol *current = symbol_table;
    while (current != NULL) {
        if (strcmp(current->name, name) == 0) {
            return current->type;
        }
        current = current->next;
    }
    return TYPE_UNKNOWN;
}

int is_function(char *name) {
    Symbol *current = symbol_table;
    while (current != NULL) {
        if (strcmp(current->name, name) == 0) {
            return current->is_function;
        }
        current = current->next;
    }
    return 0;
}

Param* get_function_params(char *name) {
    Symbol *current = symbol_table;
    while (current != NULL) {
        if (strcmp(current->name, name) == 0) {
            return current->params;
        }
        current = current->next;
    }
    return NULL;
}

const char* type_to_string(DataType type) {
    switch (type) {
        case TYPE_INT: return "int";
        case TYPE_FLOAT: return "float";
        case TYPE_CHAR: return "char";
        case TYPE_VOID: return "void";
        default: return "unknown";
    }
}

void free_param_list(Param *params) {
    while (params != NULL) {
        Param *temp = params;
        params = params->next;
        free(temp);
    }
}

int count_params(Param *params) {
    int count = 0;
    while (params != NULL) {
        count++;
        params = params->next;
    }
    return count;
}

int check_function_params(Param *expected, Param *actual) {
    int expected_count = 0, actual_count = 0;
    Param *exp = expected, *act = actual;
    
    while (exp != NULL && act != NULL) {
        if (!types_compatible(exp->type, act->type)) {
            return 0;
        }
        exp = exp->next;
        act = act->next;
        expected_count++;
        actual_count++;
    }
    
    if (exp != NULL || act != NULL) {
        return 0;
    }
    
    return 1;
}
