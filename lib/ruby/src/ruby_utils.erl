-module(ruby_utils).

-export([check_args/1]).

check_args(Args) ->
  parse_args(Args).

parse_args([]) -> [];
parse_args([Arg | RestArgs]) ->
  [parse_arg(Arg)] ++ parse_args(RestArgs).

parse_arg(Arg) ->
  case Arg of
    "--version" ->
      io:put_chars("this ruby is alpha version.\n"),
      erlang:halt(0);
    Else ->
      Else
  end.

