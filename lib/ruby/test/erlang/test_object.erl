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

  % メタプログラミング基盤のテスト
  test_define_class_method(),
  test_lookup_method(),
  test_lookup_method_not_found(),
  test_get_class_methods(),
  test_method_cache(),

  % アクセサメソッドのテスト
  test_attr_reader(),
  test_attr_writer(),
  test_attr_accessor(),

  % 動的メソッド定義のテスト
  test_define_method(),
  test_method_send(),
  test_set_method_missing(),
  test_has_method_missing(),

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

%% ========================================
%% メタプログラミング基盤のテスト
%% ========================================

%% クラスメソッドを定義
test_define_class_method() ->
  MethodDef = #{
    name => greet,
    params => [],
    body => "Hello",
    closure_env => nil
  },
  ok = ruby_object_server:define_class_method('TestClass1', greet, MethodDef),
  io:format("  [PASS] define class method~n"),
  ok.

%% メソッドを検索
test_lookup_method() ->
  MethodDef = #{
    name => hello,
    params => [],
    body => "World",
    closure_env => nil
  },
  ruby_object_server:define_class_method('TestClass2', hello, MethodDef),
  {ok, Found} = ruby_object_server:lookup_method('TestClass2', hello),
  #{name := hello} = Found,
  io:format("  [PASS] lookup method~n"),
  ok.

%% 存在しないメソッドを検索
test_lookup_method_not_found() ->
  Result = ruby_object_server:lookup_method('NonExistentClass', nonexistent),
  assert_equal(not_found, Result, "lookup method not found"),
  ok.

%% クラスの全メソッドを取得
test_get_class_methods() ->
  Method1 = #{name => m1, params => [], body => nil, closure_env => nil},
  Method2 = #{name => m2, params => [], body => nil, closure_env => nil},
  ruby_object_server:define_class_method('TestClass3', m1, Method1),
  ruby_object_server:define_class_method('TestClass3', m2, Method2),
  {ok, Methods} = ruby_object_server:get_class_methods('TestClass3'),
  assert_equal(2, maps:size(Methods), "get class methods"),
  ok.

%% メソッドキャッシュの動作
test_method_cache() ->
  MethodDef = #{name => cached, params => [], body => nil, closure_env => nil},
  ruby_object_server:define_class_method('TestClass4', cached, MethodDef),
  % 1回目の検索（キャッシュなし）
  {ok, _} = ruby_object_server:lookup_method('TestClass4', cached),
  % 2回目の検索（キャッシュから）
  {ok, _} = ruby_object_server:lookup_method('TestClass4', cached),
  io:format("  [PASS] method cache~n"),
  ok.

%% ========================================
%% アクセサメソッドのテスト
%% ========================================

%% attr_reader
test_attr_reader() ->
  ruby_object_server:attr_reader('ReaderClass', [name, age]),
  {ok, Methods} = ruby_object_server:get_class_methods('ReaderClass'),
  assert_equal(true, maps:is_key(name, Methods), "attr_reader creates getter - name"),
  assert_equal(true, maps:is_key(age, Methods), "attr_reader creates getter - age"),
  io:format("  [PASS] attr_reader~n"),
  ok.

%% attr_writer
test_attr_writer() ->
  ruby_object_server:attr_writer('WriterClass', [name, age]),
  {ok, Methods} = ruby_object_server:get_class_methods('WriterClass'),
  NameSetter = list_to_atom("name="),
  AgeSetter = list_to_atom("age="),
  assert_equal(true, maps:is_key(NameSetter, Methods), "attr_writer creates setter - name="),
  assert_equal(true, maps:is_key(AgeSetter, Methods), "attr_writer creates setter - age="),
  io:format("  [PASS] attr_writer~n"),
  ok.

%% attr_accessor
test_attr_accessor() ->
  ruby_object_server:attr_accessor('AccessorClass', [title, price]),
  {ok, Methods} = ruby_object_server:get_class_methods('AccessorClass'),
  TitleSetter = list_to_atom("title="),
  PriceSetter = list_to_atom("price="),
  assert_equal(4, maps:size(Methods), "attr_accessor creates 4 methods"),
  assert_equal(true, maps:is_key(title, Methods), "attr_accessor creates getter - title"),
  assert_equal(true, maps:is_key(TitleSetter, Methods), "attr_accessor creates setter - title="),
  assert_equal(true, maps:is_key(price, Methods), "attr_accessor creates getter - price"),
  assert_equal(true, maps:is_key(PriceSetter, Methods), "attr_accessor creates setter - price="),
  io:format("  [PASS] attr_accessor~n"),
  ok.

%% ========================================
%% 動的メソッド定義のテスト
%% ========================================

%% define_method
test_define_method() ->
  ruby_object_server:define_method('DynamicClass', add, [a, b], {add_op, a, b}),
  {ok, Method} = ruby_object_server:lookup_method('DynamicClass', add),
  #{name := add, params := [a, b]} = Method,
  io:format("  [PASS] define_method~n"),
  ok.

%% method_send
test_method_send() ->
  MethodDef = #{name => test_send, params => [], body => "result", closure_env => nil},
  ruby_object_server:define_class_method('SendClass', test_send, MethodDef),
  {ok, Obj} = ruby_object_server:new_instance('SendClass'),
  {ok, nil, _} = ruby_object_server:method_send(Obj, test_send, []),
  io:format("  [PASS] method_send~n"),
  ok.

%% set_method_missing
test_set_method_missing() ->
  Handler = #{name => method_missing, params => [name, args], body => nil, closure_env => nil},
  ok = ruby_object_server:set_method_missing('MissingClass', method_missing, Handler),
  io:format("  [PASS] set_method_missing~n"),
  ok.

%% has_method_missing
test_has_method_missing() ->
  Handler = #{name => method_missing, params => [], body => nil, closure_env => nil},
  ruby_object_server:set_method_missing('CheckClass', method_missing, Handler),
  assert_equal(true, ruby_object_server:has_method_missing('CheckClass'), "has_method_missing returns true"),
  assert_equal(false, ruby_object_server:has_method_missing('NoHandlerClass'), "has_method_missing returns false"),
  ok.
