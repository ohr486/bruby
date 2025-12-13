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
  test_method_operations(),
  test_class_operations(),

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

test_method_operations() ->
  % 引数なしのメソッド定義と呼び出し
  AST1 = [
    {method_def, 1, "hello", [], [{integer, 2, 42}]},
    {call, 3, "hello", []}
  ],
  assert_eval(AST1, 42, "method definition and call (no args)"),

  % 引数1つのメソッド定義と呼び出し
  AST2 = [
    {method_def, 1, "double", [{param, 1, "x"}],
     [{binary_op, 2, '*', {identifier, 2, "x"}, {integer, 2, 2}}]},
    {call, 3, "double", [{integer, 3, 5}]}
  ],
  assert_eval(AST2, 10, "method with one parameter"),

  % 引数2つのメソッド定義と呼び出し
  AST3 = [
    {method_def, 1, "add", [{param, 1, "x"}, {param, 1, "y"}],
     [{binary_op, 2, '+', {identifier, 2, "x"}, {identifier, 2, "y"}}]},
    {call, 3, "add", [{integer, 3, 3}, {integer, 3, 4}]}
  ],
  assert_eval(AST3, 7, "method with two parameters"),

  % メソッド内でのローカル変数
  AST4 = [
    {method_def, 1, "compute", [{param, 1, "x"}],
     [
       {assign, 2, {var, 2, "y"}, {integer, 2, 10}},
       {binary_op, 3, '+', {identifier, 3, "x"}, {identifier, 3, "y"}}
     ]},
    {call, 4, "compute", [{integer, 4, 5}]}
  ],
  assert_eval(AST4, 15, "method with local variable"),

  % return文を持つメソッド
  AST5 = [
    {method_def, 1, "early_return", [{param, 1, "x"}],
     [
       {if_stmt, 2,
        {binary_op, 2, '>', {identifier, 2, "x"}, {integer, 2, 10}},
        [{return, 3, {integer, 3, 999}}],
        [],
        []},
       {integer, 4, 1}
     ]},
    {call, 5, "early_return", [{integer, 5, 15}]}
  ],
  assert_eval(AST5, 999, "method with early return"),

  % メソッド呼び出しに式を渡す
  AST6 = [
    {method_def, 1, "triple", [{param, 1, "x"}],
     [{binary_op, 2, '*', {identifier, 2, "x"}, {integer, 2, 3}}]},
    {call, 3, "triple", [{binary_op, 3, '+', {integer, 3, 2}, {integer, 3, 3}}]}
  ],
  assert_eval(AST6, 15, "method call with expression argument"),

  % メソッドからメソッドを呼び出す
  AST7 = [
    {method_def, 1, "square", [{param, 1, "x"}],
     [{binary_op, 2, '*', {identifier, 2, "x"}, {identifier, 2, "x"}}]},
    {method_def, 3, "square_plus_one", [{param, 3, "x"}],
     [{binary_op, 4, '+', {call, 4, "square", [{identifier, 4, "x"}]}, {integer, 4, 1}}]},
    {call, 5, "square_plus_one", [{integer, 5, 4}]}
  ],
  assert_eval(AST7, 17, "method calling another method"),

  % 未定義メソッドの呼び出しエラー
  assert_eval_error([{call, 1, "undefined_method", []}], "undefined method error"),

  % 引数の数が間違っている場合のエラー
  AST8 = [
    {method_def, 1, "add", [{param, 1, "x"}, {param, 1, "y"}],
     [{binary_op, 2, '+', {identifier, 2, "x"}, {identifier, 2, "y"}}]},
    {call, 3, "add", [{integer, 3, 3}]}
  ],
  assert_eval_error(AST8, "wrong number of arguments error"),

  ok.

test_class_operations() ->
  % 空のクラス定義
  AST1 = [{class_def, 1, "EmptyClass", []}],
  assert_eval(AST1, 'EmptyClass', "empty class definition"),

  % クラス定義はクラス名（シンボル）を返す
  AST2 = [{class_def, 1, "MyClass", []}],
  assert_eval(AST2, 'MyClass', "class definition returns class name"),

  % メソッドを含むクラス定義
  AST3 = [
    {class_def, 1, "Calculator", [
      {method_def, 2, "add", [{param, 2, "x"}, {param, 2, "y"}],
       [{binary_op, 3, '+', {identifier, 3, "x"}, {identifier, 3, "y"}}]},
      {method_def, 4, "multiply", [{param, 4, "x"}, {param, 4, "y"}],
       [{binary_op, 5, '*', {identifier, 5, "x"}, {identifier, 5, "y"}}]}
    ]}
  ],
  assert_eval(AST3, 'Calculator', "class with methods"),

  % クラス内で変数を使うメソッド定義
  AST4 = [
    {class_def, 1, "Counter", [
      {method_def, 2, "increment", [{param, 2, "n"}],
       [
         {assign, 3, {var, 3, "result"}, {binary_op, 3, '+', {identifier, 3, "n"}, {integer, 3, 1}}},
         {identifier, 4, "result"}
       ]}
    ]}
  ],
  assert_eval(AST4, 'Counter', "class with method using local variables"),

  % 複数のクラス定義
  AST5 = [
    {class_def, 1, "ClassA", []},
    {class_def, 2, "ClassB", []}
  ],
  assert_eval(AST5, 'ClassB', "multiple class definitions"),

  ok.
