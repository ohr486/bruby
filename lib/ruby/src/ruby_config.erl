%% @doc Ruby configuration server
%% gen_server for managing Ruby runtime configuration
-module(ruby_config).
-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-behaviour(gen_server).

-type state() :: term().

%% ============================================================================
%% gen_server callbacks
%% ============================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec init(term()) -> {ok, state()}.
init(_Args) ->
  {ok, []}.

-spec handle_call(term(), {pid(), term()}, state()) -> {reply, term(), state()}.
handle_call(_Msg, _From, State) ->
  {reply, ok, State}.

-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
  {noreply, State}.

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
%% Public API
%% ============================================================================

