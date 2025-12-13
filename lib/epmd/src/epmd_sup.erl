%% @doc Top-level supervisor for the EPMD application
%% Currently a stub implementation
-module(epmd_sup).
-export([init/1, start_link/0]).
-behaviour(supervisor).

%% ============================================================================
%% Supervisor callbacks
%% ============================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init(term()) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init(_Args) ->
  {ok, {{one_for_one, 3, 10}, []}}.
