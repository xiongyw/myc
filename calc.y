%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
extern int yyparse();
extern FILE* yyin;

#define NUM_BITS        (sizeof(int)*8)
#define RADIX_MASK_2    ((1<<2))
#define RADIX_MASK_8    ((1<<8))
#define RADIX_MASK_10   ((1<<10))
#define RADIX_MASK_16   ((1<<16))

int g_radix = RADIX_MASK_10 | RADIX_MASK_16;

void yyerror(const char* s);
void prompt(void);
void help(void);
void toggle_output_format(const char* s);
void output_int_radix(int x, int radix);
void output_int(int x);

%}

%code requires {  /* also export the following to flex */

    typedef struct {
        const char* text;
    }TokenInfo;

}

/*
 * %union declaration: identify all possible semantic value types a symbol
 * (termainal or nonterminal) value can have.
 */
%union {
    int ival;
    //float fval;
    TokenInfo info;
}

/*
 * declare tokens (terminals) and their semantic value types.
 * Note that no need to declare literal character tokens, unless we need
 * to declare their semantic value types.
 *
 * bison also allows to declare strings as aliaes for tokens, for example,
 *   %token ASR ">>>"
 * this defines the token ASR and lets you use ASR and ">>>" interchangeably in
 * the production rules; also the syntax error msgs passed to yyerror() from
 * the parser will reference the alias instead of the token name.
 * however, the lexer must still return the internal token value for ASR when
 * the token is read, not a string.
 */
%token <info> INT HEXINT TOGGLE
%token EOL SHL SHR
%token ASR ">>>"

%left  SHL SHR ASR
%left  '+' '-'
%left  '*' '/' '%'
%left  '&' '|' '^'
%right '~'

/*
 * declare semantic value types for nonterminals.
 * similarly, no need to declare nonterminals whose values are not to be used.
 */
%type <ival> expr

/*
 * avoid memory leak when parser recovers from errors (i.e., pops symbols from
 * the semantic value stack). parser does not call it in normal reduction.
 */
%destructor { if($$.text) free((void*)$$.text); } <info>

/*
 * declare the start rule: not necessary if the first rule is the start rule,
 * as it should in most cases.
 */
%start eval

%%

 /*
  * default conflict-resolution in bison:
  * - reduce-reduce conflict: the first defined rule wins
  * - shift-reduce conflict: shift wins
  *
  * bison assigns each rule the precedence and associativity of the right most
  * token (terminal) on the RHS, as the precedence/associativity of the rule;
  * if that token has no precedence/associativity assined, the rule has no
  * precedence/associativity of its own. bison first consults the rules'
  * precedences/associativity to resolve conflicts, before falling back to the
  * default conflict-resolution mechanism.
  *
  * bison allows to explictly assign a precedence to a rule by appending
  * `%prec <terminal>` to the RHS of a rule, indicating that the rule has the
  * same precedence of the terminal. in this case, the terminal can be a
  * psedotoken (i.e., never returned from the scanner) which is just place
  * holder in the precedence levels.
  */

eval:   /* nothing. matches at beginning of input */
      | eval line
      ;

line:   EOL            { ; }
      | '?' EOL        { help(); }
      | 'q' EOL        { printf("bye!\n"); exit(0); }
      | expr EOL       { output_int($1); }
      | TOGGLE EOL     { toggle_output_format($1.text); free((void*)$1.text); }
      | error EOL      { yyerrok; /* resume normal parsing */ }
      ;

expr:   INT            { int t; sscanf($1.text, "%d", &t); free((void*)$1.text); $$ = t; }
      | HEXINT         { int t; sscanf($1.text, "%x", &t); free((void*)$1.text); $$ = t; }
      | expr '+' expr  { $$ = $1 + $3; }
      | expr '-' expr  { $$ = $1 - $3; }
      | expr '*' expr  { $$ = $1 * $3; }
      | expr '/' expr  { $$ = $1 / $3; }
      | expr '%' expr  { $$ = $1 % $3; }
      | expr '&' expr  { $$ = $1 & $3; }
      | expr '|' expr  { $$ = $1 | $3; }
      | expr '^' expr  { $$ = $1 ^ $3; }
      | expr SHL expr  { $$ = $1 << ($3 % NUM_BITS); }
      | expr ">>>" expr  { $$ = $1 >> ($3 % NUM_BITS); } // arithmetic shift right
      | expr SHR expr  { $$ = (unsigned int)$1 >> ($3 % NUM_BITS); } // logic shift right
      | '(' expr ')'   { $$ = $2; }
      | '~' expr       { $$ = ~$2; }
      | '-' expr       { $$ = -$2; }
      ;

