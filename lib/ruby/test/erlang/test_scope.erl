-module(test_scope).
-export([test/0]).

test() ->
  io:format("~n=== Running Scope Tests ===~n"),

  % テスト実行
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
