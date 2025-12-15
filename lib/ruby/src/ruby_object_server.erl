%% @doc Rubyオブジェクトシステムの実装
%%
%% このモジュールはRubyのオブジェクトシステムを実装します。
%% オブジェクトの生成、インスタンス変数の管理、
%% Object、Class、Moduleの基底クラスを提供します。
%%
%% ## オブジェクトモデル
%%
%% brubyのオブジェクトシステムは以下の要素で構成されます：
%%
%% - **Object**: すべてのRubyオブジェクトの基底クラス
%% - **Class**: クラスを表すクラス（Class自身もClassのインスタンス）
%% - **Module**: モジュールを表すクラス
%%
%% ## オブジェクトID管理
%%
%% オブジェクトIDはgen_serverで管理され、スレッドセーフに
%% 一意なIDを生成します。
%%
%% ## 使用例
%%
%% ```erlang
%% % オブジェクトシステムの開始
%% {ok, Pid} = ruby_object_server:start_link(),
%%
%% % 新しいオブジェクトを作成
%% {ok, Obj} = ruby_object_server:new_instance('MyClass'),
%%
%% % インスタンス変数の設定
%% Obj2 = ruby_object_server:set_instance_var(Obj, '@name', "Alice"),
%%
%% % インスタンス変数の取得
%% {ok, "Alice"} = ruby_object_server:get_instance_var(Obj2, '@name').
%% ```
%%
%% @author bruby development team
%% @version 1.0.0

-module(ruby_object_server).
-behaviour(gen_server).

%% API
-export([
    start_link/0,
    stop/0,
    new_instance/1,
    new_instance/2,
    get_instance_var/2,
    set_instance_var/3,
    get_instance_vars/1,
    get_class/1,
    get_object_id/1,
    is_instance_of/2,
    % メソッド管理
    define_class_method/3,
    lookup_method/2,
    lookup_method/3,
    get_class_methods/1,
    % メソッドディスパッチ
    send_message/3,
    send_message/4,
    % アクセサメソッド
    attr_reader/2,
    attr_writer/2,
    attr_accessor/2,
    % 動的メソッド定義
    define_method/4,
    method_send/3,
    method_send/4,
    set_method_missing/3,
    has_method_missing/1
]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% 基底クラスの定義
-export([
    object_class/0,
    class_class/0,
    module_class/0
]).

%% ============================================================================
%% 型定義
%% ============================================================================

-type object_id() :: integer().
-type class_name() :: atom().
-type instance_var_name() :: atom().
-type ruby_object() :: #{
    type := object,
    class := class_name(),
    id := object_id(),
    instance_vars := #{instance_var_name() => term()}
}.

-type ruby_class() :: #{
    type := class,
    name := class_name(),
    superclass := class_name() | nil,
    methods := #{atom() => term()},
    instance_vars := [instance_var_name()],
    id := object_id()
}.

-type ruby_module() :: #{
    type := module,
    name := atom(),
    methods := #{atom() => term()},
    id := object_id()
}.

-type state() :: #{
    next_id := object_id(),
    class_methods := #{class_name() => #{atom() => method_def()}},  % クラスごとのメソッドテーブル
    method_cache := #{cache_key() => method_def() | not_found},     % メソッドキャッシュ
    method_missing := #{class_name() => method_def()}               % method_missingハンドラ
}.

-type method_def() :: #{
    name := atom(),
    params := list(),
    body := term(),
    closure_env := term()
}.

-type cache_key() :: {class_name(), atom()}.  % {ClassName, MethodName}

-export_type([
    object_id/0,
    class_name/0,
    ruby_object/0,
    ruby_class/0,
    ruby_module/0
]).

%% ============================================================================
%% API
%% ============================================================================

%% @doc オブジェクトシステムを開始
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc オブジェクトシステムを停止
-spec stop() -> ok.
stop() ->
    gen_server:stop(?MODULE).

