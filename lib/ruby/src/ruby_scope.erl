%% @doc Rubyスコープ管理モジュール
%%
%% このモジュールはRubyの変数スコープを管理するための機能を提供します。
%% スコープチェーン（親スコープへの参照）を使用して、Rubyのレキシカルスコープを
%% 正確に実装しています。
%%
%% 主な機能：
%% - スコープの生成と破棄
%% - 変数の束縛（binding）と検索
%% - スコープチェーンを辿った変数検索
%% - スコープスタックの管理（将来の拡張用）
%%
%% 使用例：
%% ```
%% % トップレベルスコープを作成
%% GlobalScope1 = ruby_scope:new(),
%% GlobalScope2 = ruby_scope:bind(x, 10, GlobalScope1),
%%
%% % 子スコープを作成
%% LocalScope1 = ruby_scope:new(GlobalScope2),
%% LocalScope2 = ruby_scope:bind(y, 20, LocalScope1),
%%
%% % 変数検索（スコープチェーンを辿る）
%% {ok, 10} = ruby_scope:lookup(x, LocalScope2),  % 親スコープから検索
%% {ok, 20} = ruby_scope:lookup(y, LocalScope2),  % 現在のスコープから検索
%% {error, undefined} = ruby_scope:lookup(z, LocalScope2).
%% '''
%%
%% @author bruby development team
%% @version 1.0.0

-module(ruby_scope).
-export([
    new/0,
    new/1,
    bind/3,
    lookup/2,
    get_bindings/1,
    set_bindings/2,
    get_parent/1,
    push/2,
    pop/1,
    current/1
]).

%% ============================================================================
%% 型定義
%% ============================================================================

%% @doc スコープの型定義
%% スコープは変数の束縛を管理し、親スコープへの参照を持つ
-type scope() :: #{
    bindings := #{atom() => term()},  % 変数名 -> 値のマッピング
    parent := scope() | nil            % 親スコープ（スコープチェーン）
}.

%% @doc スコープスタックの型定義
%% スコープスタックは現在のスコープとスコープの履歴を管理する
-type scope_stack() :: #{
    current := scope(),      % 現在のスコープ
    stack := [scope()]       % スコープのスタック（push/popで使用）
}.

-export_type([scope/0, scope_stack/0]).

%% ============================================================================
%% スコープ生成と破棄
%% ============================================================================

%% @doc 新しいトップレベルスコープを作成
%%
%% 親スコープを持たないルートスコープを生成します。
%% グローバルスコープやトップレベルの実行環境を作成する際に使用します。
%%
%% 戻り値：
%%   - 空のバインディングと親スコープnil を持つ新しいスコープ
%%
%% 使用例：
%% ```
%% Scope = ruby_scope:new(),
%% % #{bindings => #{}, parent => nil}
%% '''
-spec new() -> scope().
new() ->
    #{
        bindings => #{},
        parent => nil
    }.

%% @doc 親スコープを指定して新しいスコープを作成
%%
%% 指定された親スコープを持つ子スコープを生成します。
%% スコープチェーンを構築する際に使用します。
%% メソッド内やブロック内など、新しいレキシカルスコープが必要な場合に呼び出します。
%%
%% パラメータ：
%%   - ParentScope: 親となるスコープ（map型）
%%
%% 戻り値：
%%   - 空のバインディングと指定された親スコープを持つ新しいスコープ
%%
%% 使用例：
%% ```
%% GlobalScope = ruby_scope:new(),
%% LocalScope = ruby_scope:new(GlobalScope),
%% % #{bindings => #{}, parent => GlobalScope}
%% '''
-spec new(scope()) -> scope().
new(ParentScope) when is_map(ParentScope) ->
    #{
        bindings => #{},
        parent => ParentScope
    }.

%% ============================================================================
%% 変数の束縛と検索
%% ============================================================================

