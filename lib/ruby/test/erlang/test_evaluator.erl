-module(test_evaluator).
-export([test/0]).

test() ->
  io:format("~n=== Running Evaluator Tests ===~n"),

  % テスト実行
  test_literals(),
  test_variables(),
  test_arithmetic_operations(),
  test_comparison_operations(),
  test_logical_operations(),
  test_bitwise_operations(),
  test_if_statements(),
  test_while_statements(),
  test_until_statements(),

  io:format("~n=== All Evaluator Tests Passed ===~n"),
  ok.

%% テストヘルパー
assert_eval(AST, Expected, TestName) ->
  case ruby_evaluator:eval(AST) of
    {ok, Result, _Env} ->
      case Result =:= Expected of
        true ->
          io:format("  [PASS] ~s~n", [TestName]);
        false ->
          io:format("  [FAIL] ~s~n", [TestName]),
          io:format("    AST:      ~p~n", [AST]),
          io:format("    Expected: ~p~n", [Expected]),
          io:format("    Actual:   ~p~n", [Result]),
          erlang:error({assertion_failed, TestName})
      end;
    {error, Reason} ->
      io:format("  [FAIL] ~s~n", [TestName]),
      io:format("    AST:   ~p~n", [AST]),
      io:format("    Error: ~p~n", [Reason]),
      erlang:error({eval_error, TestName, Reason})
  end.

assert_eval_error(AST, TestName) ->
  case ruby_evaluator:eval(AST) of
    {ok, Result, _Env} ->
      io:format("  [FAIL] ~s (expected error but got result)~n", [TestName]),
      io:format("    AST:    ~p~n", [AST]),
      io:format("    Result: ~p~n", [Result]),
      erlang:error({expected_error, TestName});
    {error, _Reason} ->
      io:format("  [PASS] ~s~n", [TestName])
  end.

%% 個別テスト

test_literals() ->
  % 整数リテラル
  assert_eval([{integer, 1, 42}], 42, "integer literal 42"),
  assert_eval([{integer, 1, 0}], 0, "integer literal 0"),
  assert_eval([{integer, 1, -10}], -10, "integer literal -10"),

  % 文字列リテラル
  assert_eval([{string, 1, "hello"}], "hello", "string literal"),
  assert_eval([{string, 1, ""}], "", "empty string literal"),

  % ブール値リテラル
  assert_eval([{boolean, 1, true}], true, "true literal"),
  assert_eval([{boolean, 1, false}], false, "false literal"),

  % nilリテラル
  assert_eval([{nil, 1}], nil, "nil literal"),

  ok.

test_variables() ->
  % 変数の代入と参照
  AST1 = [
    {assign, 1, {var, 1, "x"}, {integer, 1, 10}},
    {identifier, 2, "x"}
  ],
  assert_eval(AST1, 10, "variable assignment and reference"),

  % 複数の変数
  AST2 = [
    {assign, 1, {var, 1, "x"}, {integer, 1, 5}},
    {assign, 2, {var, 2, "y"}, {integer, 2, 3}},
    {binary_op, 3, '+', {identifier, 3, "x"}, {identifier, 3, "y"}}
  ],
  assert_eval(AST2, 8, "multiple variables"),

  % 変数の再代入
  AST3 = [
    {assign, 1, {var, 1, "x"}, {integer, 1, 5}},
    {assign, 2, {var, 2, "x"}, {integer, 2, 10}},
    {identifier, 3, "x"}
  ],
  assert_eval(AST3, 10, "variable reassignment"),

  % 未定義変数の参照（エラー）
  assert_eval_error([{identifier, 1, "undefined_var"}], "undefined variable error"),

  ok.

