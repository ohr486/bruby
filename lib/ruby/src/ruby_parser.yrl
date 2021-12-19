Nonterminals
  none
  program top_compstmt top_stmts
  expr
  command_call command command_args
  fcall
  operation
  op
  .

Terminals
  var
  tIDENTIFIER
  .

Rootsymbol program.

none -> var.

program -> top_compstmt.

top_compstmt -> top_stmts.
top_stmts -> expr.

expr ->  command_call.

command_call -> command.
command -> fcall command_args.
command_args -> none.

fcall -> operation.
operation -> op.
op -> tIDENTIFIER.

Erlang code.

