%{
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef _WIN32
#include <unistd.h>
#endif
#include "ast.h"   
#include "parser.tab.h"

static char *process_string_literal(const char *text) {
    size_t len = strlen(text);
    if (len < 2) {
        return xstrdup("");
    }

    /* Allocate len to safely accommodate escape shrinking */
    char *result = malloc(len);
    if (!result) {
        return NULL;
    }

    size_t j = 0;
    for (size_t i = 1; i < len - 1; ++i) {
        char c = text[i];
        if (c == '\\' && i + 1 < len - 1) {
            char next = text[++i];
            switch (next) {
                case 'n': result[j++] = '\n'; break;
                case 't': result[j++] = '\t'; break;
                case 'r': result[j++] = '\r'; break;
                case '\\': result[j++] = '\\'; break;
                case '"': result[j++] = '"'; break;
                case '\'': result[j++] = '\''; break;
                case '0': result[j++] = '\0'; break;
                default:
                    result[j++] = next;
                    break;
            }
        } else {
            result[j++] = c;
        }
    }
    result[j] = '\0';
    return result;
}

static int process_char_literal(const char *text) {
    size_t len = strlen(text);
    if (len >= 4 && text[1] == '\\') {
        char esc = text[2];
        switch (esc) {
            case 'n': return '\n';
            case 't': return '\t';
            case 'r': return '\r';
            case '\\': return '\\';
            case '\'': return '\'';
            case '"': return '"';
            case '0': return '\0';
            default: return esc;
        }
    }
    if (len >= 3) {
        return text[1];
    }
    return 0;
}
%}

%%

"while"					{ return WHILE; }
"if"					{ return IF; }
"else"					{ return ELSE; }

"printf"				{ return PRINT;}
"scanf"					{ return SCANF;}

"int"					{ return INT; }
"float"					{ return FLOAT; }
"char"					{ return CHAR; }
"void"					{ return VOID; }
"return"				{ return RETURN; }

"==" 					{ return UGUALE; }
"!="					{ return DIVERSO; }
">="					{ return MAGGIORE_UGUALE; }
"<="					{ return MINORE_UGUALE; }
">"					    { return MAGGIORE; }
"<"					    { return MINORE; }

"="    					{ return ASSEGNAZIONE; }
"+"					    { return SOMMA; }
"-" 					{ return DIFFERENZA; }
"*"					    { return MOLTIPLICAZIONE; }
"/"					    { return DIVISIONE; }

[0-9]+					{ 
                                           yylval.ival = atoi(yytext); 
                                           return INTERO; 
                                         }
[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?	{ 
                                           yylval.fval = atof(yytext); 
                                           return FLOATING; 
                                         }

'([^'\\]|\\.)'				{ 
                                           yylval.ival = process_char_literal(yytext); 
                                           return CARATTERE; 
                                         }

\"(\\.|[^"\\])*%[a-zA-Z0-9.*+-]*[diouxXfFeEgGaAcspn](\\.|[^"\\])*\"  { 
                                           yylval.sval = process_string_literal(yytext); 
                                           return STRINGA_PLACEHOLDER; 
                                         }
\"(\\.|[^"\\])*\"   			{ 
                                           yylval.sval = process_string_literal(yytext); 
                                           return STRINGA_NORMALE; 
                                         }

"{"					    { return GRAFFA_APERTA; }
"}"					    { return GRAFFA_CHIUSA; }
"("					    { return TONDA_APERTA; }
")"					    { return TONDA_CHIUSA; }

";"       				{ return SEMICOLON; }
","     				{ return COMA; }

[a-zA-Z_][a-zA-Z0-9_]*  		{ 
                                           yylval.sval = xstrdup(yytext); 
                                           return ID; 
                                         }
&[a-zA-Z_][a-zA-Z0-9_]*			{ 
                                           yylval.sval = xstrdup(yytext); 
                                           return INDIRIZZO; 
                                         }

\#[^\n]*                               ;

[ \t\n]                 ;

.         ;

%%

int yywrap() {
    return 1;
}
