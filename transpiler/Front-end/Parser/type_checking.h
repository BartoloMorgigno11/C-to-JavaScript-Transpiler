#ifndef TYPE_CHECKING_H
#define TYPE_CHECKING_H

#include "symbol_table.h"

#define MAX_PLACEHOLDERS 256

// Funzioni per il type checking
int types_compatible(DataType var_type, DataType value_type);
void extract_placeholders(const char *s, int ph_types_local[], int *ph_cnt);
int placeholder_matches(int ph, int vt);
char* extract_var_name_from_address(const char *address);
void add_param_to_call(DataType type);

// Variabili globali per type checking
extern int ph_types[MAX_PLACEHOLDERS];
extern int var_types[MAX_PLACEHOLDERS];
extern int ph_count;
extern int var_count;
extern int in_printf_context;
extern int in_scanf_context;
extern Param *current_function_params;
extern Param *current_call_params;
extern int scanf_ph_types[MAX_PLACEHOLDERS];
extern int scanf_var_types[MAX_PLACEHOLDERS];
extern int scanf_ph_count;
extern int scanf_var_count;
extern int comparison_types_compatible(DataType type1, DataType type2);

#endif
