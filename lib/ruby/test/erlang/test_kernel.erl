-module(test_kernel).
-export([test/0]).

test() ->
  io:format("~n=== Running Kernel Module Tests ===~n"),

  % Start ruby application for object system tests
  application:ensure_all_started(ruby),

  % Run tests
  test_output_methods(),
  test_type_conversion(),
  test_object_inspection(),
  test_file_loading(),
  test_exception_methods(),

  io:format("~n=== All Kernel Module Tests Passed ===~n"),
  ok.

%% Test helper
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

assert_true(Actual, TestName) ->
  assert_equal(true, Actual, TestName).

assert_false(Actual, TestName) ->
  assert_equal(false, Actual, TestName).

%%====================================================================
%% Output methods tests
%%====================================================================

test_output_methods() ->
  io:format("~nTesting output methods:~n"),

  % Test puts with integer
  Result1 = ruby_kernel:puts(42),
  assert_equal(nil, Result1, "puts returns nil"),

  % Test puts with string
  Result2 = ruby_kernel:puts("Hello"),
  assert_equal(nil, Result2, "puts with string returns nil"),

  % Test puts with binary
  Result3 = ruby_kernel:puts(<<"World">>),
  assert_equal(nil, Result3, "puts with binary returns nil"),

  % Test puts with nil
  Result4 = ruby_kernel:puts(nil),
  assert_equal(nil, Result4, "puts with nil returns nil"),

  % Test puts with true/false
  Result5 = ruby_kernel:puts(true),
  assert_equal(nil, Result5, "puts with true returns nil"),
  Result6 = ruby_kernel:puts(false),
  assert_equal(nil, Result6, "puts with false returns nil"),

  % Test print
  Result7 = ruby_kernel:print(42),
  assert_equal(nil, Result7, "print returns nil"),

  % Test p (returns the value itself)
  Result8 = ruby_kernel:p(42),
  assert_equal(42, Result8, "p returns the value"),

  Result9 = ruby_kernel:p("test"),
  assert_equal("test", Result9, "p with string returns the string"),

  % Test printf
  Result10 = ruby_kernel:printf("Number: ~p~n", [42]),
  assert_equal(nil, Result10, "printf returns nil"),

  ok.

%%====================================================================
%% Type conversion tests
%%====================================================================

test_type_conversion() ->
  io:format("~nTesting type conversion methods:~n"),

  % Test Integer conversion
  {ok, Int1} = ruby_kernel:to_integer("42"),
  assert_equal(42, Int1, "String to integer"),

  {ok, Int2} = ruby_kernel:to_integer(42),
  assert_equal(42, Int2, "Integer to integer"),

  {ok, Int3} = ruby_kernel:to_integer(42.7),
  assert_equal(42, Int3, "Float to integer"),

  % Test Float conversion
  {ok, Float1} = ruby_kernel:to_float("3.14"),
  assert_true(abs(Float1 - 3.14) < 0.01, "String to float"),

  {ok, Float2} = ruby_kernel:to_float(42),
  assert_equal(42.0, Float2, "Integer to float"),

  {ok, Float3} = ruby_kernel:to_float(3.14),
  assert_equal(3.14, Float3, "Float to float"),

  % Test String conversion
  {ok, Str1} = ruby_kernel:to_string(42),
  assert_equal("42", Str1, "Integer to string"),

  {ok, Str2} = ruby_kernel:to_string("hello"),
  assert_equal("hello", Str2, "String to string"),

  % Test Array conversion
  Arr1 = ruby_kernel:to_array([1, 2, 3]),
  assert_equal([1, 2, 3], Arr1, "List to array"),

  Arr2 = ruby_kernel:to_array(42),
  assert_equal([42], Arr2, "Non-list to array"),

  ok.

%%====================================================================
%% Object inspection tests
%%====================================================================

