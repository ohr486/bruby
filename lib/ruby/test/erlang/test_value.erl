-module(test_value).
-export([test/0]).

test() ->
  io:format("~n=== Running Ruby Value Tests ===~n"),

  % 型チェックのテスト
  test_is_ruby_integer(),
  test_is_ruby_float(),
  test_is_ruby_number(),
  test_is_ruby_string(),
  test_is_ruby_symbol(),
  test_is_ruby_boolean(),
  test_is_ruby_nil(),
  test_is_ruby_object(),
  test_is_truthy(),

  % 型変換のテスト
  test_to_integer_from_integer(),
  test_to_integer_from_float(),
  test_to_integer_from_string(),
  test_to_integer_from_binary(),
  test_to_integer_from_boolean(),
  test_to_integer_error(),

  test_to_float_from_float(),
  test_to_float_from_integer(),
  test_to_float_from_string(),
  test_to_float_from_binary(),
  test_to_float_error(),

  test_to_string_from_string(),
  test_to_string_from_binary(),
  test_to_string_from_integer(),
  test_to_string_from_float(),
  test_to_string_from_boolean(),
  test_to_string_from_nil(),
  test_to_string_from_atom(),
  test_to_string_from_object(),
  test_to_string_from_proc(),

  test_to_symbol_from_atom(),
  test_to_symbol_from_string(),
  test_to_symbol_from_binary(),
  test_to_symbol_from_integer(),
  test_to_symbol_error(),

  test_to_boolean_from_values(),

  % 等価性チェックのテスト
  test_equal_integers(),
  test_equal_floats(),
  test_equal_numeric_coercion(),
  test_equal_strings(),
  test_equal_atoms(),
  test_equal_different_types(),

  test_eql_same_type_and_value(),
  test_eql_same_value_different_type(),
  test_eql_different_values(),

  test_identical_numbers(),
  test_identical_atoms(),
  test_identical_objects(),
  test_identical_strings(),

  % オブジェクト操作のテスト
  test_new_object(),
  test_get_object_class(),
  test_get_object_id(),

  io:format("~n=== All Ruby Value Tests Passed ===~n"),
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

%% ========================================
%% 型チェックのテスト
%% ========================================

test_is_ruby_integer() ->
  assert_equal(true, ruby_value:is_ruby_integer(42), "is_ruby_integer with integer"),
  assert_equal(true, ruby_value:is_ruby_integer(0), "is_ruby_integer with zero"),
  assert_equal(true, ruby_value:is_ruby_integer(-100), "is_ruby_integer with negative"),
  assert_equal(false, ruby_value:is_ruby_integer(3.14), "is_ruby_integer with float"),
  assert_equal(false, ruby_value:is_ruby_integer("123"), "is_ruby_integer with string"),
  ok.

test_is_ruby_float() ->
  assert_equal(true, ruby_value:is_ruby_float(3.14), "is_ruby_float with float"),
  assert_equal(true, ruby_value:is_ruby_float(0.0), "is_ruby_float with zero float"),
  assert_equal(false, ruby_value:is_ruby_float(42), "is_ruby_float with integer"),
  ok.

test_is_ruby_number() ->
  assert_equal(true, ruby_value:is_ruby_number(42), "is_ruby_number with integer"),
  assert_equal(true, ruby_value:is_ruby_number(3.14), "is_ruby_number with float"),
  assert_equal(false, ruby_value:is_ruby_number("123"), "is_ruby_number with string"),
  ok.

test_is_ruby_string() ->
  assert_equal(true, ruby_value:is_ruby_string("hello"), "is_ruby_string with string"),
  assert_equal(true, ruby_value:is_ruby_string(""), "is_ruby_string with empty string"),
  assert_equal(true, ruby_value:is_ruby_string(<<"binary">>), "is_ruby_string with binary"),
  assert_equal(false, ruby_value:is_ruby_string(42), "is_ruby_string with integer"),
  ok.

test_is_ruby_symbol() ->
  assert_equal(true, ruby_value:is_ruby_symbol(symbol), "is_ruby_symbol with atom"),
  assert_equal(true, ruby_value:is_ruby_symbol('Symbol'), "is_ruby_symbol with quoted atom"),
  assert_equal(false, ruby_value:is_ruby_symbol(true), "is_ruby_symbol with true"),
  assert_equal(false, ruby_value:is_ruby_symbol(false), "is_ruby_symbol with false"),
  assert_equal(false, ruby_value:is_ruby_symbol(nil), "is_ruby_symbol with nil"),
  ok.

