A simple command-line-based calculator which supports only integer
arithmetics (+, -, *, /, %) and bitwise operators (&, |, ^, ~), but

- allows mixed decimal and hexadecimal numbers in input expressions;
- can output numbers in multiple (bin/oct/dec/hex) formats at once;
- supports input history (using `linenoise`)


The motivation of doing this calculator (`myc`) is two fold:

- to avoid `ibase`/`obase` settings of `bc`, for my simple use cases
- practise with flex/bison

created: 2019.02.05
last updated: 2019.02.06
