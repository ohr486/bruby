-module(test_tokenizer).
-export([test/0]).

test() ->
  io:format("~n=== Running Tokenizer Tests ===~n"),

  % テスト実行
  test_empty_string(),
  test_whitespace(),
  test_comments(),
  test_identifiers(),
  test_keywords(),
  test_integers(),
  test_strings(),
  test_operators(),
  test_delimiters(),
  test_complex_expression(),

  io:format("~n=== All Tokenizer Tests Passed ===~n"),
  ok.

%% テストヘルパー
assert_equal(Expected, Actual, TestName) ->
  case Expected =:= Actual of
    true ->
      io:format("  [PASS] ~s~n", [TestName]);
    false ->
      io:format("  [FAIL] ~s~n", [TestName]),
      io:format("    Expected: ~p~n", [Expected]),
      io:format("    Actual:   ~p~n", [Actual]),
      erlang:error({assertion_failed, TestName})
  end.

%% 個別テスト

test_empty_string() ->
  {ok, Tokens, _} = ruby_tokenizer:tokenize(""),
  assert_equal([], Tokens, "empty string"),
  ok.

test_whitespace() ->
  {ok, Tokens, _} = ruby_tokenizer:tokenize("   \t  \n  "),
  assert_equal([], Tokens, "whitespace only"),
  ok.