%% @doc スコープに変数を束縛
%%
%% 指定された変数名に値を束縛した新しいスコープを返します。
%% 既存の束縛が存在する場合は上書きされます。
%% 元のスコープは変更されず、新しいスコープが返されます（関数型プログラミングの原則）。
%%
%% パラメータ：
%%   - Name: 変数名（atom型）
%%   - Value: 束縛する値（任意の型）
%%   - Scope: 対象のスコープ
%%
%% 戻り値：
%%   - 変数が束縛された新しいスコープ
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:bind(x, 42, Scope1),
%% Scope3 = ruby_scope:bind(y, "hello", Scope2),
%% % Scope3には x => 42, y => "hello" が束縛されている
%% '''
-spec bind(atom(), term(), scope()) -> scope().
bind(Name, Value, Scope) when is_atom(Name), is_map(Scope) ->
    Bindings = maps:get(bindings, Scope),
    NewBindings = maps:put(Name, Value, Bindings),
    maps:put(bindings, NewBindings, Scope).

%% @doc スコープチェーンを辿って変数を検索
%%
%% 現在のスコープから開始し、見つからなければ親スコープを順に検索します。
%% Rubyのレキシカルスコープを実装するための中核機能です。
%% 再帰的に親スコープを辿ることで、外側のスコープで定義された変数にアクセスできます。
%%
%% パラメータ：
%%   - Name: 検索する変数名（atom型）
%%   - Scope: 検索を開始するスコープ
%%
%% 戻り値：
%%   - {ok, Value}: 変数が見つかった場合、その値を返す
%%   - {error, undefined}: 変数が見つからなかった場合
%%
%% 使用例：
%% ```
%% GlobalScope1 = ruby_scope:new(),
%% GlobalScope2 = ruby_scope:bind(x, 100, GlobalScope1),
%% LocalScope1 = ruby_scope:new(GlobalScope2),
%% LocalScope2 = ruby_scope:bind(y, 200, LocalScope1),
%%
%% {ok, 100} = ruby_scope:lookup(x, LocalScope2),  % 親スコープから検索
%% {ok, 200} = ruby_scope:lookup(y, LocalScope2),  % 現在のスコープから検索
%% {error, undefined} = ruby_scope:lookup(z, LocalScope2).  % 見つからない
%% '''
-spec lookup(atom(), scope()) -> {ok, term()} | {error, undefined}.
lookup(Name, Scope) when is_atom(Name), is_map(Scope) ->
    Bindings = maps:get(bindings, Scope),
    case maps:find(Name, Bindings) of
        {ok, Value} ->
            {ok, Value};
        error ->
            % 親スコープを検索
            case maps:get(parent, Scope) of
                nil ->
                    {error, undefined};
                ParentScope ->
                    lookup(Name, ParentScope)
            end
    end.

%% ============================================================================
%% スコープ情報の取得と設定
%% ============================================================================

