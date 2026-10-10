-- =========================================================================
-- Test: python plugin fold query (queries/python/folds.scm via python.folds)
-- =========================================================================
-- Run as: nvim --clean --headless -l tests/test-folds.lua
-- Exit code: 0 = PASS, 1 = FAIL
--
-- Checks the raw vim.treesitter.foldexpr() levels so fold boundaries are
-- asserted, not just nesting depth. Key behaviour: a function with a
-- multi-line signature folds from the line holding the closing paren (the
-- `):` line) to the end of the body, and does not merge with a preceding
-- decorator fold. Needs the python parser from stdpath('data')/site of
-- BeastVim; skipped (exit 0) when it is not installed.
-- =========================================================================

local site = vim.fn.expand("~/.local/share/BeastVim/site")
vim.opt.runtimepath:append(site) -- parser + upstream folds.scm (the one we must override)
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

if not pcall(vim.treesitter.language.add, "python") then
	io.write("SKIP: python parser not installed\n")
	os.exit(0)
end

require("python.folds").setup()

local passed = 0
local failed = 0

---@param lines string[]
---@return string[] levels foldexpr value per line
local function fold_levels(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "python"
	vim.api.nvim_set_current_buf(buf)
	vim.treesitter.start(buf, "python")
	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
	vim.treesitter.get_parser(buf, "python"):parse(true)
	local levels = {}
	for lnum = 1, #lines do
		levels[lnum] = vim.treesitter.foldexpr(lnum)
	end
	vim.api.nvim_buf_delete(buf, { force = true })
	return levels
end

---@param name string
---@param lines string[]
---@param expected string[]
local function check(name, lines, expected)
	local got = table.concat(fold_levels(lines), " ")
	local want = table.concat(expected, " ")
	if got == want then
		passed = passed + 1
		io.write("  PASS: " .. name .. "\n")
	else
		failed = failed + 1
		io.write(("  FAIL: %s\n    got:      %s\n    expected: %s\n"):format(name, got, want))
	end
end

io.write("\n== Multi-line signature with decorator ==\n")
check("decorator, params and body fold separately", {
	"@pytest.mark.parametrize(", -- 1: decorator fold 1-5
	'    "a, b",',
	"    CASES.values(),",
	"    ids=CASES.keys(),",
	")",
	"def test_x(", -- 6: params fold 6-9
	"    a: int,",
	"    b: str,",
	"    n: Node,",
	"):", -- 10: body fold 10-15
	"    graph = build(n)",
	"",
	"    assert graph",
	"    for x in graph:",
	"        assert x",
}, { ">1", "1", "1", "1", "1", ">1", "1", "1", "1", ">1", "1", "1", "1", ">2", "2" })

io.write("\n== Single-line signature ==\n")
check("method folds from the def line", {
	"class A:", -- 1: class fold 1-7
	"    def f(self, a):", -- 2: body fold 2-4
	"        x = 1",
	"        y = 2",
	"",
	"    def g(self) -> int:", -- 6: body fold 6-7
	"        return 1",
}, { ">1", ">2", "2", "2", "1", ">2", "2" })

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
os.exit(failed > 0 and 1 or 0)
