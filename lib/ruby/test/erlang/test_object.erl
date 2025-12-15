-module(test_object).
-export([test/0]).

test() ->
  io:format("~n=== Running Object System Tests ===~n"),

  % rubyアプリケーションを起動（ruby_object_serverを含む）
  application:ensure_all_started(ruby),

  % オブジェクトインスタンスのテスト
  test_new_instance(),
  test_new_instance_with_vars(),
  test_get_class(),
  test_get_object_id(),
  test_object_id_uniqueness(),

  % インスタンス変数のテスト
  test_set_instance_var(),
  test_get_instance_var(),
  test_get_instance_var_not_found(),
  test_get_all_instance_vars(),
  test_multiple_instance_vars(),
  test_update_instance_var(),

  % インスタンスチェックのテスト
  test_is_instance_of_true(),
  test_is_instance_of_false(),
  test_is_instance_of_non_object(),

  % 基底クラスのテスト
  test_object_class(),
  test_class_class(),
  test_module_class(),

  % エラーケースのテスト
  test_get_instance_var_non_object(),
  test_set_instance_var_non_object(),
  test_get_class_non_object(),
  test_get_object_id_non_object(),

  io:format("~n=== All Object System Tests Passed ===~n"),
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

%% ========================================
%% オブジェクトインスタンスのテスト
%% ========================================

%% 新しいオブジェクトインスタンスの作成
test_new_instance() ->
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  #{type := object, class := 'MyClass'} = Obj,
  io:format("  [PASS] new instance creates object~n"),
  ok.

%% 初期インスタンス変数付きでオブジェクトを作成
test_new_instance_with_vars() ->
  InitVars = #{'@x' => 10, '@y' => 20},
  {ok, Obj} = ruby_object_server:new_instance('TestClass', InitVars),
  {ok, Vars} = ruby_object_server:get_instance_vars(Obj),
  assert_equal(InitVars, Vars, "new instance with initial vars"),
  ok.

%% オブジェクトのクラスを取得
test_get_class() ->
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  {ok, Class} = ruby_object_server:get_class(Obj),
  assert_equal('MyClass', Class, "get class returns correct class name"),
  ok.

%% オブジェクトIDを取得
test_get_object_id() ->
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  {ok, Id} = ruby_object_server:get_object_id(Obj),
  assert_equal(true, is_integer(Id), "get object id returns integer"),
  ok.

%% オブジェクトIDの一意性
test_object_id_uniqueness() ->
  {ok, Obj1} = ruby_object_server:new_instance('Class1'),
  {ok, Obj2} = ruby_object_server:new_instance('Class2'),
  {ok, Id1} = ruby_object_server:get_object_id(Obj1),
  {ok, Id2} = ruby_object_server:get_object_id(Obj2),
  assert_equal(false, Id1 =:= Id2, "object IDs are unique"),
  ok.

%% ========================================
%% インスタンス変数のテスト
%% ========================================

%% インスタンス変数を設定
test_set_instance_var() ->
  {ok, Obj1} = ruby_object_server:new_instance('MyClass'),
  Obj2 = ruby_object_server:set_instance_var(Obj1, '@name', "Alice"),
  {ok, Value} = ruby_object_server:get_instance_var(Obj2, '@name'),
  assert_equal("Alice", Value, "set instance var"),
  ok.

%% インスタンス変数を取得
test_get_instance_var() ->
  {ok, Obj1} = ruby_object_server:new_instance('MyClass'),
  Obj2 = ruby_object_server:set_instance_var(Obj1, '@x', 42),
  {ok, Value} = ruby_object_server:get_instance_var(Obj2, '@x'),
  assert_equal(42, Value, "get instance var"),
  ok.

%% 存在しないインスタンス変数を取得
test_get_instance_var_not_found() ->
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  Result = ruby_object_server:get_instance_var(Obj, '@nonexistent'),
  assert_equal({error, not_found}, Result, "get nonexistent instance var returns error"),
  ok.

%% すべてのインスタンス変数を取得
test_get_all_instance_vars() ->
  {ok, Obj1} = ruby_object_server:new_instance('MyClass'),
  Obj2 = ruby_object_server:set_instance_var(Obj1, '@x', 10),
  Obj3 = ruby_object_server:set_instance_var(Obj2, '@y', 20),
  {ok, Vars} = ruby_object_server:get_instance_vars(Obj3),
  Expected = #{'@x' => 10, '@y' => 20},
  assert_equal(Expected, Vars, "get all instance vars"),
  ok.

