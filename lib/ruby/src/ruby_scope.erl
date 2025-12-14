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
    current/1,
    % バインディング管理
    create_binding/1,
    binding_get_variable/2,
    binding_set_variable/3,
    binding_get_all_variables/1,
    binding_to_scope/1,
    capture_closure_bindings/2,
    flatten_bindings/1
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

%% @doc バインディングオブジェクトの型定義
%% バインディングはRubyの実行コンテキストをカプセル化する
%% 特定のスコープの状態をキャプチャし、後で復元できる
-type binding() :: #{
    type := binding,              % バインディングオブジェクトであることを示す
    scope := scope(),             % キャプチャされたスコープ
    captured_bindings := #{atom() => term()}  % フラット化された全変数の束縛
}.

-export_type([scope/0, scope_stack/0, binding/0]).

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

%% ============================================================================
%% バインディング管理
%% ============================================================================

%% @doc スコープからバインディングオブジェクトを作成
%%
%% 指定されたスコープの状態をキャプチャしてバインディングオブジェクトを作成します。
%% バインディングオブジェクトは、スコープチェーン全体の変数をフラット化して保持します。
%% これにより、Rubyの`binding`メソッドと同様に、現在のコンテキストを
%% 保存して後で`eval`などで使用できます。
%%
%% パラメータ：
%%   - Scope: キャプチャするスコープ
%%
%% 戻り値：
%%   - バインディングオブジェクト（binding型）
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:bind(x, 10, Scope1),
%% Scope3 = ruby_scope:bind(y, 20, Scope2),
%% Binding = ruby_scope:create_binding(Scope3),
%% % Bindingには x => 10, y => 20 の情報が含まれる
%% '''
-spec create_binding(scope()) -> binding().
create_binding(Scope) when is_map(Scope) ->
    % スコープチェーン全体の変数をフラット化
    FlattenedBindings = flatten_bindings(Scope),
    #{
        type => binding,
        scope => Scope,
        captured_bindings => FlattenedBindings
    }.

%% @doc バインディングから変数を取得
%%
%% バインディングオブジェクトに保存されている変数の値を取得します。
%% スコープチェーン全体から変数を検索します。
%%
%% パラメータ：
%%   - Name: 変数名（atom型）
%%   - Binding: バインディングオブジェクト
%%
%% 戻り値：
%%   - {ok, Value}: 変数が見つかった場合、その値を返す
%%   - {error, undefined}: 変数が見つからなかった場合
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:bind(x, 100, Scope1),
%% Binding = ruby_scope:create_binding(Scope2),
%% {ok, 100} = ruby_scope:binding_get_variable(x, Binding).
%% '''
-spec binding_get_variable(atom(), binding()) -> {ok, term()} | {error, undefined}.
binding_get_variable(Name, Binding) when is_atom(Name), is_map(Binding) ->
    CapturedBindings = maps:get(captured_bindings, Binding),
    case maps:find(Name, CapturedBindings) of
        {ok, Value} ->
            {ok, Value};
        error ->
            {error, undefined}
    end.

