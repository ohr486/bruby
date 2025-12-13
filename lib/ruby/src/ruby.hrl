%% @doc Ruby tokenizer state record
%% Used to maintain tokenizer state including warnings during lexical analysis
-record(ruby_tokenizer, {
  warnings = []  % List of warnings accumulated during tokenization
}).
