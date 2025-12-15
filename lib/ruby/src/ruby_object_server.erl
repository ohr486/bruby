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
    is_instance_of/2
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
    next_id := object_id()
}.

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
    {ok, #{next_id => 3}}.

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
