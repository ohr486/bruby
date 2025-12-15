-module(test_scope).
-export([test/0]).

test() ->
  io:format("~n=== Running Scope Tests ===~n"),

  % 変数スコープのテスト
  test_new_scope(),
  test_new_scope_with_parent(),
  test_bind_and_lookup(),
  test_lookup_in_parent(),
  test_lookup_not_found(),
  test_get_bindings(),
  test_set_bindings(),
  test_get_parent(),
  test_scope_stack_push(),
  test_scope_stack_pop(),
  test_scope_stack_current(),
  test_scope_chain(),
  test_shadowing(),

  % 名前空間のテスト
  test_new_namespace(),
  test_new_namespace_with_parent(),
  test_new_namespace_with_name(),
  test_bind_constant(),
  test_lookup_constant(),
  test_lookup_constant_in_parent(),
  test_lookup_constant_not_found(),
  test_lookup_constant_path(),
  test_lookup_constant_path_nested(),
  test_get_constants(),
  test_nesting(),

  io:format("~n=== All Scope Tests Passed ===~n"),
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

%% 新しいスコープの作成
test_new_scope() ->
  Scope = ruby_scope:new(),
  assert_equal(#{}, ruby_scope:get_bindings(Scope), "new scope has empty bindings"),
  assert_equal(nil, ruby_scope:get_parent(Scope), "new scope has no parent"),
  ok.

%% 親スコープを持つスコープの作成
test_new_scope_with_parent() ->
  ParentScope = ruby_scope:new(),
  ChildScope = ruby_scope:new(ParentScope),
  assert_equal(#{}, ruby_scope:get_bindings(ChildScope), "child scope has empty bindings"),
  assert_equal(ParentScope, ruby_scope:get_parent(ChildScope), "child scope has parent"),
  ok.

%% 変数の束縛と検索
test_bind_and_lookup() ->
  Scope1 = ruby_scope:new(),
  Scope2 = ruby_scope:bind(x, 42, Scope1),
  {ok, Value} = ruby_scope:lookup(x, Scope2),
  assert_equal(42, Value, "lookup bound variable"),
  ok.

%% 親スコープでの変数検索
test_lookup_in_parent() ->
  ParentScope1 = ruby_scope:new(),
  ParentScope2 = ruby_scope:bind(x, 10, ParentScope1),
  ParentScope3 = ruby_scope:bind(y, 20, ParentScope2),

  ChildScope = ruby_scope:new(ParentScope3),

  {ok, ValueX} = ruby_scope:lookup(x, ChildScope),
  assert_equal(10, ValueX, "lookup variable in parent"),

  {ok, ValueY} = ruby_scope:lookup(y, ChildScope),
  assert_equal(20, ValueY, "lookup another variable in parent"),
  ok.

%% 変数が見つからない場合
test_lookup_not_found() ->
  Scope = ruby_scope:new(),
  Result = ruby_scope:lookup(undefined_var, Scope),
  assert_equal({error, undefined}, Result, "lookup undefined variable"),
  ok.

%% バインディングの取得
test_get_bindings() ->
  Scope1 = ruby_scope:new(),
  Scope2 = ruby_scope:bind(x, 10, Scope1),
  Scope3 = ruby_scope:bind(y, 20, Scope2),

  Bindings = ruby_scope:get_bindings(Scope3),
  assert_equal(#{x => 10, y => 20}, Bindings, "get bindings"),
  ok.

%% バインディングの設定
test_set_bindings() ->
  Scope1 = ruby_scope:new(),
  NewBindings = #{a => 100, b => 200},
  Scope2 = ruby_scope:set_bindings(NewBindings, Scope1),

  Bindings = ruby_scope:get_bindings(Scope2),
  assert_equal(NewBindings, Bindings, "set bindings"),
  ok.

%% 親スコープの取得
test_get_parent() ->
  ParentScope = ruby_scope:new(),
  ChildScope = ruby_scope:new(ParentScope),

  Parent = ruby_scope:get_parent(ChildScope),
  assert_equal(ParentScope, Parent, "get parent scope"),
  ok.

%% スコープスタックへのプッシュ
test_scope_stack_push() ->
  Scope1 = ruby_scope:new(),
  ScopeStack = #{
    current => Scope1,
    stack => []
  },

  Scope2 = ruby_scope:bind(x, 42, ruby_scope:new()),
  NewStack = ruby_scope:push(Scope2, ScopeStack),

  Current = ruby_scope:current(NewStack),
  assert_equal(Scope2, Current, "push updates current scope"),

  StackList = maps:get(stack, NewStack),
  assert_equal([Scope1], StackList, "push adds old scope to stack"),
  ok.

%% スコープスタックからのポップ
test_scope_stack_pop() ->
  Scope1 = ruby_scope:new(),
  Scope2 = ruby_scope:bind(x, 42, ruby_scope:new()),

  ScopeStack = #{
    current => Scope2,
    stack => [Scope1]
  },

  {ok, NewStack} = ruby_scope:pop(ScopeStack),
  Current = ruby_scope:current(NewStack),
  assert_equal(Scope1, Current, "pop restores previous scope"),

  StackList = maps:get(stack, NewStack),
  assert_equal([], StackList, "pop removes scope from stack"),

  % 空のスタックからのポップ
  EmptyStack = #{current => Scope1, stack => []},
  Result = ruby_scope:pop(EmptyStack),
  assert_equal({error, empty_stack}, Result, "pop from empty stack returns error"),
  ok.

%% 現在のスコープの取得
test_scope_stack_current() ->
  Scope = ruby_scope:bind(x, 100, ruby_scope:new()),
  ScopeStack = #{
    current => Scope,
    stack => []
  },

  Current = ruby_scope:current(ScopeStack),
  assert_equal(Scope, Current, "current returns current scope"),
  ok.

