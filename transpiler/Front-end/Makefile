FLEX ?= flex
BISON ?= bison
CC ?= gcc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -D_POSIX_C_SOURCE=200809L -IParser -IScanner
LDFLAGS ?= -lfl

LEX_SRC := Scanner/scanner.l
YACC_SRC := Parser/parser.y
LEX_OUT := Scanner/lex.yy.c
YACC_OUT := Parser/parser.tab.c
YACC_HEADER := Parser/parser.tab.h

OBJS := \
	Parser/parser.tab.o \
	Scanner/lex.yy.o \
	Parser/ast.o \
	Parser/symbol_table.o \
	Parser/type_checking.o

all: myTranspiler

$(YACC_OUT) $(YACC_HEADER): $(YACC_SRC)
	$(BISON) -d -o $(YACC_OUT) $(YACC_SRC)

$(LEX_OUT): $(LEX_SRC) $(YACC_HEADER)
	$(FLEX) -o $(LEX_OUT) $(LEX_SRC)

Parser/parser.tab.o: $(YACC_OUT) Parser/ast.h Parser/symbol_table.h Parser/type_checking.h
	$(CC) $(CFLAGS) -c $(YACC_OUT) -o $@

Scanner/lex.yy.o: $(LEX_OUT) Parser/ast.h Parser/parser.tab.h
	$(CC) $(CFLAGS) -c $(LEX_OUT) -o $@

Parser/ast.o: Parser/ast.c Parser/ast.h
	$(CC) $(CFLAGS) -c $< -o $@

Parser/symbol_table.o: Parser/symbol_table.c Parser/symbol_table.h Parser/type_checking.h
	$(CC) $(CFLAGS) -c $< -o $@

Parser/type_checking.o: Parser/type_checking.c Parser/type_checking.h Parser/symbol_table.h
	$(CC) $(CFLAGS) -c $< -o $@

myTranspiler: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $@ $(LDFLAGS)

clean:
	$(RM) -f $(OBJS) myTranspiler $(LEX_OUT) $(YACC_OUT) $(YACC_HEADER)

.PHONY: all clean
