%% @doc Rubyトークナイザー（字句解析器）
%%
%% このモジュールはRubyソースコードを字句解析してトークン列に変換します。
%% トークナイザーはパーサーの前段階として動作し、文字列を意味のある
%% トークン（キーワード、識別子、演算子、リテラルなど）に分割します。
%%
%% 主な機能：
%% - 識別子とキーワードの認識
%% - 数値リテラル（整数）の解析
%% - 文字列リテラル（ダブル/シングルクォート）の解析
%% - 演算子と区切り文字の認識
%% - コメントのスキップ
%% - 行番号とカラム位置の追跡
%% - エラーと警告の報告
%%
%% サポートするトークン：
%% - キーワード: def, end, class, if, elsif, else, while, until, return, yield, etc.
%% - 演算子: +, -, *, /, ==, !=, <=, >=, &&, ||, &, |, ^, ~, <<, >>, etc.
%% - リテラル: 整数、文字列、true, false, nil
%% - 識別子: 変数名、メソッド名（?, ! を含む）
%%
%% 使用例：
%% ```
%% Code = "def hello(name)\n  puts name\nend",
%% {ok, Tokens, FinalLine} = ruby_tokenizer:tokenize(Code),
%% % Tokens = [{tDEF, 1}, {tIDENTIFIER, 1, "hello"}, {'(', 1}, ...]
%% '''
%%
%% @author bruby development team
%% @version 1.0.0

-module(ruby_tokenizer).
-include("ruby.hrl").
-export([tokenize/1, tokenize/3, tokenize/4]).

%% @doc トークナイズのエントリーポイント（文字列のみ）
%%
%% Rubyソースコードの文字列をトークン列に変換します。
%% 行番号は1から開始し、初期状態のトークナイザーを使用します。
%%
%% パラメータ：
%%   - String: Rubyソースコード（文字列またはバイナリ）
%%
%% 戻り値：
%%   - {ok, Tokens, FinalLine}: 成功時、トークンリストと最終行番号
%%   - {error, Error, Line}: エラー時、エラー情報と行番号
%%
%% 使用例：
%% ```
%% {ok, Tokens, _} = ruby_tokenizer:tokenize("x = 42"),
%% % Tokens = [{tIDENTIFIER, 1, "x"}, {'=', 1}, {tINTEGER, 1, 42}]
%% '''
-spec tokenize(string() | binary()) -> {ok, list(), pos_integer()} | {error, tuple(), pos_integer()}.
tokenize(String) when is_list(String) ->
  tokenize(String, 1, #ruby_tokenizer{});
tokenize(String) when is_binary(String) ->
  tokenize(binary_to_list(String), 1, #ruby_tokenizer{}).

%% @doc トークナイズのエントリーポイント（行番号と状態指定）
%%
%% 開始行番号とトークナイザー状態を指定してトークナイズを実行します。
%% カラム位置は1から開始されます。
%% 複数行のコードを段階的に処理する場合に使用します。
%%
%% パラメータ：
%%   - String: Rubyソースコード
%%   - Line: 開始行番号（正の整数）
%%   - Opts: トークナイザー状態（#ruby_tokenizer{}レコード）
%%
%% 戻り値：
%%   - {ok, Tokens, FinalLine}: 成功時、トークンリストと最終行番号
%%   - {error, Error, Line}: エラー時、エラー情報と行番号
-spec tokenize(string(), pos_integer(), #ruby_tokenizer{}) -> {ok, list(), pos_integer()} | {error, tuple(), pos_integer()}.
tokenize(String, Line, Opts) ->
  tokenize(String, Line, 1, Opts).

%% @doc トークナイズのメイン処理（行番号、カラム位置、状態指定）
%%
%% 開始行番号、カラム位置、トークナイザー状態を指定してトークナイズを実行します。
%% これは内部的に使用される最も詳細なエントリーポイントです。
%%
%% パラメータ：
%%   - String: Rubyソースコード
%%   - Line: 開始行番号（正の整数）
%%   - Column: 開始カラム位置（正の整数）
%%   - Scope: トークナイザー状態（#ruby_tokenizer{}レコード）
%%
%% 戻り値：
%%   - {ok, Tokens, FinalLine}: 成功時、トークンリストと最終行番号
%%   - {error, Error, Line}: エラー時、エラー情報と行番号
-spec tokenize(string(), pos_integer(), pos_integer(), #ruby_tokenizer{}) -> {ok, list(), pos_integer()} | {error, tuple(), pos_integer()}.
tokenize(String, Line, Column, #ruby_tokenizer{} = Scope) ->
  tokenize(String, Line, Column, Scope, []).

%% @doc 内部トークナイズ処理
%% 空文字列の場合、トークンリストを逆順にして返す
tokenize([], Line, _Column, _Scope, Tokens) ->
  {ok, lists:reverse(Tokens), Line};

%% 空白文字をスキップ
tokenize([C | Rest], Line, Column, Scope, Tokens) when C =:= $\s; C =:= $\t ->
  tokenize(Rest, Line, Column + 1, Scope, Tokens);

%% 改行文字を処理
tokenize([$\r, $\n | Rest], Line, _Column, Scope, Tokens) ->
  tokenize(Rest, Line + 1, 1, Scope, Tokens);
tokenize([$\n | Rest], Line, _Column, Scope, Tokens) ->
  tokenize(Rest, Line + 1, 1, Scope, Tokens);
tokenize([$\r | Rest], Line, _Column, Scope, Tokens) ->
  tokenize(Rest, Line + 1, 1, Scope, Tokens);

%% コメント（#から行末まで）
tokenize([$# | Rest], Line, Column, Scope, Tokens) ->
  {_, NewRest, NewLine} = skip_comment(Rest, Line),
  tokenize(NewRest, NewLine, Column, Scope, Tokens);

%% 識別子とキーワード
tokenize([C | _] = String, Line, Column, Scope, Tokens)
    when (C >= $a andalso C =< $z) orelse
         (C >= $A andalso C =< $Z) orelse
         C =:= $_ ->
  {Identifier, Rest} = scan_identifier(String, []),
  Token = identifier_or_keyword(Identifier, Line),
  tokenize(Rest, Line, Column + length(Identifier), Scope, [Token | Tokens]);

%% 数値リテラル
tokenize([C | _] = String, Line, Column, Scope, Tokens) when C >= $0 andalso C =< $9 ->
  {Number, Rest} = scan_number(String, []),
  Token = {tINTEGER, Line, list_to_integer(Number)},
  tokenize(Rest, Line, Column + length(Number), Scope, [Token | Tokens]);

%% 文字列リテラル（ダブルクォート）
tokenize([$" | Rest], Line, Column, Scope, Tokens) ->
  case scan_string(Rest, [], $") of
    {ok, String, NewRest} ->
      Token = {tSTRING, Line, String},
      tokenize(NewRest, Line, Column + length(String) + 2, Scope, [Token | Tokens]);
    {error, Reason} ->
      {error, {Line, ?MODULE, Reason}, Line}
  end;

%% 文字列リテラル（シングルクォート）
tokenize([$' | Rest], Line, Column, Scope, Tokens) ->
  case scan_string(Rest, [], $') of
    {ok, String, NewRest} ->
      Token = {tSTRING, Line, String},
      tokenize(NewRest, Line, Column + length(String) + 2, Scope, [Token | Tokens]);
    {error, Reason} ->
      {error, {Line, ?MODULE, Reason}, Line}
  end;

%% 2文字演算子
tokenize("==" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tEQ, Line} | Tokens]);
tokenize("!=" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tNE, Line} | Tokens]);
tokenize("<=" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tLE, Line} | Tokens]);
tokenize(">=" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tGE, Line} | Tokens]);
tokenize("&&" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tAND, Line} | Tokens]);
tokenize("||" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tOR, Line} | Tokens]);
tokenize("<<" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tLSHIFT, Line} | Tokens]);
tokenize(">>" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tRSHIFT, Line} | Tokens]);
tokenize("=>" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tASSOC, Line} | Tokens]);

%% 1文字演算子と区切り文字
tokenize([$+ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'+', Line} | Tokens]);
tokenize([$- | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'-', Line} | Tokens]);
tokenize([$* | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'*', Line} | Tokens]);
tokenize([$/ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'/', Line} | Tokens]);
tokenize([$% | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'%', Line} | Tokens]);
tokenize([$= | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'=', Line} | Tokens]);
tokenize([$< | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'<', Line} | Tokens]);
tokenize([$> | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'>', Line} | Tokens]);
tokenize([$! | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'!', Line} | Tokens]);
tokenize([$( | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'(', Line} | Tokens]);
tokenize([$) | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{')', Line} | Tokens]);
tokenize([$[ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'[', Line} | Tokens]);
tokenize([$] | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{']', Line} | Tokens]);
tokenize([${ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'{', Line} | Tokens]);
tokenize([$} | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'}', Line} | Tokens]);
tokenize([$, | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{',', Line} | Tokens]);
tokenize([$. | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'.', Line} | Tokens]);
tokenize([$: | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{':', Line} | Tokens]);
tokenize([$; | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{';', Line} | Tokens]);
tokenize([$& | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'&', Line} | Tokens]);
tokenize([$| | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'|', Line} | Tokens]);
tokenize([$^ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'^', Line} | Tokens]);
tokenize([$~ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'~', Line} | Tokens]);

%% 未知の文字
tokenize([C | Rest], Line, Column, Scope, Tokens) ->
  Warning = {Line, ?MODULE, {unknown_character, C}},
  NewScope = Scope#ruby_tokenizer{warnings = [Warning | Scope#ruby_tokenizer.warnings]},
  tokenize(Rest, Line, Column + 1, NewScope, Tokens).

%% ========================================
%% ヘルパー関数
%% ========================================

%% @doc コメントをスキップ（行末まで）
%%
%% Rubyのコメント（#から行末まで）をスキップします。
%% 改行文字（\n, \r\n, \r）まで読み飛ばし、残りの文字列と更新された行番号を返します。
%%
%% パラメータ：
%%   - String: 処理する文字列（#の直後から）
%%   - Line: 現在の行番号
%%
%% 戻り値：
%%   - {[], RemainingString, UpdatedLine}: 空リスト、残りの文字列、更新された行番号
%%
%% 使用例：
%% ```
%% {[], "code", 2} = skip_comment("comment text\ncode", 1).
%% '''
-spec skip_comment(string(), pos_integer()) -> {[], string(), pos_integer()}.
skip_comment([], Line) ->
  {[], [], Line};
