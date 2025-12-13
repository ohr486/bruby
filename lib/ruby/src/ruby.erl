%% @doc Ruby application module
%% Main entry point for the bruby application
-module(ruby).
-export([start/2, stop/1]).
-export([run_script/0]).
-behaviour(application).

%% ============================================================================
%% Application callbacks
%% ============================================================================

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_Type, _Args) ->
  ruby_sup:start_link().

-spec stop(term()) -> ok.
stop(_) ->
  ok.

%% ============================================================================
%% Public API
%% ============================================================================

%% @doc Run a Ruby script from command line arguments
-spec run_script() -> no_return().
run_script() ->
  utils:check_args(init:get_plain_arguments()),
  erlang:halt(0).
