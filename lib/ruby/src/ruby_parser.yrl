Nonterminals
  program stmts stmt
  expr primary literal
  var_lhs
  call_args arg_list
  method_def method_params param_list
  if_stmt elsif_clauses elsif_clause else_clause
  .

Terminals
  tIDENTIFIER tINTEGER tSTRING
  tTRUE tFALSE tNIL
  tDEF tEND
  tIF tELSIF tELSE
  tRETURN tBREAK tNEXT
  tAND tOR
  tEQ tNE tLE tGE
  '=' '+' '-' '*' '/' '%'
  tLSHIFT tRSHIFT
  '&' '|' '^' '~'
  '<' '>'
  '(' ')' ',' ';'
  .

Rootsymbol program.

%% 優先順位と結合性
Right 100 '='.
Left 200 tOR.
Left 300 tAND.
Nonassoc 400 tEQ tNE.
Nonassoc 500 '<' '>' tLE tGE.
Left 600 '+' '-'.
Left 700 '*' '/' '%'.
Left 800 tLSHIFT tRSHIFT.
Left 900 '&' '|' '^' '~'.

%% プログラム全体
program -> stmts : '$1'.
program -> '$empty' : [].

%% ステートメントのリスト
stmts -> stmt : ['$1'].
stmts -> stmt ';' stmts : ['$1' | '$3'].
stmts -> stmt ';' : ['$1'].

%% 個別のステートメント
stmt -> expr : '$1'.
stmt -> var_lhs '=' expr : {assign, line_of('$2'), '$1', '$3'}.
stmt -> method_def : '$1'.
stmt -> if_stmt : '$1'.
stmt -> tRETURN : {return, line_of('$1'), nil}.
stmt -> tRETURN expr : {return, line_of('$1'), '$2'}.
stmt -> tBREAK : {break, line_of('$1')}.
stmt -> tNEXT : {next, line_of('$1')}.

var_lhs -> tIDENTIFIER : {var, line_of('$1'), value_of('$1')}.

%% 式（演算子の優先順位は宣言で処理）
expr -> primary : '$1'.
expr -> expr '+' expr : {binary_op, line_of('$2'), '+', '$1', '$3'}.
expr -> expr '-' expr : {binary_op, line_of('$2'), '-', '$1', '$3'}.
expr -> expr '*' expr : {binary_op, line_of('$2'), '*', '$1', '$3'}.
expr -> expr '/' expr : {binary_op, line_of('$2'), '/', '$1', '$3'}.
expr -> expr '%' expr : {binary_op, line_of('$2'), '%', '$1', '$3'}.
expr -> expr tLSHIFT expr : {binary_op, line_of('$2'), '<<', '$1', '$3'}.
expr -> expr tRSHIFT expr : {binary_op, line_of('$2'), '>>', '$1', '$3'}.
expr -> expr '&' expr : {binary_op, line_of('$2'), '&', '$1', '$3'}.
expr -> expr '|' expr : {binary_op, line_of('$2'), '|', '$1', '$3'}.
expr -> expr '^' expr : {binary_op, line_of('$2'), '^', '$1', '$3'}.
expr -> '~' expr : {unary_op, line_of('$1'), '~', '$2'}.
expr -> expr tEQ expr : {binary_op, line_of('$2'), '==', '$1', '$3'}.
expr -> expr tNE expr : {binary_op, line_of('$2'), '!=', '$1', '$3'}.
expr -> expr '<' expr : {binary_op, line_of('$2'), '<', '$1', '$3'}.
expr -> expr '>' expr : {binary_op, line_of('$2'), '>', '$1', '$3'}.
expr -> expr tLE expr : {binary_op, line_of('$2'), '<=', '$1', '$3'}.
expr -> expr tGE expr : {binary_op, line_of('$2'), '>=', '$1', '$3'}.
expr -> expr tAND expr : {binary_op, line_of('$2'), 'and', '$1', '$3'}.
expr -> expr tOR expr : {binary_op, line_of('$2'), 'or', '$1', '$3'}.
expr -> '(' expr ')' : '$2'.
expr -> tIDENTIFIER '(' call_args ')' : {call, line_of('$1'), value_of('$1'), '$3'}.
expr -> tIDENTIFIER '(' ')' : {call, line_of('$1'), value_of('$1'), []}.

call_args -> arg_list : '$1'.

arg_list -> expr : ['$1'].
arg_list -> expr ',' arg_list : ['$1' | '$3'].

%% プライマリ式
primary -> literal : '$1'.
primary -> tIDENTIFIER : {identifier, line_of('$1'), value_of('$1')}.

%% リテラル
literal -> tINTEGER : {integer, line_of('$1'), value_of('$1')}.
literal -> tSTRING : {string, line_of('$1'), value_of('$1')}.
literal -> tTRUE : {boolean, line_of('$1'), true}.
literal -> tFALSE : {boolean, line_of('$1'), false}.
literal -> tNIL : {nil, line_of('$1')}.

%% メソッド定義
method_def -> tDEF tIDENTIFIER method_params stmts tEND :
  {method_def, line_of('$1'), value_of('$2'), '$3', '$4'}.
method_def -> tDEF tIDENTIFIER method_params tEND :
  {method_def, line_of('$1'), value_of('$2'), '$3', []}.

method_params -> '(' param_list ')' : '$2'.
method_params -> '(' ')' : [].
method_params -> '$empty' : [].

param_list -> tIDENTIFIER : [{param, line_of('$1'), value_of('$1')}].
param_list -> tIDENTIFIER ',' param_list : [{param, line_of('$1'), value_of('$1')} | '$3'].

%% if文
if_stmt -> tIF expr stmts elsif_clauses else_clause tEND :
  {if_stmt, line_of('$1'), '$2', '$3', '$4', '$5'}.
if_stmt -> tIF expr stmts elsif_clauses tEND :
  {if_stmt, line_of('$1'), '$2', '$3', '$4', []}.
if_stmt -> tIF expr stmts else_clause tEND :
  {if_stmt, line_of('$1'), '$2', '$3', [], '$4'}.
if_stmt -> tIF expr stmts tEND :
  {if_stmt, line_of('$1'), '$2', '$3', [], []}.

elsif_clauses -> elsif_clause : ['$1'].
elsif_clauses -> elsif_clause elsif_clauses : ['$1' | '$2'].

elsif_clause -> tELSIF expr stmts : {elsif, line_of('$1'), '$2', '$3'}.

else_clause -> tELSE stmts : {else_clause, line_of('$1'), '$2'}.

Erlang code.

%% ヘルパー関数
line_of(Token) when is_tuple(Token) -> element(2, Token);
line_of(_) -> 0.

value_of({_, _, Value}) -> Value;
value_of({_, Line}) -> Line;
value_of(Value) -> Value.
