all: myc

calc.tab.c calc.tab.h: calc.y
	bison -d calc.y

lex.yy.c: calc.l calc.tab.h
	flex calc.l

myc: lex.yy.c calc.tab.c calc.tab.h linenoise.c linenoise.h
	gcc -o $@ calc.tab.c lex.yy.c linenoise.c

clean:
	rm myc calc.tab.c lex.yy.c calc.tab.h
