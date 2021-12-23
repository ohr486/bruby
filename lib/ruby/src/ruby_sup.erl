-module(ruby_sup).
-behaviour(supervisor).

-export([init/1, start_link/0]).

%% Callbacks

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
    }
  ],
  {ok, {{one_for_one, 3, 10}, Workers}}.
