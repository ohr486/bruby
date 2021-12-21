-module(ruby_sup).
-behaviour(supervisor).

-export([init/1, start_link/0]).

%% Callbacks

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, ok).

init(ok) ->
  Workers = [],
  {ok, {{one_for_one, 3, 10}, Workers}}.