skip_comment([$\n | Rest], Line) ->
  {[], Rest, Line + 1};
skip_comment([$\r, $\n | Rest], Line) ->
  {[], Rest, Line + 1};
skip_comment([$\r | Rest], Line) ->
  {[], Rest, Line + 1};
skip_comment([_ | Rest], Line) ->
  skip_comment(Rest, Line).

%% @doc 識別子をスキャン
%%
%% Ruby識別子（変数名、メソッド名など）をスキャンします。
%% 識別子は英字、数字、アンダースコア、?、!で構成されます。
%% 先頭は英字またはアンダースコアでなければなりません。
%%
%% パラメータ：
%%   - String: スキャンする文字列
%%   - Acc: アキュムレータ（逆順で文字を蓄積）
%%
%% 戻り値：
%%   - {Identifier, RemainingString}: 識別子文字列と残りの文字列
%%
%% 使用例：
%% ```
%% {"foo_bar?", " = 42"} = scan_identifier("foo_bar? = 42", []).
%% '''
-spec scan_identifier(string(), string()) -> {string(), string()}.
scan_identifier([], Acc) ->
  {lists:reverse(Acc), []};
scan_identifier([C | Rest], Acc)
    when (C >= $a andalso C =< $z) orelse
         (C >= $A andalso C =< $Z) orelse
         (C >= $0 andalso C =< $9) orelse
         C =:= $_ orelse C =:= $? orelse C =:= $! ->
  scan_identifier(Rest, [C | Acc]);
scan_identifier(String, Acc) ->
  {lists:reverse(Acc), String}.

%% @doc 数値をスキャン（整数のみ）
%%
%% 整数リテラルをスキャンします。
%% 現在は10進数の整数のみをサポートしています。
%% 浮動小数点数、8進数、16進数、2進数は将来の拡張予定です。
%%
%% パラメータ：
%%   - String: スキャンする文字列
%%   - Acc: アキュムレータ（逆順で数字を蓄積）
%%
%% 戻り値：
%%   - {NumberString, RemainingString}: 数値文字列と残りの文字列
%%
%% 使用例：
%% ```
%% {"42", " + 10"} = scan_number("42 + 10", []).
%% '''
-spec scan_number(string(), string()) -> {string(), string()}.
scan_number([], Acc) ->
  {lists:reverse(Acc), []};
scan_number([C | Rest], Acc) when C >= $0 andalso C =< $9 ->
  scan_number(Rest, [C | Acc]);
scan_number(String, Acc) ->
  {lists:reverse(Acc), String}.

%% @doc 文字列をスキャン
%%
%% 文字列リテラルをスキャンします。
%% ダブルクォート（"）またはシングルクォート（'）で囲まれた文字列を処理します。
%% エスケープシーケンス（\n, \t, \r, \\, \", \'）をサポートします。
%%
%% パラメータ：
%%   - String: スキャンする文字列（開始クォートの直後から）
%%   - Acc: アキュムレータ（逆順で文字を蓄積）
%%   - Quote: 終了を示すクォート文字（$" または $'）
%%
%% 戻り値：
%%   - {ok, StringContent, RemainingString}: 成功時、文字列内容と残りの文字列
%%   - {error, unterminated_string}: 文字列が終了していない場合
%%
%% 使用例：
%% ```
%% {ok, "hello", " world"} = scan_string("hello\" world", [], $").
%% {ok, "tab\there", ""} = scan_string("tab\\there'", [], $').
%% '''
-spec scan_string(string(), string(), char()) -> {ok, string(), string()} | {error, atom()}.
scan_string([], _Acc, _Quote) ->
  {error, unterminated_string};
