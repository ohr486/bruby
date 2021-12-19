Nonterminals
  program
  exps exp
  .

Terminals
  ';'
  var
  .

Rootsymbol program.

program ->
  exps : '$1'.

exps ->
  exp ';' exps :
    [ '$1' | '$3' ].

exp ->
  var : '$1'.


Erlang code.