%% @doc スコープのバインディングを取得
%%
%% スコープに保存されている全ての変数束縛を取得します。
%% 現在のスコープのみのバインディングを返し、親スコープのバインディングは含みません。
%%
%% パラメータ：
%%   - Scope: 対象のスコープ
%%
%% 戻り値：
%%   - 変数名から値へのマップ（#{atom() => term()}）
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:bind(x, 10, Scope1),
%% Scope3 = ruby_scope:bind(y, 20, Scope2),
%% Bindings = ruby_scope:get_bindings(Scope3),
%% % #{x => 10, y => 20}
%% '''
-spec get_bindings(scope()) -> #{atom() => term()}.
get_bindings(Scope) when is_map(Scope) ->
    maps:get(bindings, Scope).

%% @doc スコープのバインディングを設定
%%
%% スコープのバインディングを一括で置き換えます。
%% 既存のバインディングは全て削除され、新しいバインディングで置き換えられます。
%% 通常はクロージャの環境を復元する際などに使用します。
%%
%% パラメータ：
%%   - Bindings: 設定する変数束縛のマップ（#{atom() => term()}）
%%   - Scope: 対象のスコープ
%%
%% 戻り値：
%%   - 新しいバインディングが設定されたスコープ
%%
%% 使用例：
%% ```
%% Scope = ruby_scope:new(),
%% NewBindings = #{x => 100, y => 200},
%% UpdatedScope = ruby_scope:set_bindings(NewBindings, Scope),
%% % UpdatedScopeには x => 100, y => 200 が設定されている
%% '''
-spec set_bindings(#{atom() => term()}, scope()) -> scope().
set_bindings(Bindings, Scope) when is_map(Bindings), is_map(Scope) ->
    maps:put(bindings, Bindings, Scope).

%% @doc 親スコープを取得
%%
%% スコープの親スコープを取得します。
%% トップレベルスコープの場合はnilを返します。
%%
%% パラメータ：
%%   - Scope: 対象のスコープ
%%
%% 戻り値：
%%   - 親スコープ、またはnil（トップレベルの場合）
%%
%% 使用例：
%% ```
%% GlobalScope = ruby_scope:new(),
%% LocalScope = ruby_scope:new(GlobalScope),
%% Parent = ruby_scope:get_parent(LocalScope),
%% % Parent は GlobalScope
%% nil = ruby_scope:get_parent(GlobalScope).
%% '''
-spec get_parent(scope()) -> scope() | nil.
get_parent(Scope) when is_map(Scope) ->
    maps:get(parent, Scope).

%% ============================================================================
%% スコープスタック管理（将来の拡張用）
%% ============================================================================

%% @doc スコープをスタックにプッシュ
%%
%% 新しいスコープを現在のスコープとし、古い現在のスコープをスタックに保存します。
%% スコープスタックは将来の拡張機能として実装されており、
%% ブロックやメソッド呼び出しなどでスコープを動的に切り替える際に使用します。
%%
%% パラメータ：
%%   - NewScope: 新しく現在のスコープとするスコープ
%%   - ScopeStack: 対象のスコープスタック
%%
%% 戻り値：
%%   - 更新されたスコープスタック（現在のスコープがNewScopeに、
%%     古いスコープがスタックに追加される）
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Stack = #{current => Scope1, stack => []},
%% Scope2 = ruby_scope:new(Scope1),
%% NewStack = ruby_scope:push(Scope2, Stack),
%% % NewStack = #{current => Scope2, stack => [Scope1]}
%% '''
-spec push(scope(), scope_stack()) -> scope_stack().
push(NewScope, ScopeStack) when is_map(NewScope), is_map(ScopeStack) ->
    CurrentScope = maps:get(current, ScopeStack),
    Stack = maps:get(stack, ScopeStack),
    #{
        current => NewScope,
        stack => [CurrentScope | Stack]
    }.

%% @doc スコープをスタックからポップ
%%
%% スタックから1つスコープを取り出して現在のスコープとします。
%% スタックが空の場合はエラーを返します。
%% メソッドやブロックから戻る際に、以前のスコープに復帰する目的で使用します。
%%
%% パラメータ：
%%   - ScopeStack: 対象のスコープスタック
%%
%% 戻り値：
%%   - {ok, UpdatedStack}: ポップに成功した場合、更新されたスタックを返す
%%   - {error, empty_stack}: スタックが空の場合
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:new(Scope1),
%% Stack = #{current => Scope2, stack => [Scope1]},
%% {ok, NewStack} = ruby_scope:pop(Stack),
%% % NewStack = #{current => Scope1, stack => []}
%%
%% EmptyStack = #{current => Scope1, stack => []},
%% {error, empty_stack} = ruby_scope:pop(EmptyStack).
%% '''
-spec pop(scope_stack()) -> {ok, scope_stack()} | {error, empty_stack}.
pop(ScopeStack) when is_map(ScopeStack) ->
    Stack = maps:get(stack, ScopeStack),
    case Stack of
        [] ->
            {error, empty_stack};
        [PrevScope | RestStack] ->
            {ok, #{
                current => PrevScope,
                stack => RestStack
            }}
    end.

%% @doc 現在のスコープを取得
%%
%% スコープスタックから現在アクティブなスコープを取得します。
%%
%% パラメータ：
%%   - ScopeStack: 対象のスコープスタック
%%
%% 戻り値：
%%   - 現在のスコープ
%%
%% 使用例：
%% ```
%% Scope = ruby_scope:new(),
%% Stack = #{current => Scope, stack => []},
%% Current = ruby_scope:current(Stack),
%% % Current は Scope と同じ
%% '''
-spec current(scope_stack()) -> scope().
current(ScopeStack) when is_map(ScopeStack) ->
    maps:get(current, ScopeStack).
