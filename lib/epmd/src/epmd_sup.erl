%% @doc Top-level supervisor for the EPMD application
%% Currently a stub implementation
-module(epmd_sup).
-export([init/1, start_link/0, start_link/1]).
-behaviour(supervisor).

%% ============================================================================
%% Supervisor callbacks
%% ============================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
  start_link([]).

-spec start_link(term()) -> {ok, pid()} | {error, term()}.
start_link(Args) ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, Args).

-spec init(term()) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init(_Args) ->
  {ok, {{one_for_one, 3, 10}, []}}.
