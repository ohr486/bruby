-module(ruby_code_server).
-export([start_link/0, init/1, handle_call/3, handle_cast/2]).
-behaviour(gen_server).

-record(ruby_code_server, {
  class_pool={[], [], 0},
  class_ets=#{}
}).

%% callback apis

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).

init(ok) ->
  {ok, #ruby_code_server{}}.

handle_call({def_class, Class, Pid, Tuple}, _From, Config) ->
  case ets:lookup(ruby_classes, Class) of
    [] ->
      {Ref, NewConfig} = def_class(Pid, Tuple, Config),
      {reply, {ok, Ref}, NewConfig};
    [CurrentTuple] ->
      {reply, {error, CurrentTuple}, Config}
  end.

handle_call({undef_class, Ref}, _From, Config) ->
  {reply, ok, undef_class(Ref, Config)}.


%% private apis

def_class(Pid, Tuple, #ruby_code_server{class_ets=ClassEts} = Config) ->
  ets:insert(ruby_classes, Tuple),
  Ref = erlang:monitor(process, Pid),
  Mod = erlang:element(1, Tuple),
  {Ref, Config#ruby_code_server{class_ets=maps:put(Ref, Mod, ClassEts)}}.

undef_class(Ref, #ruby_code_server{class_ets=ClassEts} = Config) ->
  case maps:find(Ref, ClassEts) of
    {ok, Class} ->
      ets:delete(ruby_classes, Class),
      Config#ruby_code_server{class_ets=maps:remove(Ref, ClassEts)};
    error ->
      Config
  end.