test_comments() ->
  {ok, Tokens, _} = ruby_tokenizer:tokenize("# this is a comment"),
  assert_equal([], Tokens, "comment only"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("foo # comment\nbar"),
  assert_equal([
    {tIDENTIFIER, 1, "foo"},
    {tIDENTIFIER, 2, "bar"}
  ], Tokens2, "identifier with comment"),
  ok.

test_identifiers() ->
  {ok, Tokens, _} = ruby_tokenizer:tokenize("foo"),
  assert_equal([{tIDENTIFIER, 1, "foo"}], Tokens, "simple identifier"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("foo_bar"),
  assert_equal([{tIDENTIFIER, 1, "foo_bar"}], Tokens2, "identifier with underscore"),

  {ok, Tokens3, _} = ruby_tokenizer:tokenize("foo123"),
  assert_equal([{tIDENTIFIER, 1, "foo123"}], Tokens3, "identifier with numbers"),

  {ok, Tokens4, _} = ruby_tokenizer:tokenize("foo?"),
  assert_equal([{tIDENTIFIER, 1, "foo?"}], Tokens4, "identifier with question mark"),

  {ok, Tokens5, _} = ruby_tokenizer:tokenize("foo!"),
  assert_equal([{tIDENTIFIER, 1, "foo!"}], Tokens5, "identifier with exclamation"),
  ok.

test_keywords() ->
  {ok, Tokens1, _} = ruby_tokenizer:tokenize("def"),
  assert_equal([{tDEF, 1}], Tokens1, "keyword: def"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("end"),
  assert_equal([{tEND, 1}], Tokens2, "keyword: end"),

  {ok, Tokens3, _} = ruby_tokenizer:tokenize("class"),
  assert_equal([{tCLASS, 1}], Tokens3, "keyword: class"),

  {ok, Tokens4, _} = ruby_tokenizer:tokenize("if"),
  assert_equal([{tIF, 1}], Tokens4, "keyword: if"),

  {ok, Tokens5, _} = ruby_tokenizer:tokenize("true"),
  assert_equal([{tTRUE, 1}], Tokens5, "keyword: true"),

  {ok, Tokens6, _} = ruby_tokenizer:tokenize("false"),
  assert_equal([{tFALSE, 1}], Tokens6, "keyword: false"),

  {ok, Tokens7, _} = ruby_tokenizer:tokenize("nil"),
  assert_equal([{tNIL, 1}], Tokens7, "keyword: nil"),
  ok.

test_integers() ->
  {ok, Tokens, _} = ruby_tokenizer:tokenize("123"),
  assert_equal([{tINTEGER, 1, 123}], Tokens, "integer: 123"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("0"),
  assert_equal([{tINTEGER, 1, 0}], Tokens2, "integer: 0"),

  {ok, Tokens3, _} = ruby_tokenizer:tokenize("456789"),
  assert_equal([{tINTEGER, 1, 456789}], Tokens3, "integer: 456789"),
  ok.

test_strings() ->
  {ok, Tokens, _} = ruby_tokenizer:tokenize("\"hello\""),
  assert_equal([{tSTRING, 1, "hello"}], Tokens, "double quoted string"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("'world'"),
  assert_equal([{tSTRING, 1, "world"}], Tokens2, "single quoted string"),

  {ok, Tokens3, _} = ruby_tokenizer:tokenize("\"hello\\nworld\""),
  assert_equal([{tSTRING, 1, "hello\nworld"}], Tokens3, "string with newline escape"),

  {ok, Tokens4, _} = ruby_tokenizer:tokenize("\"hello\\tworld\""),
  assert_equal([{tSTRING, 1, "hello\tworld"}], Tokens4, "string with tab escape"),

  {ok, Tokens5, _} = ruby_tokenizer:tokenize("\"say \\\"hello\\\"\""),
  assert_equal([{tSTRING, 1, "say \"hello\""}], Tokens5, "string with escaped quotes"),
  ok.

test_operators() ->
  {ok, Tokens1, _} = ruby_tokenizer:tokenize("+"),
  assert_equal([{$+, 1}], Tokens1, "operator: +"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("-"),
  assert_equal([{$-, 1}], Tokens2, "operator: -"),

  {ok, Tokens3, _} = ruby_tokenizer:tokenize("*"),
  assert_equal([{$*, 1}], Tokens3, "operator: *"),

  {ok, Tokens4, _} = ruby_tokenizer:tokenize("/"),
  assert_equal([{$/, 1}], Tokens4, "operator: /"),

  {ok, Tokens5, _} = ruby_tokenizer:tokenize("=="),
  assert_equal([{tEQ, 1}], Tokens5, "operator: =="),

  {ok, Tokens6, _} = ruby_tokenizer:tokenize("!="),
  assert_equal([{tNE, 1}], Tokens6, "operator: !="),

  {ok, Tokens7, _} = ruby_tokenizer:tokenize("<="),
  assert_equal([{tLE, 1}], Tokens7, "operator: <="),

  {ok, Tokens8, _} = ruby_tokenizer:tokenize(">="),
  assert_equal([{tGE, 1}], Tokens8, "operator: >="),

  {ok, Tokens9, _} = ruby_tokenizer:tokenize("&&"),
  assert_equal([{tAND, 1}], Tokens9, "operator: &&"),

  {ok, Tokens10, _} = ruby_tokenizer:tokenize("||"),
  assert_equal([{tOR, 1}], Tokens10, "operator: ||"),
  ok.

test_delimiters() ->
  {ok, Tokens1, _} = ruby_tokenizer:tokenize("()"),
  assert_equal([{$(, 1}, {$), 1}], Tokens1, "parentheses"),

  {ok, Tokens2, _} = ruby_tokenizer:tokenize("[]"),
  assert_equal([{$[, 1}, {$], 1}], Tokens2, "brackets"),

  {ok, Tokens3, _} = ruby_tokenizer:tokenize("{}"),
  assert_equal([{${, 1}, {$}, 1}], Tokens3, "braces"),

  {ok, Tokens4, _} = ruby_tokenizer:tokenize(","),
  assert_equal([{$,, 1}], Tokens4, "comma"),

  {ok, Tokens5, _} = ruby_tokenizer:tokenize("."),
  assert_equal([{$., 1}], Tokens5, "dot"),

  {ok, Tokens6, _} = ruby_tokenizer:tokenize(":"),
  assert_equal([{$:, 1}], Tokens6, "colon"),

  {ok, Tokens7, _} = ruby_tokenizer:tokenize(";"),
  assert_equal([{$;, 1}], Tokens7, "semicolon"),
  ok.

test_complex_expression() ->
  % "def foo(x, y)\n  x + y\nend"
  {ok, Tokens, _} = ruby_tokenizer:tokenize("def foo(x, y)\n  x + y\nend"),
  Expected = [
    {tDEF, 1},
    {tIDENTIFIER, 1, "foo"},
    {$(, 1},
    {tIDENTIFIER, 1, "x"},
    {$,, 1},
    {tIDENTIFIER, 1, "y"},
    {$), 1},
    {tIDENTIFIER, 2, "x"},
    {$+, 2},
    {tIDENTIFIER, 2, "y"},
    {tEND, 3}
  ],
  assert_equal(Expected, Tokens, "complex expression: method definition"),

  % "if x == 10\n  true\nelse\n  false\nend"
  {ok, Tokens2, _} = ruby_tokenizer:tokenize("if x == 10\n  true\nelse\n  false\nend"),
  Expected2 = [
    {tIF, 1},
    {tIDENTIFIER, 1, "x"},
    {tEQ, 1},
    {tINTEGER, 1, 10},
    {tTRUE, 2},
    {tELSE, 3},
    {tFALSE, 4},
    {tEND, 5}
  ],
  assert_equal(Expected2, Tokens2, "complex expression: if-else"),
  ok.
