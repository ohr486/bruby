%% @doc Utility functions for bruby
%% Provides command line argument parsing and other utilities
-module(utils).

-export([check_args/1]).

%% ============================================================================
%% Public API
%% ============================================================================

%% @doc Check and parse command line arguments
-spec check_args([string()]) -> [string()].
check_args(Args) ->
  parse_args(Args).

%% ============================================================================
%% Private functions
%% ============================================================================

%% @doc Parse a list of arguments
-spec parse_args([string()]) -> [string()].
parse_args([]) ->
  [];
parse_args([Arg | RestArgs]) ->
  [parse_arg(Arg) | parse_args(RestArgs)].

%% @doc Parse a single argument and handle special flags
-spec parse_arg(string()) -> string() | no_return().
parse_arg("--version") ->
  io:put_chars("this ruby is alpha version.\n"),
  erlang:halt(0);
parse_arg(Arg) ->
  Arg.

