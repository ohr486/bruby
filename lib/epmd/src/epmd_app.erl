%% @doc EPMD application entry point
%% Application behavior implementation for EPMD daemon
-module(epmd_app).
-behaviour(application).

-export([start/0, start/2, stop/1]).

%% ============================================================================
%% Application callbacks
%% ============================================================================

-spec start() -> {ok, pid()} | {error, term()}.
start() ->
  start(normal, []).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(normal, Args) ->
  epmd_sup:start_link(Args).

-spec stop(term()) -> ok.
stop(_State) ->
  ok.

