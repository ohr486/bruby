-module(ruby_config).
-export([start_link/0, init/1, handle_call/3, handle_cast/2]).
-behaviour(gen_server).

%% callback apis

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, ?MODULE, []).

init(Tab) ->
  {ok, Tab}.

handle_call(_Msg, _From, Tab) ->
  {reply, ok, Tab}.

handle_cast(_Msg, Tab) ->
  {noreply, Tab}.

%% apis