test_arithmetic_operations() ->
  % 加算
  assert_eval([{binary_op, 1, '+', {integer, 1, 3}, {integer, 1, 4}}],
              7, "addition"),

  % 減算
  assert_eval([{binary_op, 1, '-', {integer, 1, 10}, {integer, 1, 3}}],
              7, "subtraction"),

  % 乗算
  assert_eval([{binary_op, 1, '*', {integer, 1, 5}, {integer, 1, 6}}],
              30, "multiplication"),

  % 除算
  assert_eval([{binary_op, 1, '/', {integer, 1, 20}, {integer, 1, 4}}],
              5, "division"),

  % 剰余
  assert_eval([{binary_op, 1, '%', {integer, 1, 17}, {integer, 1, 5}}],
              2, "modulo"),

  % ゼロ除算エラー
  assert_eval_error([{binary_op, 1, '/', {integer, 1, 10}, {integer, 1, 0}}],
                    "division by zero error"),

  % 複雑な算術式
  AST = {binary_op, 1, '+',
          {binary_op, 1, '*', {integer, 1, 2}, {integer, 1, 3}},
          {integer, 1, 4}},
  assert_eval([AST], 10, "complex arithmetic: 2 * 3 + 4"),

  ok.

test_comparison_operations() ->
  % 等価比較
  assert_eval([{binary_op, 1, '==', {integer, 1, 5}, {integer, 1, 5}}],
              true, "equal comparison (true)"),
  assert_eval([{binary_op, 1, '==', {integer, 1, 5}, {integer, 1, 3}}],
              false, "equal comparison (false)"),

  % 不等価比較
  assert_eval([{binary_op, 1, '!=', {integer, 1, 5}, {integer, 1, 3}}],
              true, "not equal comparison (true)"),
  assert_eval([{binary_op, 1, '!=', {integer, 1, 5}, {integer, 1, 5}}],
              false, "not equal comparison (false)"),

  % 小なり比較
  assert_eval([{binary_op, 1, '<', {integer, 1, 3}, {integer, 1, 5}}],
              true, "less than (true)"),
  assert_eval([{binary_op, 1, '<', {integer, 1, 5}, {integer, 1, 3}}],
              false, "less than (false)"),

  % 大なり比較
  assert_eval([{binary_op, 1, '>', {integer, 1, 5}, {integer, 1, 3}}],
              true, "greater than (true)"),
  assert_eval([{binary_op, 1, '>', {integer, 1, 3}, {integer, 1, 5}}],
              false, "greater than (false)"),

  % 小なりイコール
  assert_eval([{binary_op, 1, '<=', {integer, 1, 3}, {integer, 1, 5}}],
              true, "less than or equal (true)"),
  assert_eval([{binary_op, 1, '<=', {integer, 1, 5}, {integer, 1, 5}}],
              true, "less than or equal (equal)"),

  % 大なりイコール
  assert_eval([{binary_op, 1, '>=', {integer, 1, 5}, {integer, 1, 3}}],
              true, "greater than or equal (true)"),
  assert_eval([{binary_op, 1, '>=', {integer, 1, 5}, {integer, 1, 5}}],
              true, "greater than or equal (equal)"),

  ok.

test_logical_operations() ->
  % AND演算（両方真）
  assert_eval([{binary_op, 1, 'and', {boolean, 1, true}, {boolean, 1, true}}],
              true, "logical and (true and true)"),

  % AND演算（片方偽）
  assert_eval([{binary_op, 1, 'and', {boolean, 1, true}, {boolean, 1, false}}],
              false, "logical and (true and false)"),

  % OR演算（両方偽）
  assert_eval([{binary_op, 1, 'or', {boolean, 1, false}, {boolean, 1, false}}],
              false, "logical or (false or false)"),

  % OR演算（片方真）
  assert_eval([{binary_op, 1, 'or', {boolean, 1, true}, {boolean, 1, false}}],
              true, "logical or (true or false)"),

  % Rubyの真偽値判定（nilとfalse以外は真）
  assert_eval([{binary_op, 1, 'and', {integer, 1, 5}, {boolean, 1, true}}],
              true, "truthy value (number)"),
  assert_eval([{binary_op, 1, 'and', {string, 1, "hello"}, {boolean, 1, true}}],
              true, "truthy value (string)"),
  assert_eval([{binary_op, 1, 'or', {nil, 1}, {boolean, 1, true}}],
              true, "falsy value (nil)"),

  ok.

