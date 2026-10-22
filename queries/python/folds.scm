; Local fork of nvim-treesitter's python folds.scm, loaded by lua/python/folds.lua
; via vim.treesitter.query.set (a plain file here would be shadowed by the
; upstream copy BeastVim downloads into stdpath("data")/site).
;
; Difference from upstream: (function_definition) is replaced by the last
; pattern, which folds from the closing paren of the parameters (the `):` line)
; to the end of the body. Two nodes under one @fold capture are merged by
; Neovim into a single range (first start -> last end).
;
; Same idea for if/elif/else: (if_statement) is replaced by one fold per branch
; (from its `:` to the end of its block) so a branch folds on its own instead of
; the whole statement.
[
  (class_definition)
  (while_statement)
  (for_statement)
  (with_statement)
  (try_statement)
  (match_statement)
  (import_from_statement)
  (parameters)
  (argument_list)
  (parenthesized_expression)
  (generator_expression)
  (list_comprehension)
  (set_comprehension)
  (dictionary_comprehension)
  (tuple)
  (list)
  (set)
  (dictionary)
  (string)
] @fold

[
  (import_statement)
  (import_from_statement)
]+ @fold

(function_definition
  parameters: (parameters ")" @fold)
  body: (block) @fold)

(if_statement
  ":" @fold
  consequence: (block) @fold)

(elif_clause
  ":" @fold
  consequence: (block) @fold)

(else_clause
  ":" @fold
  body: (block) @fold)