test_is_ruby_boolean() ->
  assert_equal(true, ruby_value:is_ruby_boolean(true), "is_ruby_boolean with true"),
  assert_equal(true, ruby_value:is_ruby_boolean(false), "is_ruby_boolean with false"),
  assert_equal(false, ruby_value:is_ruby_boolean(nil), "is_ruby_boolean with nil"),
  assert_equal(false, ruby_value:is_ruby_boolean(1), "is_ruby_boolean with integer"),
  ok.

test_is_ruby_nil() ->
  assert_equal(true, ruby_value:is_ruby_nil(nil), "is_ruby_nil with nil"),
  assert_equal(false, ruby_value:is_ruby_nil(false), "is_ruby_nil with false"),
  assert_equal(false, ruby_value:is_ruby_nil(0), "is_ruby_nil with zero"),
  ok.

test_is_ruby_object() ->
  Obj = #{type => object, class => 'MyClass', id => 1, instance_vars => #{}},
  assert_equal(true, ruby_value:is_ruby_object(Obj), "is_ruby_object with object"),
  assert_equal(false, ruby_value:is_ruby_object(42), "is_ruby_object with integer"),
  assert_equal(false, ruby_value:is_ruby_object(#{}), "is_ruby_object with empty map"),
  ok.

test_is_truthy() ->
  assert_equal(true, ruby_value:is_truthy(true), "is_truthy with true"),
  assert_equal(true, ruby_value:is_truthy(42), "is_truthy with integer"),
  assert_equal(true, ruby_value:is_truthy(0), "is_truthy with zero"),
  assert_equal(true, ruby_value:is_truthy(""), "is_truthy with empty string"),
  assert_equal(true, ruby_value:is_truthy([]), "is_truthy with empty list"),
  assert_equal(false, ruby_value:is_truthy(false), "is_truthy with false"),
  assert_equal(false, ruby_value:is_truthy(nil), "is_truthy with nil"),
  ok.

%% ========================================
%% 型変換のテスト - to_integer
%% ========================================

test_to_integer_from_integer() ->
  assert_equal({ok, 42}, ruby_value:to_integer(42), "to_integer from integer"),
  assert_equal({ok, 0}, ruby_value:to_integer(0), "to_integer from zero"),
  assert_equal({ok, -100}, ruby_value:to_integer(-100), "to_integer from negative"),
  ok.

test_to_integer_from_float() ->
  assert_equal({ok, 3}, ruby_value:to_integer(3.14), "to_integer from float (truncate)"),
  assert_equal({ok, -5}, ruby_value:to_integer(-5.9), "to_integer from negative float"),
  ok.

test_to_integer_from_string() ->
  assert_equal({ok, 42}, ruby_value:to_integer("42"), "to_integer from string"),
  assert_equal({ok, -100}, ruby_value:to_integer("-100"), "to_integer from negative string"),
  ok.

test_to_integer_from_binary() ->
  assert_equal({ok, 123}, ruby_value:to_integer(<<"123">>), "to_integer from binary"),
  ok.

test_to_integer_from_boolean() ->
  assert_equal({ok, 1}, ruby_value:to_integer(true), "to_integer from true"),
  assert_equal({ok, 0}, ruby_value:to_integer(false), "to_integer from false"),
  assert_equal({ok, 0}, ruby_value:to_integer(nil), "to_integer from nil"),
  ok.

test_to_integer_error() ->
  assert_equal({error, cannot_convert}, ruby_value:to_integer("not_a_number"), "to_integer from invalid string"),
  assert_equal({error, cannot_convert}, ruby_value:to_integer(atom), "to_integer from atom"),
  ok.

%% ========================================
%% 型変換のテスト - to_float
%% ========================================

test_to_float_from_float() ->
  assert_equal({ok, 3.14}, ruby_value:to_float(3.14), "to_float from float"),
  ok.

test_to_float_from_integer() ->
  assert_equal({ok, 42.0}, ruby_value:to_float(42), "to_float from integer"),
  ok.

test_to_float_from_string() ->
  {ok, Result1} = ruby_value:to_float("3.14"),
  assert_equal(true, abs(Result1 - 3.14) < 0.0001, "to_float from float string"),
  {ok, Result2} = ruby_value:to_float("42"),
  assert_equal(true, abs(Result2 - 42.0) < 0.0001, "to_float from integer string"),
  ok.

test_to_float_from_binary() ->
  {ok, Result} = ruby_value:to_float(<<"3.14">>),
  assert_equal(true, abs(Result - 3.14) < 0.0001, "to_float from binary"),
  ok.

test_to_float_error() ->
  assert_equal({error, cannot_convert}, ruby_value:to_float("not_a_number"), "to_float from invalid string"),
  ok.

%% ========================================
%% 型変換のテスト - to_string
%% ========================================

test_to_string_from_string() ->
  assert_equal({ok, "hello"}, ruby_value:to_string("hello"), "to_string from string"),
  ok.

test_to_string_from_binary() ->
  assert_equal({ok, "world"}, ruby_value:to_string(<<"world">>), "to_string from binary"),
  ok.

test_to_string_from_integer() ->
  assert_equal({ok, "42"}, ruby_value:to_string(42), "to_string from integer"),
  assert_equal({ok, "-100"}, ruby_value:to_string(-100), "to_string from negative"),
  ok.

test_to_string_from_float() ->
  {ok, Result} = ruby_value:to_string(3.14),
  assert_equal(true, is_list(Result), "to_string from float returns string"),
  ok.

test_to_string_from_boolean() ->
  assert_equal({ok, "true"}, ruby_value:to_string(true), "to_string from true"),
  assert_equal({ok, "false"}, ruby_value:to_string(false), "to_string from false"),
  ok.

test_to_string_from_nil() ->
  assert_equal({ok, ""}, ruby_value:to_string(nil), "to_string from nil"),
  ok.

test_to_string_from_atom() ->
  assert_equal({ok, "symbol"}, ruby_value:to_string(symbol), "to_string from atom"),
  ok.

test_to_string_from_object() ->
  Obj = #{type => object, class => 'MyClass', id => 1, instance_vars => #{}},
  {ok, Result} = ruby_value:to_string(Obj),
  assert_equal(true, lists:prefix("#<MyClass>", Result), "to_string from object"),
  ok.

test_to_string_from_proc() ->
  Lambda = #{is_lambda => true, params => [], body => []},
  Proc = #{is_lambda => false, params => [], body => []},
  assert_equal({ok, "#<Proc(lambda)>"}, ruby_value:to_string(Lambda), "to_string from lambda"),
  assert_equal({ok, "#<Proc>"}, ruby_value:to_string(Proc), "to_string from proc"),
  ok.

%% ========================================
%% 型変換のテスト - to_symbol
%% ========================================

test_to_symbol_from_atom() ->
  assert_equal({ok, symbol}, ruby_value:to_symbol(symbol), "to_symbol from atom"),
  ok.

test_to_symbol_from_string() ->
  assert_equal({ok, hello}, ruby_value:to_symbol("hello"), "to_symbol from string"),
  ok.

test_to_symbol_from_binary() ->
  assert_equal({ok, world}, ruby_value:to_symbol(<<"world">>), "to_symbol from binary"),
  ok.

test_to_symbol_from_integer() ->
  {ok, Result} = ruby_value:to_symbol(42),
  assert_equal('42', Result, "to_symbol from integer"),
  ok.

test_to_symbol_error() ->
  assert_equal({error, cannot_convert}, ruby_value:to_symbol(3.14), "to_symbol from float"),
  ok.

%% ========================================
%% 型変換のテスト - to_boolean
%% ========================================

test_to_boolean_from_values() ->
  assert_equal({ok, false}, ruby_value:to_boolean(false), "to_boolean from false"),
  assert_equal({ok, false}, ruby_value:to_boolean(nil), "to_boolean from nil"),
  assert_equal({ok, true}, ruby_value:to_boolean(true), "to_boolean from true"),
  assert_equal({ok, true}, ruby_value:to_boolean(0), "to_boolean from zero"),
  assert_equal({ok, true}, ruby_value:to_boolean(""), "to_boolean from empty string"),
  assert_equal({ok, true}, ruby_value:to_boolean(42), "to_boolean from integer"),
  ok.

%% ========================================
%% 等価性チェックのテスト - equal (Ruby ==)
%% ========================================

test_equal_integers() ->
  assert_equal(true, ruby_value:equal(42, 42), "equal integers"),
  assert_equal(false, ruby_value:equal(42, 43), "unequal integers"),
  ok.

test_equal_floats() ->
  assert_equal(true, ruby_value:equal(3.14, 3.14), "equal floats"),
  assert_equal(false, ruby_value:equal(3.14, 3.15), "unequal floats"),
  ok.

test_equal_numeric_coercion() ->
  assert_equal(true, ruby_value:equal(42, 42.0), "integer equals float (coercion)"),
  assert_equal(true, ruby_value:equal(0, 0.0), "zero integer equals zero float"),
  ok.

test_equal_strings() ->
  assert_equal(true, ruby_value:equal("hello", "hello"), "equal strings"),
  assert_equal(false, ruby_value:equal("hello", "world"), "unequal strings"),
  ok.

test_equal_atoms() ->
  assert_equal(true, ruby_value:equal(true, true), "equal atoms (true)"),
  assert_equal(true, ruby_value:equal(nil, nil), "equal atoms (nil)"),
  assert_equal(false, ruby_value:equal(true, false), "unequal atoms"),
  ok.

test_equal_different_types() ->
  assert_equal(false, ruby_value:equal(42, "42"), "integer not equal to string"),
  assert_equal(false, ruby_value:equal(true, 1), "boolean not equal to integer"),
  ok.

%% ========================================
%% 等価性チェックのテスト - eql (Ruby eql?)
%% ========================================

test_eql_same_type_and_value() ->
  assert_equal(true, ruby_value:eql(42, 42), "eql same integers"),
  assert_equal(true, ruby_value:eql(3.14, 3.14), "eql same floats"),
  assert_equal(true, ruby_value:eql("hello", "hello"), "eql same strings"),
  ok.

test_eql_same_value_different_type() ->
  assert_equal(false, ruby_value:eql(42, 42.0), "eql integer and float with same value"),
  ok.

test_eql_different_values() ->
  assert_equal(false, ruby_value:eql(42, 43), "eql different integers"),
  assert_equal(false, ruby_value:eql("hello", "world"), "eql different strings"),
  ok.

%% ========================================
%% 等価性チェックのテスト - identical (Ruby equal?)
%% ========================================

test_identical_numbers() ->
  assert_equal(true, ruby_value:identical(42, 42), "identical integers"),
  assert_equal(true, ruby_value:identical(3.14, 3.14), "identical floats"),
  assert_equal(false, ruby_value:identical(42, 42.0), "not identical integer and float"),
  ok.

test_identical_atoms() ->
  assert_equal(true, ruby_value:identical(true, true), "identical atoms"),
  assert_equal(true, ruby_value:identical(symbol, symbol), "identical symbols"),
  ok.

test_identical_objects() ->
  Obj1 = #{type => object, id => 1, class => 'MyClass', instance_vars => #{}},
  Obj2 = #{type => object, id => 2, class => 'MyClass', instance_vars => #{}},
  Obj3 = #{type => object, id => 1, class => 'MyClass', instance_vars => #{}},
  assert_equal(true, ruby_value:identical(Obj1, Obj3), "identical objects (same ID)"),
  assert_equal(false, ruby_value:identical(Obj1, Obj2), "not identical objects (different ID)"),
  ok.

test_identical_strings() ->
  % Strings in Erlang are lists, so structural equality applies
  assert_equal(true, ruby_value:identical("hello", "hello"), "identical string values"),
  ok.

%% ========================================
%% オブジェクト操作のテスト
%% ========================================

test_new_object() ->
  Obj = ruby_value:new_object('TestClass', 123),
  #{type := object, class := 'TestClass', id := 123, instance_vars := Vars} = Obj,
  assert_equal(#{}, Vars, "new_object creates object with empty instance vars"),
  ok.

test_get_object_class() ->
  Obj = ruby_value:new_object('MyClass', 1),
  assert_equal({ok, 'MyClass'}, ruby_value:get_object_class(Obj), "get_object_class from object"),
  assert_equal({error, not_an_object}, ruby_value:get_object_class(42), "get_object_class from non-object"),
  ok.

test_get_object_id() ->
  Obj = ruby_value:new_object('MyClass', 456),
  assert_equal({ok, 456}, ruby_value:get_object_id(Obj), "get_object_id from object"),
  assert_equal({error, not_an_object}, ruby_value:get_object_id("string"), "get_object_id from non-object"),
  ok.