%% 複数のインスタンス変数
test_multiple_instance_vars() ->
  {ok, Obj1} = ruby_object_server:new_instance('Person'),
  Obj2 = ruby_object_server:set_instance_var(Obj1, '@name', "Bob"),
  Obj3 = ruby_object_server:set_instance_var(Obj2, '@age', 30),
  Obj4 = ruby_object_server:set_instance_var(Obj3, '@city', "Tokyo"),

  {ok, Name} = ruby_object_server:get_instance_var(Obj4, '@name'),
  {ok, Age} = ruby_object_server:get_instance_var(Obj4, '@age'),
  {ok, City} = ruby_object_server:get_instance_var(Obj4, '@city'),

  assert_equal("Bob", Name, "multiple vars - name"),
  assert_equal(30, Age, "multiple vars - age"),
  assert_equal("Tokyo", City, "multiple vars - city"),
  ok.

%% インスタンス変数の更新
test_update_instance_var() ->
  {ok, Obj1} = ruby_object_server:new_instance('Counter'),
  Obj2 = ruby_object_server:set_instance_var(Obj1, '@count', 0),
  Obj3 = ruby_object_server:set_instance_var(Obj2, '@count', 1),
  Obj4 = ruby_object_server:set_instance_var(Obj3, '@count', 2),

  {ok, Count} = ruby_object_server:get_instance_var(Obj4, '@count'),
  assert_equal(2, Count, "update instance var"),
  ok.

%% ========================================
%% インスタンスチェックのテスト
%% ========================================

%% is_instance_of - 正しいクラス
test_is_instance_of_true() ->
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  Result = ruby_object_server:is_instance_of(Obj, 'MyClass'),
  assert_equal(true, Result, "is_instance_of returns true for correct class"),
  ok.

%% is_instance_of - 間違ったクラス
test_is_instance_of_false() ->
  {ok, Obj} = ruby_object_server:new_instance('MyClass'),
  Result = ruby_object_server:is_instance_of(Obj, 'OtherClass'),
  assert_equal(false, Result, "is_instance_of returns false for wrong class"),
  ok.

%% is_instance_of - オブジェクトでない値
test_is_instance_of_non_object() ->
  Result = ruby_object_server:is_instance_of(42, 'Integer'),
  assert_equal(false, Result, "is_instance_of returns false for non-object"),
  ok.

%% ========================================
%% 基底クラスのテスト
%% ========================================

%% Objectクラスの定義
test_object_class() ->
  ObjectClass = ruby_object_server:object_class(),
  #{type := class, name := 'Object', superclass := nil, id := 0} = ObjectClass,
  io:format("  [PASS] Object class definition~n"),
  ok.

%% Classクラスの定義
test_class_class() ->
  ClassClass = ruby_object_server:class_class(),
  #{type := class, name := 'Class', superclass := 'Object', id := 1} = ClassClass,
  io:format("  [PASS] Class class definition~n"),
  ok.

%% Moduleクラスの定義
test_module_class() ->
  ModuleClass = ruby_object_server:module_class(),
  #{type := module, name := 'Module', id := 2} = ModuleClass,
  io:format("  [PASS] Module class definition~n"),
  ok.

%% ========================================
%% エラーケースのテスト
%% ========================================

%% オブジェクトでない値からインスタンス変数を取得
test_get_instance_var_non_object() ->
  Result = ruby_object_server:get_instance_var(42, '@x'),
  assert_equal({error, not_an_object}, Result, "get instance var from non-object"),
  ok.

%% オブジェクトでない値にインスタンス変数を設定
test_set_instance_var_non_object() ->
  Result = ruby_object_server:set_instance_var(42, '@x', 10),
  assert_equal(42, Result, "set instance var on non-object returns original value"),
  ok.

%% オブジェクトでない値のクラスを取得
test_get_class_non_object() ->
  Result = ruby_object_server:get_class(42),
  assert_equal({error, not_an_object}, Result, "get class from non-object"),
  ok.

%% オブジェクトでない値のIDを取得
test_get_object_id_non_object() ->
  Result = ruby_object_server:get_object_id("string"),
  assert_equal({error, not_an_object}, Result, "get object id from non-object"),
  ok.
