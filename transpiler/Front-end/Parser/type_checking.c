#include "type_checking.h"
#include "ast.h"

int ph_types[MAX_PLACEHOLDERS];
int var_types[MAX_PLACEHOLDERS];
int ph_count = 0;
int var_count = 0;
int in_printf_context = 0;
int in_scanf_context = 0;
Param *current_function_params = NULL;
Param *current_call_params = NULL;
int scanf_ph_types[MAX_PLACEHOLDERS];
int scanf_var_types[MAX_PLACEHOLDERS];
int scanf_ph_count = 0;
int scanf_var_count = 0;

int types_compatible(DataType var_type, DataType value_type) {
    if (var_type == value_type) return 1;
    if (var_type == TYPE_FLOAT && value_type == TYPE_INT) return 1;
    return 0;
}

int comparison_types_compatible(DataType type1, DataType type2) {
    // Confronto tra numeri (int e float sono compatibili)
    if ((type1 == TYPE_INT || type1 == TYPE_FLOAT) && 
        (type2 == TYPE_INT || type2 == TYPE_FLOAT)) {
        return 1;
    }
    // Confronto tra caratteri
    if (type1 == TYPE_CHAR && type2 == TYPE_CHAR) {
        return 1;
    }
    return 0;
}

void extract_placeholders(const char *s, int ph_types_local[], int *ph_cnt) {
    int i = 0;
    if (!s) return;
    if (s[0] == '\"' || s[0] == '\'') i = 1;
    while (s[i]) {
        if (s[i] == '%') {
            if (s[i+1] == '%') { i += 2; continue; }
            char spec = s[i+1];
            if (spec == 'd') {
                ph_types_local[*ph_cnt] = TYPE_INT;
                (*ph_cnt)++;
            } else if (spec == 'f') {
                ph_types_local[*ph_cnt] = TYPE_FLOAT;
                (*ph_cnt)++;
            } else if (spec == 'c') {
                ph_types_local[*ph_cnt] = TYPE_CHAR;
                (*ph_cnt)++;
            } else {
                ph_types_local[*ph_cnt] = TYPE_UNKNOWN;
                (*ph_cnt)++;
            }
            i += 2;
            continue;
        }
        i++;
    }
}

int placeholder_matches(int ph, int vt) {
    if (ph == TYPE_INT)   return (vt == TYPE_INT);
    if (ph == TYPE_FLOAT) return (vt == TYPE_FLOAT);
    if (ph == TYPE_CHAR)  return (vt == TYPE_CHAR);
    return 0;
}

char* extract_var_name_from_address(const char *address) {
    if (address == NULL || address[0] != '&') return NULL;
    return xstrdup(address + 1);
}

void add_param_to_call(DataType type) {
    Param *new_param = malloc(sizeof(Param));
    new_param->type = type;
    new_param->next = current_call_params;
    current_call_params = new_param;
}
