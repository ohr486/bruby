%% @doc Erlang Port Mapper Daemon (EPMD) application module
%% Provides distributed Erlang node registration and discovery
-module(epmd).
-export([start/2, stop/1]).
-export([run/0]).
-behaviour(application).

%% ============================================================================
%% Application callbacks
%% ============================================================================

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_Type, _Args) ->
  {ok, self()}.

-spec stop(term()) -> ok.
stop(_) ->
  ok.

%% ============================================================================
%% Public API
%% ============================================================================

%% @doc Run the EPMD daemon
-spec run() -> no_return().
run() ->
  io:put_chars("run epmd.\n"),
  erlang:halt(0).
