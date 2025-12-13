%% @doc Ruby code server for managing class definitions
%% gen_server that maintains ruby_classes ETS table and monitors class ownership
-module(ruby_code_server).
-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-behaviour(gen_server).

%% Ruby code server state record
-record(ruby_code_server, {
  class_pool = {[], [], 0},  % Class pool: {Available, Allocated, Size}
  class_ets = #{}            % Map of monitor references to class names
}).

-type state() :: #ruby_code_server{}.

%% ============================================================================
%% gen_server callbacks
%% ============================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).

-spec init(term()) -> {ok, state()}.
init(ok) ->
  {ok, #ruby_code_server{}}.

-spec handle_call(term(), {pid(), term()}, state()) ->
  {reply, term(), state()}.
handle_call({def_class, Class, Pid, Tuple}, _From, Config) ->
  case ets:lookup(ruby_classes, Class) of
    [] ->
      {Ref, NewConfig} = def_class(Pid, Tuple, Config),
      {reply, {ok, Ref}, NewConfig};
    [CurrentTuple] ->
      {reply, {error, CurrentTuple}, Config}
  end;

handle_call({undef_class, Ref}, _From, Config) ->
  {reply, ok, undef_class(Ref, Config)}.

-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_Tuple, Config) ->
  {noreply, Config}.

-spec handle_info(term(), state()) -> {noreply, state()}.
handle_info(_Info, State) ->
  {noreply, State}.

-spec terminate(term(), state()) -> ok.
terminate(_Reason, _State) ->
  ok.

-spec code_change(term(), state(), term()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ============================================================================
%% Private functions
%% ============================================================================

%% @doc Define a class and monitor the owner process
-spec def_class(pid(), tuple(), state()) -> {reference(), state()}.
def_class(Pid, Tuple, #ruby_code_server{class_ets=ClassEts} = Config) ->
  ets:insert(ruby_classes, Tuple),
  Ref = erlang:monitor(process, Pid),
  Mod = erlang:element(1, Tuple),
  {Ref, Config#ruby_code_server{class_ets=maps:put(Ref, Mod, ClassEts)}}.

%% @doc Undefine a class by monitor reference
-spec undef_class(reference(), state()) -> state().
undef_class(Ref, #ruby_code_server{class_ets=ClassEts} = Config) ->
  case maps:find(Ref, ClassEts) of
    {ok, Class} ->
      ets:delete(ruby_classes, Class),
      Config#ruby_code_server{class_ets=maps:remove(Ref, ClassEts)};
    error ->
      Config
  end.