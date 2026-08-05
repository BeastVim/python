# python

`basedpyright` + `ruff` LSP configuration for [BeastVim](https://github.com/loctvl842/BeastVim),
plus `ruff_format` registered with conform.nvim as the Python formatter.
Built only for the BeastVim ecosystem — it calls `Lsp.register` and
`Mason.ensure_package`, provided globally by BeastVim's `beast.libs.lsp` and
`beast.libs.mason`. Not usable standalone.

## Install

```lua
{
  name = "python",
  src = gh("BeastVim/python"),
  lazy = { filetype = "python" },
  config = function() require("python").setup() end,
}
```