scan_string([Quote | Rest], Acc, Quote) ->
  {ok, lists:reverse(Acc), Rest};
scan_string([$\\, C | Rest], Acc, Quote) ->
  % エスケープ文字の処理
  EscapedChar = case C of
    $n -> $\n;
    $t -> $\t;
    $r -> $\r;
    $\\ -> $\\;
    $" -> $";
    $' -> $';
    _ -> C
  end,
  scan_string(Rest, [EscapedChar | Acc], Quote);
scan_string([C | Rest], Acc, Quote) ->
  scan_string(Rest, [C | Acc], Quote).

%% @doc 識別子がキーワードかどうかを判定
%%
%% スキャンされた識別子がRubyのキーワードかどうかを判定します。
%% キーワードの場合は対応するトークンタグを返し、
%% そうでない場合は tIDENTIFIER トークンを返します。
%%
%% パラメータ：
%%   - Identifier: 識別子文字列
%%   - Line: 行番号
%%
%% 戻り値：
%%   - {TokenTag, Line}: キーワードの場合
%%   - {tIDENTIFIER, Line, Identifier}: 識別子の場合
%%
%% サポートするキーワード：
%%   def, end, class, module, if, elsif, else, unless, while, until, for, in, do,
%%   return, yield, break, next, redo, retry, rescue, ensure, raise, begin,
%%   case, when, then, and, or, not, true, false, nil, self, super, proc,
%%   lambda, block_given?
-spec identifier_or_keyword(string(), pos_integer()) -> {atom(), pos_integer()} | {atom(), pos_integer(), string()}.
identifier_or_keyword("def", Line) -> {tDEF, Line};
identifier_or_keyword("end", Line) -> {tEND, Line};
identifier_or_keyword("class", Line) -> {tCLASS, Line};
identifier_or_keyword("module", Line) -> {tMODULE, Line};
identifier_or_keyword("if", Line) -> {tIF, Line};
identifier_or_keyword("elsif", Line) -> {tELSIF, Line};
identifier_or_keyword("else", Line) -> {tELSE, Line};
identifier_or_keyword("unless", Line) -> {tUNLESS, Line};
identifier_or_keyword("while", Line) -> {tWHILE, Line};
identifier_or_keyword("until", Line) -> {tUNTIL, Line};
identifier_or_keyword("for", Line) -> {tFOR, Line};
identifier_or_keyword("in", Line) -> {tIN, Line};
identifier_or_keyword("do", Line) -> {tDO, Line};
identifier_or_keyword("return", Line) -> {tRETURN, Line};
identifier_or_keyword("yield", Line) -> {tYIELD, Line};
identifier_or_keyword("break", Line) -> {tBREAK, Line};
identifier_or_keyword("next", Line) -> {tNEXT, Line};
identifier_or_keyword("redo", Line) -> {tREDO, Line};
identifier_or_keyword("retry", Line) -> {tRETRY, Line};
identifier_or_keyword("rescue", Line) -> {tRESCUE, Line};
identifier_or_keyword("ensure", Line) -> {tENSURE, Line};
identifier_or_keyword("raise", Line) -> {tRAISE, Line};
identifier_or_keyword("begin", Line) -> {tBEGIN, Line};
identifier_or_keyword("case", Line) -> {tCASE, Line};
identifier_or_keyword("when", Line) -> {tWHEN, Line};
identifier_or_keyword("then", Line) -> {tTHEN, Line};
identifier_or_keyword("and", Line) -> {tAND, Line};
identifier_or_keyword("or", Line) -> {tOR, Line};
identifier_or_keyword("not", Line) -> {tNOT, Line};
identifier_or_keyword("true", Line) -> {tTRUE, Line};
identifier_or_keyword("false", Line) -> {tFALSE, Line};
identifier_or_keyword("nil", Line) -> {tNIL, Line};
identifier_or_keyword("self", Line) -> {tSELF, Line};
identifier_or_keyword("super", Line) -> {tSUPER, Line};
identifier_or_keyword("proc", Line) -> {tPROC, Line};
identifier_or_keyword("lambda", Line) -> {tLAMBDA, Line};
identifier_or_keyword("block_given?", Line) -> {tBLOCK_GIVEN, Line};
identifier_or_keyword(Identifier, Line) -> {tIDENTIFIER, Line, Identifier}.