%% @doc バインディングに変数を設定
%%
%% バインディングオブジェクトに新しい変数を追加、または既存の変数を更新します。
%% 元のバインディングは変更されず、新しいバインディングが返されます。
%%
%% パラメータ：
%%   - Name: 変数名（atom型）
%%   - Value: 設定する値
%%   - Binding: バインディングオブジェクト
%%
%% 戻り値：
%%   - 変数が設定された新しいバインディング
%%
%% 使用例：
%% ```
%% Binding1 = ruby_scope:create_binding(ruby_scope:new()),
%% Binding2 = ruby_scope:binding_set_variable(x, 42, Binding1),
%% {ok, 42} = ruby_scope:binding_get_variable(x, Binding2).
%% '''
-spec binding_set_variable(atom(), term(), binding()) -> binding().
binding_set_variable(Name, Value, Binding) when is_atom(Name), is_map(Binding) ->
    CapturedBindings = maps:get(captured_bindings, Binding),
    NewCapturedBindings = maps:put(Name, Value, CapturedBindings),
    Scope = maps:get(scope, Binding),
    NewScope = bind(Name, Value, Scope),
    Binding#{
        captured_bindings => NewCapturedBindings,
        scope => NewScope
    }.

%% @doc バインディング内の全変数を取得
%%
%% バインディングオブジェクトに保存されている全ての変数名と値のマップを返します。
%% スコープチェーン全体の変数がフラット化されて返されます。
%%
%% パラメータ：
%%   - Binding: バインディングオブジェクト
%%
%% 戻り値：
%%   - 変数名から値へのマップ（#{atom() => term()}）
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:bind(x, 10, Scope1),
%% Scope3 = ruby_scope:bind(y, 20, Scope2),
%% Binding = ruby_scope:create_binding(Scope3),
%% AllVars = ruby_scope:binding_get_all_variables(Binding),
%% % AllVars = #{x => 10, y => 20}
%% '''
-spec binding_get_all_variables(binding()) -> #{atom() => term()}.
binding_get_all_variables(Binding) when is_map(Binding) ->
    maps:get(captured_bindings, Binding).

%% @doc バインディングをスコープに変換
%%
%% バインディングオブジェクトから元のスコープを取得します。
%% evalなどでバインディングのコンテキストでコードを実行する際に使用します。
%%
%% パラメータ：
%%   - Binding: バインディングオブジェクト
%%
%% 戻り値：
%%   - スコープ
%%
%% 使用例：
%% ```
%% OriginalScope = ruby_scope:new(),
%% Binding = ruby_scope:create_binding(OriginalScope),
%% Scope = ruby_scope:binding_to_scope(Binding),
%% % Scope と OriginalScope は同じ
%% '''
-spec binding_to_scope(binding()) -> scope().
binding_to_scope(Binding) when is_map(Binding) ->
    Scope = maps:get(scope, Binding),
    % captured_bindingsの最新の値でスコープを更新
    CapturedBindings = maps:get(captured_bindings, Binding),
    set_bindings(CapturedBindings, Scope).

%% @doc クロージャのバインディングをキャプチャ
%%
%% 指定されたスコープから、指定された変数名のリストに該当する変数のみを
%% キャプチャしたバインディングを作成します。
%% クロージャで特定の変数のみをキャプチャする場合に使用します。
%%
%% パラメータ：
%%   - VarNames: キャプチャする変数名のリスト（[atom()]）
%%   - Scope: 元となるスコープ
%%
%% 戻り値：
%%   - 指定された変数のみを含むバインディングマップ（#{atom() => term()}）
%%
%% 使用例：
%% ```
%% Scope1 = ruby_scope:new(),
%% Scope2 = ruby_scope:bind(x, 10, Scope1),
%% Scope3 = ruby_scope:bind(y, 20, Scope2),
%% Scope4 = ruby_scope:bind(z, 30, Scope3),
%% Captured = ruby_scope:capture_closure_bindings([x, y], Scope4),
%% % Captured = #{x => 10, y => 20}  (zは含まれない)
%% '''
-spec capture_closure_bindings([atom()], scope()) -> #{atom() => term()}.
capture_closure_bindings(VarNames, Scope) when is_list(VarNames), is_map(Scope) ->
    lists:foldl(
        fun(VarName, Acc) ->
            case lookup(VarName, Scope) of
                {ok, Value} ->
                    maps:put(VarName, Value, Acc);
                {error, undefined} ->
                    Acc
            end
        end,
        #{},
        VarNames
    ).

%% @doc スコープチェーン全体の変数をフラット化
%%
%% スコープチェーンを辿って、全ての親スコープの変数を含む
%% フラット化されたバインディングマップを作成します。
%% 同じ変数名が複数のスコープに存在する場合、より内側（子）のスコープの値が優先されます。
%%
%% パラメータ：
%%   - Scope: フラット化するスコープ
%%
%% 戻り値：
%%   - 全スコープの変数を含むマップ（#{atom() => term()}）
%%
%% 使用例：
%% ```
%% GlobalScope1 = ruby_scope:new(),
%% GlobalScope2 = ruby_scope:bind(x, 10, GlobalScope1),
%% LocalScope1 = ruby_scope:new(GlobalScope2),
%% LocalScope2 = ruby_scope:bind(y, 20, LocalScope1),
%% Flattened = ruby_scope:flatten_bindings(LocalScope2),
%% % Flattened = #{x => 10, y => 20}
%% '''
-spec flatten_bindings(scope()) -> #{atom() => term()}.
flatten_bindings(Scope) when is_map(Scope) ->
    flatten_bindings_recursive(Scope, #{}).

%% @doc スコープチェーンを再帰的に辿ってバインディングを収集（内部関数）
-spec flatten_bindings_recursive(scope() | nil, #{atom() => term()}) -> #{atom() => term()}.
flatten_bindings_recursive(nil, Acc) ->
    Acc;
flatten_bindings_recursive(Scope, Acc) when is_map(Scope) ->
    % 親スコープを先に処理（親の値が基本となる）
    Parent = maps:get(parent, Scope),
    AccWithParent = flatten_bindings_recursive(Parent, Acc),
    % 現在のスコープの変数で上書き（子スコープの値が優先）
    CurrentBindings = maps:get(bindings, Scope),
    maps:merge(AccWithParent, CurrentBindings).
