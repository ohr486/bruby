-module(ruby_config).

-behaviour(gen_server).

%% Callbacks

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, ?MODULE, []).

init(Args) ->
  {ok, Args}.