%% @doc 新しいオブジェクトインスタンスを作成（デフォルトはObjectクラス）
-spec new_instance(class_name()) -> {ok, ruby_object()}.
new_instance(ClassName) ->
    new_instance(ClassName, #{}).

%% @doc 新しいオブジェクトインスタンスを作成（初期インスタンス変数付き）
-spec new_instance(class_name(), #{instance_var_name() => term()}) -> {ok, ruby_object()}.
new_instance(ClassName, InitialVars) when is_atom(ClassName), is_map(InitialVars) ->
    gen_server:call(?MODULE, {new_instance, ClassName, InitialVars}).

%% @doc インスタンス変数を取得
-spec get_instance_var(ruby_object(), instance_var_name()) -> {ok, term()} | {error, not_found}.
get_instance_var(#{type := object, instance_vars := Vars}, VarName) when is_atom(VarName) ->
    case maps:get(VarName, Vars, undefined) of
        undefined -> {error, not_found};
        Value -> {ok, Value}
    end;
get_instance_var(_, _) ->
    {error, not_an_object}.

%% @doc インスタンス変数を設定
-spec set_instance_var(ruby_object(), instance_var_name(), term()) -> ruby_object().
set_instance_var(#{type := object, instance_vars := Vars} = Obj, VarName, Value)
    when is_atom(VarName) ->
    NewVars = maps:put(VarName, Value, Vars),
    Obj#{instance_vars => NewVars};
set_instance_var(Obj, _, _) ->
    Obj.

%% @doc すべてのインスタンス変数を取得
-spec get_instance_vars(ruby_object()) -> {ok, #{instance_var_name() => term()}} | {error, not_an_object}.
get_instance_vars(#{type := object, instance_vars := Vars}) ->
    {ok, Vars};
get_instance_vars(_) ->
    {error, not_an_object}.

%% @doc オブジェクトのクラスを取得
-spec get_class(ruby_object()) -> {ok, class_name()} | {error, not_an_object}.
get_class(#{type := object, class := ClassName}) ->
    {ok, ClassName};
get_class(#{type := class}) ->
    {ok, 'Class'};
get_class(#{type := module}) ->
    {ok, 'Module'};
get_class(_) ->
    {error, not_an_object}.

%% @doc オブジェクトのIDを取得
-spec get_object_id(ruby_object()) -> {ok, object_id()} | {error, not_an_object}.
get_object_id(#{type := object, id := Id}) ->
    {ok, Id};
get_object_id(#{type := class, id := Id}) ->
    {ok, Id};
get_object_id(#{type := module, id := Id}) ->
    {ok, Id};
get_object_id(_) ->
    {error, not_an_object}.

%% @doc オブジェクトが指定したクラスのインスタンスかどうかを判定
-spec is_instance_of(ruby_object(), class_name()) -> boolean().
is_instance_of(#{type := object, class := ClassName}, ClassName) ->
    true;
is_instance_of(#{type := object, class := ObjClass}, CheckClass) ->
    % 継承チェック（将来の拡張用）
    % 現在は直接の一致のみチェック
    ObjClass =:= CheckClass;
is_instance_of(_, _) ->
    false.

%% ============================================================================
%% 基底クラスの定義
%% ============================================================================

%% @doc Objectクラスの定義
%%
%% ObjectはすべてのRubyオブジェクトの基底クラスです。
-spec object_class() -> ruby_class().
object_class() ->
    #{
        type => class,
        name => 'Object',
        superclass => nil,
        methods => #{},
        instance_vars => [],
        id => 0  % 特別なID
    }.

%% @doc Classクラスの定義
%%
%% Classはクラスを表すクラスです。
%% Class自身もClassのインスタンスです。
-spec class_class() -> ruby_class().
class_class() ->
    #{
        type => class,
        name => 'Class',
        superclass => 'Object',
        methods => #{},
        instance_vars => [],
        id => 1  % 特別なID
    }.

%% @doc Moduleクラスの定義
%%
%% Moduleはモジュールを表すクラスです。
-spec module_class() -> ruby_module().
module_class() ->
    #{
        type => module,
        name => 'Module',
        methods => #{},
        id => 2  % 特別なID
    }.

%% ============================================================================
%% gen_server callbacks
%% ============================================================================

%% @doc gen_server初期化
-spec init([]) -> {ok, state()}.
init([]) ->
    % オブジェクトIDは3から開始（0, 1, 2は基底クラス用に予約）
    {ok, #{
        next_id => 3,
        class_methods => #{},  % クラスメソッドテーブル
        method_cache => #{},   % メソッドキャッシュ
        method_missing => #{}  % method_missingハンドラ
    }}.

%% @doc 同期呼び出しハンドラ
-spec handle_call(term(), {pid(), term()}, state()) ->
    {reply, term(), state()}.
handle_call({new_instance, ClassName, InitialVars}, _From, #{next_id := NextId} = State) ->
    % 新しいオブジェクトを作成
    Obj = #{
        type => object,
        class => ClassName,
        id => NextId,
        instance_vars => InitialVars
    },
    NewState = State#{next_id => NextId + 1},
    {reply, {ok, Obj}, NewState};

handle_call({define_method, ClassName, MethodName, MethodDef}, _From, State) ->
    #{class_methods := ClassMethods, method_cache := Cache} = State,
    % クラスのメソッドテーブルを取得または作成
    Methods = maps:get(ClassName, ClassMethods, #{}),
    % メソッドを追加
    NewMethods = maps:put(MethodName, MethodDef, Methods),
    NewClassMethods = maps:put(ClassName, NewMethods, ClassMethods),
    % キャッシュをクリア（そのクラスのメソッドキャッシュのみ）
    NewCache = clear_class_cache(ClassName, Cache),
    NewState = State#{class_methods => NewClassMethods, method_cache => NewCache},
    {reply, ok, NewState};

handle_call({lookup_method, ClassName, MethodName}, _From, State) ->
    #{class_methods := ClassMethods, method_cache := Cache} = State,
    CacheKey = {ClassName, MethodName},
    % まずキャッシュをチェック
    case maps:get(CacheKey, Cache, undefined) of
        undefined ->
            % キャッシュにない場合は検索
            Result = do_lookup_method(ClassName, MethodName, ClassMethods),
            % 結果をキャッシュに保存
            NewCache = maps:put(CacheKey, Result, Cache),
            NewState = State#{method_cache => NewCache},
            {reply, Result, NewState};
        CachedResult ->
            % キャッシュから返す
            {reply, CachedResult, State}
    end;

handle_call({get_class_methods, ClassName}, _From, State) ->
    #{class_methods := ClassMethods} = State,
    Methods = maps:get(ClassName, ClassMethods, #{}),
    {reply, {ok, Methods}, State};

handle_call({set_method_missing, ClassName, Handler}, _From, State) ->
    #{method_missing := MethodMissing} = State,
    NewMethodMissing = maps:put(ClassName, Handler, MethodMissing),
    NewState = State#{method_missing => NewMethodMissing},
    {reply, ok, NewState};

handle_call({has_method_missing, ClassName}, _From, State) ->
    #{method_missing := MethodMissing} = State,
    Result = maps:is_key(ClassName, MethodMissing),
    {reply, Result, State};

handle_call({get_method_missing, ClassName}, _From, State) ->
    #{method_missing := MethodMissing} = State,
    case maps:get(ClassName, MethodMissing, undefined) of
        undefined -> {reply, not_found, State};
        Handler -> {reply, {ok, Handler}, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

%% @doc 非同期メッセージハンドラ
-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

%% @doc その他のメッセージハンドラ
-spec handle_info(term(), state()) -> {noreply, state()}.
handle_info(_Info, State) ->
    {noreply, State}.

%% @doc 終了処理
-spec terminate(term(), state()) -> ok.
terminate(_Reason, _State) ->
    ok.

%% @doc コード変更時の状態変換
-spec code_change(term(), state(), term()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ============================================================================
%% メソッド管理API
%% ============================================================================

%% @doc クラスにメソッドを定義
%%
%% 指定されたクラスにメソッドを追加します。
%% メソッド定義には名前、パラメータ、本体、クロージャ環境が含まれます。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - MethodName: メソッド名
%%   - MethodDef: メソッド定義（method_def型）
%%
%% 戻り値：
%%   - ok: 成功
-spec define_class_method(class_name(), atom(), method_def()) -> ok.
define_class_method(ClassName, MethodName, MethodDef)
    when is_atom(ClassName), is_atom(MethodName), is_map(MethodDef) ->
    gen_server:call(?MODULE, {define_method, ClassName, MethodName, MethodDef}).

%% @doc メソッドを検索（キャッシュあり）
%%
%% クラス階層を辿ってメソッドを検索します。
%% 結果はキャッシュされ、次回以降の検索が高速化されます。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - MethodName: メソッド名
%%
%% 戻り値：
%%   - {ok, MethodDef}: メソッドが見つかった場合
%%   - not_found: メソッドが見つからない場合
-spec lookup_method(class_name(), atom()) -> {ok, method_def()} | not_found.
lookup_method(ClassName, MethodName) when is_atom(ClassName), is_atom(MethodName) ->
    gen_server:call(?MODULE, {lookup_method, ClassName, MethodName}).

%% @doc メソッドを検索（ruby_objectから）
%%
%% オブジェクトのクラスを取得してメソッドを検索します。
%%
%% パラメータ：
%%   - Object: Rubyオブジェクト
%%   - MethodName: メソッド名
%%
%% 戻り値：
%%   - {ok, MethodDef}: メソッドが見つかった場合
%%   - not_found: メソッドが見つからない場合
-spec lookup_method(ruby_object(), atom(), unused) -> {ok, method_def()} | not_found.
lookup_method(#{type := object, class := ClassName}, MethodName, _Unused) ->
    lookup_method(ClassName, MethodName);
lookup_method(_, _, _) ->
    not_found.

%% @doc クラスの全メソッドを取得
%%
%% 指定されたクラスに定義されているすべてのメソッドを取得します。
%% （継承されたメソッドは含まれません）
%%
%% パラメータ：
%%   - ClassName: クラス名
%%
%% 戻り値：
%%   - {ok, Methods}: メソッドのマップ
-spec get_class_methods(class_name()) -> {ok, #{atom() => method_def()}}.
get_class_methods(ClassName) when is_atom(ClassName) ->
    gen_server:call(?MODULE, {get_class_methods, ClassName}).

%% @doc メソッドディスパッチ（引数なし）
%%
%% オブジェクトに対してメソッドを呼び出します。
%% メソッド探索、引数の束縛、本体の評価を行います。
%%
%% パラメータ：
%%   - Object: レシーバーオブジェクト
%%   - MethodName: メソッド名
%%   - Env: 評価環境
%%
%% 戻り値：
%%   - {ok, Result, NewEnv}: 成功時、結果と更新された環境
%%   - {error, Reason}: エラー時
-spec send_message(ruby_object(), atom(), term()) -> {ok, term(), term()} | {error, term()}.
send_message(Object, MethodName, Env) ->
    send_message(Object, MethodName, [], Env).

%% @doc メソッドディスパッチ（引数あり）
%%
%% オブジェクトに対してメソッドを呼び出します。
%% メソッド探索、引数の束縛、本体の評価を行います。
%%
%% パラメータ：
%%   - Object: レシーバーオブジェクト
%%   - MethodName: メソッド名
%%   - Args: 引数のリスト
%%   - Env: 評価環境
%%
%% 戻り値：
%%   - {ok, Result, NewEnv}: 成功時、結果と更新された環境
%%   - {error, Reason}: エラー時
-spec send_message(ruby_object(), atom(), list(), term()) -> {ok, term(), term()} | {error, term()}.
send_message(Object, MethodName, Args, Env) when is_atom(MethodName), is_list(Args) ->
    case lookup_method(Object, MethodName, unused) of
        {ok, _MethodDef} ->
            % TODO: メソッドの実行（ruby_evaluatorとの統合が必要）
            % 現時点では基本的な構造のみ実装
            {ok, nil, Env};
        not_found ->
            % method_missingを呼び出す（将来の拡張）
            {error, {method_not_found, MethodName}}
    end.

%% @doc attr_readerを定義
%%
%% インスタンス変数の読み取りメソッドを生成します。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - AttrNames: 属性名のリスト
%%
%% 戻り値：
%%   - ok: 成功
-spec attr_reader(class_name(), list(atom())) -> ok.
attr_reader(ClassName, AttrNames) when is_atom(ClassName), is_list(AttrNames) ->
    lists:foreach(fun(AttrName) ->
        % ゲッターメソッドを定義
        IvarName = list_to_atom("@" ++ atom_to_list(AttrName)),
        MethodDef = #{
            name => AttrName,
            params => [],
            body => {get_instance_var, IvarName},
            closure_env => nil
        },
        define_class_method(ClassName, AttrName, MethodDef)
    end, AttrNames),
    ok.

%% @doc attr_writerを定義
%%
%% インスタンス変数の書き込みメソッドを生成します。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - AttrNames: 属性名のリスト
%%
%% 戻り値：
%%   - ok: 成功
-spec attr_writer(class_name(), list(atom())) -> ok.
attr_writer(ClassName, AttrNames) when is_atom(ClassName), is_list(AttrNames) ->
    lists:foreach(fun(AttrName) ->
        % セッターメソッドを定義
        IvarName = list_to_atom("@" ++ atom_to_list(AttrName)),
        SetterName = list_to_atom(atom_to_list(AttrName) ++ "="),
        MethodDef = #{
            name => SetterName,
            params => [value],
            body => {set_instance_var, IvarName, {var, value}},
            closure_env => nil
        },
        define_class_method(ClassName, SetterName, MethodDef)
    end, AttrNames),
    ok.

%% @doc attr_accessorを定義
%%
%% インスタンス変数の読み取りと書き込みメソッドの両方を生成します。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - AttrNames: 属性名のリスト
%%
%% 戻り値：
%%   - ok: 成功
-spec attr_accessor(class_name(), list(atom())) -> ok.
attr_accessor(ClassName, AttrNames) when is_atom(ClassName), is_list(AttrNames) ->
    attr_reader(ClassName, AttrNames),
    attr_writer(ClassName, AttrNames),
    ok.

%% @doc define_methodを使用してメソッドを動的に定義
%%
%% 実行時にメソッドを定義します。
%% Rubyのdefine_methodに相当します。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - MethodName: メソッド名
%%   - Params: パラメータリスト
%%   - Body: メソッド本体
%%
%% 戻り値：
%%   - ok: 成功
-spec define_method(class_name(), atom(), list(), term()) -> ok.
define_method(ClassName, MethodName, Params, Body)
    when is_atom(ClassName), is_atom(MethodName), is_list(Params) ->
    MethodDef = #{
        name => MethodName,
        params => Params,
        body => Body,
        closure_env => nil
    },
    define_class_method(ClassName, MethodName, MethodDef).

%% @doc sendメソッド（メソッド名を動的に指定して呼び出し）
%%
%% オブジェクトに対してメソッド名を文字列やシンボルで指定して呼び出します。
%% Rubyのsendメソッドに相当します。
%%
%% パラメータ：
%%   - Object: レシーバーオブジェクト
%%   - MethodName: メソッド名（アトム）
%%   - Env: 評価環境
%%
%% 戻り値：
%%   - {ok, Result, NewEnv}: 成功時
%%   - {error, Reason}: エラー時
-spec method_send(ruby_object(), atom(), term()) -> {ok, term(), term()} | {error, term()}.
method_send(Object, MethodName, Env) ->
    method_send(Object, MethodName, [], Env).

%% @doc sendメソッド（引数あり）
%%
%% オブジェクトに対してメソッド名と引数を指定して呼び出します。
%%
%% パラメータ：
%%   - Object: レシーバーオブジェクト
%%   - MethodName: メソッド名（アトム）
%%   - Args: 引数のリスト
%%   - Env: 評価環境
%%
%% 戻り値：
%%   - {ok, Result, NewEnv}: 成功時
%%   - {error, Reason}: エラー時
-spec method_send(ruby_object(), atom(), list(), term()) -> {ok, term(), term()} | {error, term()}.
method_send(Object, MethodName, Args, Env) when is_atom(MethodName), is_list(Args) ->
    % send_messageを使用（同じ実装）
    send_message(Object, MethodName, Args, Env).

%% @doc method_missingハンドラを設定
%%
%% 未定義のメソッドが呼ばれた時のハンドラを設定します。
%%
%% パラメータ：
%%   - ClassName: クラス名
%%   - MethodName: 呼ばれたメソッド名
%%   - Handler: ハンドラ関数
%%
%% 戻り値：
%%   - ok: 成功
-spec set_method_missing(class_name(), atom(), method_def()) -> ok.
set_method_missing(ClassName, _MethodName, Handler)
    when is_atom(ClassName), is_map(Handler) ->
    gen_server:call(?MODULE, {set_method_missing, ClassName, Handler}).

%% @doc method_missingハンドラが設定されているかチェック
%%
%% パラメータ：
%%   - ClassName: クラス名
%%
%% 戻り値：
%%   - true: 設定されている
%%   - false: 設定されていない
-spec has_method_missing(class_name()) -> boolean().
has_method_missing(ClassName) when is_atom(ClassName) ->
    gen_server:call(?MODULE, {has_method_missing, ClassName}).

%% ============================================================================
%% 内部ヘルパー関数
%% ============================================================================

%% @doc クラスのメソッドキャッシュをクリア
-spec clear_class_cache(class_name(), #{cache_key() => term()}) -> #{cache_key() => term()}.
clear_class_cache(ClassName, Cache) ->
    maps:filter(fun({CName, _MethodName}, _Value) ->
        CName =/= ClassName
    end, Cache).

%% @doc メソッドを実際に検索（継承チェーンを辿る）
-spec do_lookup_method(class_name(), atom(), #{class_name() => #{atom() => method_def()}})
    -> {ok, method_def()} | not_found.
do_lookup_method(ClassName, MethodName, ClassMethods) ->
    case maps:get(ClassName, ClassMethods, undefined) of
        undefined ->
            % クラスが見つからない場合
            not_found;
        Methods ->
            case maps:get(MethodName, Methods, undefined) of
                undefined ->
                    % メソッドが見つからない場合、親クラスを検索
                    % 現時点では継承未実装のため、not_foundを返す
                    % TODO: 継承実装時に親クラスを辿る処理を追加
                    not_found;
                MethodDef ->
                    {ok, MethodDef}
            end
    end.
