%option noyywrap nodefault

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "linenoise.h"   // readline alternative

#define YY_DECL int yylex()

/*
 * redefine YY_INPUT macro flex uses to read input into the current buffer.
 * whenever the scanner's input buffer is empty, it invokes YY_INPUT, where
 * `buf` and `maxsize` are the buffer and its size respectively, and
 * `result` is the actual amount read, or zero at EOF.
 */
#define YY_INPUT(buf,result,max_size) result = linenoise_input(buf, max_size);

const char* get_prompt();
int linenoise_input(char *buf, int size) {
    char *line;
    if (feof(yyin))
        return YY_NULL;
    line = linenoise(get_prompt());
    if(!line)
        return YY_NULL;
    if (strlen(line) > size - 2) {
        fprintf(stderr,"input line too long\n");
        return YY_NULL;
    }
    sprintf(buf, "%s\n", line);
    linenoiseHistoryAdd(line);
    free(line);
    return strlen(buf);
}

/* parser calls this whenever it detects a syntax error */
void yyerror(const char* s) {
    fprintf(stderr, "Error: %s at `%s`. Type `?` for help.\n", s, yytext);
    //exit(1);
}

#include "calc.tab.h"

%}

%%

 /*
  * flex resolves ambiguity (multiple patterns match the same input) with
  * two simple rules:
  * 1. the longest match wins
  * 2. in case of a tie, the first declared pattern wins
  */

 /*
  * read the numbers as positive integers, treating the leading '-' as
  * a separate token that is interpreted syntactically (by bison/yacc)
  * as either negation or subtraction depending on context.
  */

0                  { yylval.info.text = strndup(yytext, yyleng); return INT; }
[1-9][0-9]*        { yylval.info.text = strndup(yytext, yyleng); return INT; }
0[xX][0-9a-fA-F]+  { yylval.info.text = strndup(yytext, yyleng); return HEXINT; }
[bodhBODH]+        { yylval.info.text = strndup(yytext, yyleng); return TOGGLE; }

 /*
  * operator uses its literal value as token type;
  * as well as quit and help commands (`q` & `?`);
  */

[-+*/%()&|^~]      { return yytext[0]; }
"<<"               { return SHL; } // logical shift left
">>"               { return SHR; } // logical shift right
">>>"              { return ASR; } // arithemtic shift right
[q?]               { return yytext[0]; }
\n                 { return EOL; }
[ \t]              { ; } // ignore all whitespace
.                  { return yytext[0]; }
%%