%%

int main() {
    yyin = stdin;
    do {
        yyparse();
    } while(!feof(yyin));

    return 0;
}


void toggle_output_format(const char* s)
{
    int len = strlen(s);
    for (int i = 0; i < len; i ++) {
        switch(s[i]) {
            case 'b': case 'B':
                g_radix ^= RADIX_MASK_2;
                break;
            case 'o': case 'O':
                g_radix ^= RADIX_MASK_8;
                break;
            case 'd': case 'D':
                g_radix ^= RADIX_MASK_10;
                break;
            case 'h': case 'H':
                g_radix ^= RADIX_MASK_16;
                break;
            default:
                printf("strange: `%c` is invalid\n", s[i]);
                break;

        }
    }
}

const char* get_prompt()
{
#define PROMPT_SIZE    16
    static char s_prompt[PROMPT_SIZE];

    if ((g_radix & (RADIX_MASK_2 | RADIX_MASK_8 | RADIX_MASK_10 | RADIX_MASK_16)) == 0) {
        g_radix = RADIX_MASK_10;
    }

    s_prompt[0] = '\0';
    if (g_radix & RADIX_MASK_2){
        strcat(s_prompt, "b");
    }
    if (g_radix & RADIX_MASK_8) {
        strcat(s_prompt, "o");
    }
    if (g_radix & RADIX_MASK_10) {
        strcat(s_prompt, "d");
    }
    if (g_radix & RADIX_MASK_16){
        strcat(s_prompt, "h");
    }
    strcat(s_prompt, "> ");

    return s_prompt;
}

void prompt()
{
    if ((g_radix & (RADIX_MASK_2 | RADIX_MASK_8 | RADIX_MASK_10 | RADIX_MASK_16)) == 0) {
        g_radix = RADIX_MASK_10;
    }

    if (g_radix & RADIX_MASK_2)
        printf("b");
    if (g_radix & RADIX_MASK_8)
        printf("o");
    if (g_radix & RADIX_MASK_10)
        printf("d");
    if (g_radix & RADIX_MASK_16)
        printf("h");

    printf("> ");
}

void print_nibble(unsigned char x)
{
    printf(":");
    for (int i = 3; i >= 0; i --) {
        if (x & (1 << i)) {
            printf("1");
        } else {
            printf("0");
        }
    }
}

void print_binary(int x)
{
#if (0)
    int nbits = sizeof(x) * 8;
    int started = 0;
    for (int i = nbits - 1; i >= 0; i --) {
        if (x & (1 << i)) {
            started = 1;
            printf("1");
        } else {
            if (started)
                printf("0");
        }
    }

    if (!started)
        printf("0");
#else
    if (x == 0) {
        printf("0000");
    } else {
        int n_nibbles = sizeof(x) * 2;
        int started = 0;
        unsigned char nibble;
        for (int i = n_nibbles - 1; i >= 0; i --) {
            nibble = (unsigned char)((unsigned int)x >> (i * 4));
            if (nibble) {
               print_nibble(nibble);
               started = 1;
            } else if (started) {
               print_nibble(nibble);
            }
        }
    }
#endif
}

void output_int(int x)
{
    if (g_radix & RADIX_MASK_2) {
        printf("0b");
        print_binary(x);
        printf(" ");
    }
    if (g_radix & RADIX_MASK_8) {
        printf("0%o ", x);
    }
    if (g_radix & RADIX_MASK_10) {
        printf("%d ", x);
    }
    if (g_radix & RADIX_MASK_16) {
        printf("0x%X ", x);
    }

    printf("\n");
}

void help(void)
{
    printf("- supported operators for integers:\n");
    printf("    . arithmetic `+=*/%%`\n");
    printf("    . bitwise `&|^~`\n");
    printf("    . logical shift `<<`, `>>`\n");
    printf("    . arithmetic shift right `>>>`\n");
    printf("    . grouping parentheses `()`\n");
    printf("- input hex numbers by prefixing `0x` or `0X`\n");
    printf("- type `[bodhBODH]+` to toggle four output formats\n");
    printf("- type `?` to display this help\n");
    printf("- type `q` to quit\n");
}

