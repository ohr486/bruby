%% @doc Interactive Ruby (IRB) application module
%% Provides REPL (Read-Eval-Print Loop) functionality
-module(irb).
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

%% @doc Run the interactive Ruby REPL
-spec run() -> no_return().
run() ->
  io:put_chars("run irb repl.\n"),
  erlang:halt(0).