%% スコープチェーンのテスト
test_scope_chain() ->
  % 3階層のスコープを作成
  % グローバル -> 中間 -> ローカル
  GlobalScope1 = ruby_scope:new(),
  GlobalScope2 = ruby_scope:bind(global_var, 1, GlobalScope1),

  MiddleScope1 = ruby_scope:new(GlobalScope2),
  MiddleScope2 = ruby_scope:bind(middle_var, 2, MiddleScope1),

  LocalScope1 = ruby_scope:new(MiddleScope2),
  LocalScope2 = ruby_scope:bind(local_var, 3, LocalScope1),

  % ローカルスコープから各変数を検索
  {ok, GlobalVal} = ruby_scope:lookup(global_var, LocalScope2),
  assert_equal(1, GlobalVal, "lookup global variable from local scope"),

  {ok, MiddleVal} = ruby_scope:lookup(middle_var, LocalScope2),
  assert_equal(2, MiddleVal, "lookup middle variable from local scope"),

  {ok, LocalVal} = ruby_scope:lookup(local_var, LocalScope2),
  assert_equal(3, LocalVal, "lookup local variable from local scope"),
  ok.

%% 変数のシャドーイング（上書き）のテスト
test_shadowing() ->
  % 親スコープで変数を定義
  ParentScope1 = ruby_scope:new(),
  ParentScope2 = ruby_scope:bind(x, 100, ParentScope1),

  % 子スコープで同じ変数を定義（シャドーイング）
  ChildScope1 = ruby_scope:new(ParentScope2),
  ChildScope2 = ruby_scope:bind(x, 200, ChildScope1),

  % 子スコープでは子の値が見える
  {ok, ChildVal} = ruby_scope:lookup(x, ChildScope2),
  assert_equal(200, ChildVal, "child scope shadows parent variable"),

  % 親スコープでは親の値がそのまま
  {ok, ParentVal} = ruby_scope:lookup(x, ParentScope2),
  assert_equal(100, ParentVal, "parent scope retains original value"),
  ok.

%% ============================================================================
%% 名前空間のテスト
%% ============================================================================

