-module(ruby).
-behaviour(application).

-export([start/2, stop/1]).

%% Callbacks

start(_Type, _Args) -> ok.

stop(_) -> ok.

