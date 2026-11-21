#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Enumerazione per i tipi di dato
typedef enum {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_CHAR,
    TYPE_VOID,
    TYPE_UNKNOWN
} DataType;

// Struttura per i parametri delle funzioni
typedef struct Param {
    DataType type;
    struct Param *next;
} Param;

// Struttura per la tabella dei simboli
typedef struct Symbol {
    char *name;
    DataType type;
    Param *params; // Lista parametri per funzioni
    int is_function;
    struct Symbol *next;
} Symbol;

// Funzioni per la gestione della tabella dei simboli
void add_symbol(char *name, DataType type, int is_function);
int symbol_defined(char *name);
DataType get_symbol_type(char *name);
int is_function(char *name);
Param* get_function_params(char *name);
const char* type_to_string(DataType type);
void free_param_list(Param *params);
int count_params(Param *params);
int check_function_params(Param *expected, Param *actual);

// Variabili globali
extern Symbol *symbol_table;
extern DataType current_var_type;

#endif