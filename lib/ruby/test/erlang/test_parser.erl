-module(test_parser).
-export([test/0]).

test() ->
  io:format("~n=== Running Parser Tests ===~n"),

  % テスト実行
  test_literals(),
  test_identifiers(),
  test_binary_operations(),
  test_method_calls(),
  test_assignments(),
  test_method_definitions(),
  test_if_statements(),
  test_complex_expressions(),

  io:format("~n=== All Parser Tests Passed ===~n"),
  ok.

%% テストヘルパー
assert_parse(Input, Expected, TestName) ->
  case tokenize_and_parse(Input) of
    {ok, Result} ->
      case Result =:= Expected of
        true ->
          io:format("  [PASS] ~s~n", [TestName]);
        false ->
          io:format("  [FAIL] ~s~n", [TestName]),
          io:format("    Input:    ~s~n", [Input]),
          io:format("    Expected: ~p~n", [Expected]),
          io:format("    Actual:   ~p~n", [Result]),
          erlang:error({assertion_failed, TestName})
      end;
    {error, Reason} ->
      io:format("  [FAIL] ~s~n", [TestName]),
      io:format("    Input:  ~s~n", [Input]),
      io:format("    Error:  ~p~n", [Reason]),
      erlang:error({parse_error, TestName, Reason})
  end.

assert_parse_ok(Input, TestName) ->
  case tokenize_and_parse(Input) of
    {ok, _Result} ->
      io:format("  [PASS] ~s~n", [TestName]);
    {error, Reason} ->
      io:format("  [FAIL] ~s~n", [TestName]),
      io:format("    Input: ~s~n", [Input]),
      io:format("    Error: ~p~n", [Reason]),
      erlang:error({parse_error, TestName, Reason})
  end.

tokenize_and_parse(Input) ->
  case ruby_tokenizer:tokenize(Input) of
    {ok, Tokens, _} ->
      case ruby_parser:parse(Tokens) of
        {ok, AST} -> {ok, AST};
        {error, Reason} -> {error, Reason}
      end;
    {error, Reason, _} ->
      {error, Reason}
  end.

%% 個別テスト

test_literals() ->
  % 整数
  assert_parse("42", [{integer, 1, 42}], "integer literal"),
  assert_parse("0", [{integer, 1, 0}], "zero literal"),

  % 文字列
  assert_parse("\"hello\"", [{string, 1, "hello"}], "string literal"),

  % ブール値とnil
  assert_parse("true", [{boolean, 1, true}], "true literal"),
  assert_parse("false", [{boolean, 1, false}], "false literal"),
  assert_parse("nil", [{nil, 1}], "nil literal"),
  ok.

test_identifiers() ->
  assert_parse("foo", [{identifier, 1, "foo"}], "simple identifier"),
  assert_parse("foo_bar", [{identifier, 1, "foo_bar"}], "identifier with underscore"),
  ok.

test_binary_operations() ->
  % 算術演算
  assert_parse("1 + 2",
    [{binary_op, 1, '+', {integer, 1, 1}, {integer, 1, 2}}],
    "addition"),

  assert_parse("10 - 5",
    [{binary_op, 1, '-', {integer, 1, 10}, {integer, 1, 5}}],
    "subtraction"),

  assert_parse("3 * 4",
    [{binary_op, 1, '*', {integer, 1, 3}, {integer, 1, 4}}],
    "multiplication"),

  assert_parse("10 / 2",
    [{binary_op, 1, '/', {integer, 1, 10}, {integer, 1, 2}}],
    "division"),

  % 比較演算
  assert_parse("x == 10",
    [{binary_op, 1, '==', {identifier, 1, "x"}, {integer, 1, 10}}],
    "equality"),

  assert_parse("x != 5",
    [{binary_op, 1, '!=', {identifier, 1, "x"}, {integer, 1, 5}}],
    "inequality"),

  assert_parse("x < 10",
    [{binary_op, 1, '<', {identifier, 1, "x"}, {integer, 1, 10}}],
    "less than"),

  assert_parse("x > 5",
    [{binary_op, 1, '>', {identifier, 1, "x"}, {integer, 1, 5}}],
    "greater than"),

  % 複雑な式
  assert_parse("1 + 2 * 3",
    [{binary_op, 1, '+',
      {integer, 1, 1},
      {binary_op, 1, '*', {integer, 1, 2}, {integer, 1, 3}}}],
    "operator precedence"),

  assert_parse("(1 + 2) * 3",
    [{binary_op, 1, '*',
      {binary_op, 1, '+', {integer, 1, 1}, {integer, 1, 2}},
      {integer, 1, 3}}],
    "parentheses grouping"),
  ok.

test_method_calls() ->
  % 引数なし
  assert_parse("foo()", [{call, 1, "foo", []}], "method call no args"),

  % 引数あり
  assert_parse("foo(1)", [{call, 1, "foo", [{integer, 1, 1}]}], "method call one arg"),

  assert_parse("foo(1, 2)",
    [{call, 1, "foo", [{integer, 1, 1}, {integer, 1, 2}]}],
    "method call multiple args"),

  % 式を引数として
  assert_parse("foo(1 + 2)",
    [{call, 1, "foo", [{binary_op, 1, '+', {integer, 1, 1}, {integer, 1, 2}}]}],
    "method call with expression arg"),
  ok.

test_assignments() ->
  assert_parse("x = 10",
    [{assign, 1, {var, 1, "x"}, {integer, 1, 10}}],
    "simple assignment"),

  assert_parse("y = x + 1",
    [{assign, 1, {var, 1, "y"},
      {binary_op, 1, '+', {identifier, 1, "x"}, {integer, 1, 1}}}],
    "assignment with expression"),

  assert_parse("result = foo(42)",
    [{assign, 1, {var, 1, "result"}, {call, 1, "foo", [{integer, 1, 42}]}}],
    "assignment with method call"),
  ok.

test_method_definitions() ->
  % 引数なしのメソッド
  assert_parse_ok("def hello\nend", "method def no params no body"),
  assert_parse_ok("def hello\n  42\nend", "method def no params with body"),

  % 引数ありのメソッド
  assert_parse_ok("def add(x, y)\n  x + y\nend", "method def with params"),
  assert_parse_ok("def greet(name)\n  \"Hello\"\nend", "method def one param"),
  ok.

test_if_statements() ->
  % 単純なif
  assert_parse_ok("if true\n  42\nend", "simple if"),

  % if-else
  assert_parse_ok("if x == 10\n  1\nelse\n  2\nend", "if-else"),

  % if-elsif-else
  assert_parse_ok("if x == 1\n  1\nelsif x == 2\n  2\nelse\n  3\nend", "if-elsif-else"),
  ok.

test_complex_expressions() ->
  % メソッド定義の中の演算（セミコロンで区切る）
  assert_parse_ok("def calc\n  x = 10; y = 20; x + y\nend",
    "method with multiple statements"),

  % ネストしたif文
  assert_parse_ok("if x > 0\n  if y > 0\n    1\n  end\nend",
    "nested if statements"),

  % 複数のステートメント
  assert_parse_ok("x = 1; y = 2; x + y",
    "multiple statements with semicolon"),
  ok.
