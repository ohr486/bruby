-module(ruby_sup).
-export([init/1, start_link/0]).
-behaviour(supervisor).

%% callback apis

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, ok).

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
    }
  ],
  {ok, {{one_for_one, 3, 10}, Workers}}.
