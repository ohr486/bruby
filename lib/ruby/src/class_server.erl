-module(class_server).
-export([start_link/0, init/1, handle_call/3, handle_cast/2]).
-behaviour(gen_server).

-record(class_server, {
  class_pool={[], [], 0},
  class_ets=#{}
}).

%% callback apis

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).

init(Tab) ->
  {ok, #class_server{}}.

handle_call(_Msg, _From, Tab) ->
  {reply, ok, Tab}.

handle_cast(_Msg, Tab) ->
  {noreply, Tab}.
