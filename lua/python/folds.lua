-- Loads this plugin's queries/python/folds.scm with `vim.treesitter.query.set`.
-- A plain queries/ file would lose to the upstream folds.scm that BeastVim
-- downloads into stdpath("data")/site, which is earlier on the runtimepath.
local M = {}

---Absolute path of this plugin's folds.scm, resolved from this file's location
---(not the runtimepath, which would find the upstream copy first).
---@return string
function M.path()
	local this = debug.getinfo(1, "S").source:sub(2)
	return vim.fs.joinpath(vim.fs.dirname(this), "..", "..", "queries", "python", "folds.scm")
end

function M.setup()
	local fd = io.open(M.path(), "r")
	if not fd then
		return
	end
	local text = fd:read("*a")
	fd:close()
	vim.treesitter.query.set("python", "folds", text)
end

return M
