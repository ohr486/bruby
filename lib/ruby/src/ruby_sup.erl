%% @doc Top-level supervisor for the Ruby application
%% Manages ruby_config, ruby_code_server, ruby_object_server, and class_server workers
-module(ruby_sup).
-export([init/1, start_link/0]).
-behaviour(supervisor).

%% ============================================================================
%% Supervisor callbacks
%% ============================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, ok).

-spec init(term()) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init(ok) ->
  Workers = [
    {
      ruby_config,
      {ruby_config, start_link, []},
      permanent,
      2000,
      worker,
      [ruby_config]
    },
    {
      ruby_code_server,
      {ruby_code_server, start_link, []},
      permanent,
      2000,
      worker,
      [ruby_code_server]
    },
    {
      ruby_object_server,
      {ruby_object_server, start_link, []},
      permanent,
      2000,
      worker,
      [ruby_object_server]
    },
    {
      class_server,
      {class_server, start_link, []},
      permanent,
      2000,
      worker,
      [class_server]
    }
  ],
  {ok, {{one_for_one, 3, 10}, Workers}}.