test_bitwise_operations() ->
  % ビットAND
  assert_eval([{binary_op, 1, '&', {integer, 1, 12}, {integer, 1, 10}}],
              8, "bitwise and"),

  % ビットOR
  assert_eval([{binary_op, 1, '|', {integer, 1, 12}, {integer, 1, 10}}],
              14, "bitwise or"),

  % ビットXOR
  assert_eval([{binary_op, 1, '^', {integer, 1, 12}, {integer, 1, 10}}],
              6, "bitwise xor"),

  % ビットNOT
  assert_eval([{unary_op, 1, '~', {integer, 1, 5}}],
              -6, "bitwise not"),

  % 左シフト
  assert_eval([{binary_op, 1, '<<', {integer, 1, 5}, {integer, 1, 2}}],
              20, "left shift"),

  % 右シフト
  assert_eval([{binary_op, 1, '>>', {integer, 1, 20}, {integer, 1, 2}}],
              5, "right shift"),

  ok.

test_if_statements() ->
  % 条件が真の場合
  AST1 = [{if_stmt, 1,
           {boolean, 1, true},
           [{integer, 2, 10}],
           [],
           []}],
  assert_eval(AST1, 10, "if statement (true condition)"),

  % 条件が偽の場合
  AST2 = [{if_stmt, 1,
           {boolean, 1, false},
           [{integer, 2, 10}],
           [],
           []}],
  assert_eval(AST2, nil, "if statement (false condition)"),

  % else句を持つif文（条件が偽）
  AST3 = [{if_stmt, 1,
           {boolean, 1, false},
           [{integer, 2, 10}],
           [],
           {else_clause, 3, [{integer, 3, 20}]}}],
  assert_eval(AST3, 20, "if-else statement (false condition)"),

  % elsif句を持つif文
  AST4 = [{if_stmt, 1,
           {boolean, 1, false},
           [{integer, 2, 10}],
           [{elsif, 3, {boolean, 3, true}, [{integer, 3, 30}]}],
           {else_clause, 4, [{integer, 4, 40}]}}],
  assert_eval(AST4, 30, "if-elsif-else statement (elsif true)"),

  % 変数を使った条件分岐
  AST5 = [
    {assign, 1, {var, 1, "x"}, {integer, 1, 5}},
    {if_stmt, 2,
     {binary_op, 2, '>', {identifier, 2, "x"}, {integer, 2, 3}},
     [{integer, 3, 100}],
     [],
     {else_clause, 4, [{integer, 4, 200}]}}
  ],
  assert_eval(AST5, 100, "if statement with variable condition"),

  ok.

test_while_statements() ->
  % 基本的なwhile文
  AST1 = [
    {assign, 1, {var, 1, "x"}, {integer, 1, 0}},
    {while_stmt, 2,
     {binary_op, 2, '<', {identifier, 2, "x"}, {integer, 2, 3}},
     [{assign, 3, {var, 3, "x"},
       {binary_op, 3, '+', {identifier, 3, "x"}, {integer, 3, 1}}}]},
    {identifier, 4, "x"}
  ],
  assert_eval(AST1, 3, "while loop (counting to 3)"),

  % 条件が最初から偽のwhile文
  AST2 = [
    {while_stmt, 1,
     {boolean, 1, false},
     [{integer, 2, 10}]},
    {integer, 3, 20}
  ],
  assert_eval(AST2, 20, "while loop (never executed)"),

  ok.

test_until_statements() ->
  % 基本的なuntil文
  AST1 = [
    {assign, 1, {var, 1, "x"}, {integer, 1, 0}},
    {until_stmt, 2,
     {binary_op, 2, '>=', {identifier, 2, "x"}, {integer, 2, 3}},
     [{assign, 3, {var, 3, "x"},
       {binary_op, 3, '+', {identifier, 3, "x"}, {integer, 3, 1}}}]},
    {identifier, 4, "x"}
  ],
  assert_eval(AST1, 3, "until loop (counting to 3)"),

  % 条件が最初から真のuntil文
  AST2 = [
    {until_stmt, 1,
     {boolean, 1, true},
     [{integer, 2, 10}]},
    {integer, 3, 20}
  ],
  assert_eval(AST2, 20, "until loop (never executed)"),

  ok.