%% 新しい名前空間の作成
test_new_namespace() ->
  Namespace = ruby_scope:new_namespace(),
  assert_equal(nil, maps:get(name, Namespace), "new namespace has no name"),
  assert_equal(#{}, ruby_scope:get_constants(Namespace), "new namespace has empty constants"),
  assert_equal(nil, maps:get(parent, Namespace), "new namespace has no parent"),
  assert_equal([], ruby_scope:get_nesting(Namespace), "new namespace has empty nesting"),
  ok.

%% 親名前空間を持つ名前空間の作成
test_new_namespace_with_parent() ->
  ParentNS = ruby_scope:new_namespace(),
  ChildNS = ruby_scope:new_namespace(ParentNS),
  assert_equal(nil, maps:get(name, ChildNS), "child namespace has no name"),
  assert_equal(#{}, ruby_scope:get_constants(ChildNS), "child namespace has empty constants"),
  assert_equal(ParentNS, maps:get(parent, ChildNS), "child namespace has parent"),
  ok.

%% 名前を持つ名前空間の作成
test_new_namespace_with_name() ->
  ParentNS = ruby_scope:new_namespace(),
  MyClassNS = ruby_scope:new_namespace('MyClass', ParentNS),
  assert_equal('MyClass', maps:get(name, MyClassNS), "namespace has name"),
  assert_equal(ParentNS, maps:get(parent, MyClassNS), "namespace has parent"),
  assert_equal(['MyClass'], ruby_scope:get_nesting(MyClassNS), "namespace has correct nesting"),
  ok.

%% 定数の束縛
test_bind_constant() ->
  NS1 = ruby_scope:new_namespace(),
  NS2 = ruby_scope:bind_constant('FOO', 42, NS1),
  Constants = ruby_scope:get_constants(NS2),
  assert_equal(#{'FOO' => 42}, Constants, "bind constant"),
  ok.

%% 定数の検索
test_lookup_constant() ->
  NS1 = ruby_scope:new_namespace(),
  NS2 = ruby_scope:bind_constant('PI', 3.14, NS1),
  {ok, Value} = ruby_scope:lookup_constant('PI', NS2),
  assert_equal(3.14, Value, "lookup constant"),
  ok.

%% 親名前空間での定数検索
test_lookup_constant_in_parent() ->
  ParentNS1 = ruby_scope:new_namespace(),
  ParentNS2 = ruby_scope:bind_constant('GLOBAL_CONST', 100, ParentNS1),

  ChildNS1 = ruby_scope:new_namespace('MyClass', ParentNS2),
  ChildNS2 = ruby_scope:bind_constant('LOCAL_CONST', 200, ChildNS1),

  {ok, GlobalVal} = ruby_scope:lookup_constant('GLOBAL_CONST', ChildNS2),
  assert_equal(100, GlobalVal, "lookup constant in parent namespace"),

  {ok, LocalVal} = ruby_scope:lookup_constant('LOCAL_CONST', ChildNS2),
  assert_equal(200, LocalVal, "lookup constant in current namespace"),
  ok.

%% 定数が見つからない場合
test_lookup_constant_not_found() ->
  NS = ruby_scope:new_namespace(),
  Result = ruby_scope:lookup_constant('UNDEFINED_CONST', NS),
  assert_equal({error, undefined}, Result, "lookup undefined constant"),
  ok.

%% 単純な定数パスの解決
test_lookup_constant_path() ->
  TopLevel = ruby_scope:new_namespace(),

  % A モジュールを定義
  ANS1 = ruby_scope:new_namespace('A', TopLevel),
  ANS2 = ruby_scope:bind_constant('VALUE', 42, ANS1),
  TopLevel2 = ruby_scope:bind_constant('A', ANS2, TopLevel),

  % A::VALUE を解決
  {ok, Value} = ruby_scope:lookup_constant_path(['A', 'VALUE'], TopLevel2),
  assert_equal(42, Value, "lookup constant path A::VALUE"),
  ok.

%% ネストした定数パスの解決
test_lookup_constant_path_nested() ->
  TopLevel = ruby_scope:new_namespace(),

  % A モジュールを定義
  ANS = ruby_scope:new_namespace('A', TopLevel),
  TopLevel2 = ruby_scope:bind_constant('A', ANS, TopLevel),

  % A::B モジュールを定義
  BNS = ruby_scope:new_namespace('B', ANS),
  ANS2 = ruby_scope:bind_constant('B', BNS, ANS),
  TopLevel3 = ruby_scope:bind_constant('A', ANS2, TopLevel2),

  % A::B::C 定数を定義
  BNS2 = ruby_scope:bind_constant('C', 999, BNS),
  ANS3 = ruby_scope:bind_constant('B', BNS2, ANS2),
  TopLevel4 = ruby_scope:bind_constant('A', ANS3, TopLevel3),

  % A::B::C を解決
  {ok, Value} = ruby_scope:lookup_constant_path(['A', 'B', 'C'], TopLevel4),
  assert_equal(999, Value, "lookup nested constant path A::B::C"),

  % 存在しないパス
  Result = ruby_scope:lookup_constant_path(['A', 'B', 'D'], TopLevel4),
  assert_equal({error, {undefined_constant, 'D'}}, Result, "lookup undefined nested constant"),
  ok.

%% 定数一覧の取得
test_get_constants() ->
  NS1 = ruby_scope:new_namespace(),
  NS2 = ruby_scope:bind_constant('FOO', 42, NS1),
  NS3 = ruby_scope:bind_constant('BAR', "hello", NS2),
  NS4 = ruby_scope:bind_constant('BAZ', true, NS3),

  Constants = ruby_scope:get_constants(NS4),
  assert_equal(#{'FOO' => 42, 'BAR' => "hello", 'BAZ' => true}, Constants, "get all constants"),
  ok.

%% ネスト情報のテスト
test_nesting() ->
  TopLevel = ruby_scope:new_namespace(),
  assert_equal([], ruby_scope:get_nesting(TopLevel), "top level has empty nesting"),

  % A モジュール
  ANS = ruby_scope:new_namespace('A', TopLevel),
  assert_equal(['A'], ruby_scope:get_nesting(ANS), "A module has [A] nesting"),

  % A::B モジュール
  BNS = ruby_scope:new_namespace('B', ANS),
  assert_equal(['A', 'B'], ruby_scope:get_nesting(BNS), "A::B module has [A, B] nesting"),

  % A::B::C モジュール
  CNS = ruby_scope:new_namespace('C', BNS),
  assert_equal(['A', 'B', 'C'], ruby_scope:get_nesting(CNS), "A::B::C module has [A, B, C] nesting"),

  % set_nesting のテスト
  NS = ruby_scope:new_namespace(),
  NS2 = ruby_scope:set_nesting(['Foo', 'Bar'], NS),
  assert_equal(['Foo', 'Bar'], ruby_scope:get_nesting(NS2), "set_nesting works"),
  ok.