test_object_inspection() ->
  io:format("~nTesting object inspection methods:~n"),

  % Test get_class with primitives
  Class1 = ruby_kernel:get_class(42),
  assert_equal('Integer', Class1, "Integer class"),

  Class2 = ruby_kernel:get_class(3.14),
  assert_equal('Float', Class2, "Float class"),

  Class3 = ruby_kernel:get_class(<<"string">>),
  assert_equal('String', Class3, "String class (binary)"),

  Class4 = ruby_kernel:get_class("string"),
  assert_equal('String', Class4, "String class (list)"),

  Class5 = ruby_kernel:get_class(nil),
  assert_equal('NilClass', Class5, "NilClass"),

  Class6 = ruby_kernel:get_class(true),
  assert_equal('TrueClass', Class6, "TrueClass"),

  Class7 = ruby_kernel:get_class(false),
  assert_equal('FalseClass', Class7, "FalseClass"),

  Class8 = ruby_kernel:get_class([1, 2, 3]),
  assert_equal('Array', Class8, "Array class"),

  % Test get_class with objects
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  Class9 = ruby_kernel:get_class(Obj),
  assert_equal('MyClass', Class9, "Object class"),

  % Test is_a? with primitives
  IsInt = ruby_kernel:is_a(42, 'Integer'),
  assert_true(IsInt, "42 is_a? Integer"),

  IsNotFloat = ruby_kernel:is_a(42, 'Float'),
  assert_false(IsNotFloat, "42 is_a? Float - false"),

  % Test is_a? with objects and inheritance
  ok = ruby_object_server:register_class('Animal', nil),
  ok = ruby_object_server:register_class('Dog', 'Animal'),
  {ok, DogObj} = ruby_object_server:new_instance('Dog'),

  IsDog = ruby_kernel:is_a(DogObj, 'Dog'),
  assert_true(IsDog, "Dog instance is_a? Dog"),

  IsAnimal = ruby_kernel:is_a(DogObj, 'Animal'),
  assert_true(IsAnimal, "Dog instance is_a? Animal (parent)"),

  % Test kind_of? (alias for is_a?)
  KindOfDog = ruby_kernel:kind_of(DogObj, 'Dog'),
  assert_true(KindOfDog, "Dog instance kind_of? Dog"),

  % Test respond_to?
  ok = ruby_object_server:define_class_method(
    'Dog',
    bark,
    #{name => bark, params => [], body => "Woof!", closure_env => nil}
  ),

  RespondsTo = ruby_kernel:respond_to(DogObj, bark),
  assert_true(RespondsTo, "Dog responds_to? bark"),

  NotRespondsTo = ruby_kernel:respond_to(DogObj, meow),
  assert_false(NotRespondsTo, "Dog responds_to? meow - false"),

  ok.

%%====================================================================
%% File loading tests
%%====================================================================

test_file_loading() ->
  io:format("~nTesting file loading methods:~n"),

  % Test require with non-existent file
  Result1 = ruby_kernel:require("nonexistent_file"),
  assert_false(Result1, "require non-existent file returns false"),

  % Test load with non-existent file
  Result2 = ruby_kernel:load("nonexistent_file"),
  assert_false(Result2, "load non-existent file returns false"),

  % Test require_relative
  Result3 = ruby_kernel:require_relative("nonexistent_file"),
  assert_false(Result3, "require_relative non-existent file returns false"),

  % Note: Testing with actual files would require creating test fixtures
  % For now, we just test the basic behavior with non-existent files

  ok.

%%====================================================================
%% Exception methods tests
%%====================================================================

test_exception_methods() ->
  io:format("~nTesting exception methods:~n"),

  % Test raise
  Result1 = ruby_kernel:raise("Error message"),
  assert_equal({error, {exception, "Error message"}}, Result1, "raise with message"),

  Result2 = ruby_kernel:raise('RuntimeError', "Error message"),
  assert_equal({error, {exception, 'RuntimeError', "Error message"}}, Result2, "raise with class and message"),

  % Test fail (alias for raise)
  Result3 = ruby_kernel:fail("Error message"),
  assert_equal({error, {exception, "Error message"}}, Result3, "fail with message"),

  Result4 = ruby_kernel:fail('RuntimeError', "Error message"),
  assert_equal({error, {exception, 'RuntimeError', "Error message"}}, Result4, "fail with class and message"),

  % Test throw and catch
  CaughtValue = ruby_kernel:catch_throw(fun() -> ruby_kernel:throw(42) end),
  assert_equal(42, CaughtValue, "catch_throw catches thrown value"),

  CaughtValue2 = ruby_kernel:catch_throw(fun() -> ruby_kernel:throw(symbol, "value") end),
  assert_equal({symbol, "value"}, CaughtValue2, "catch_throw catches thrown tagged value"),

  % Test normal return (no throw)
  NormalValue = ruby_kernel:catch_throw(fun() -> 99 end),
  assert_equal(99, NormalValue, "catch_throw returns normal value when no throw"),

  ok.
