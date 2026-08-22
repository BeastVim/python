local M = {}

function M.setup()
	local missing = {}
	if not Lsp then
		table.insert(missing, "Lsp")
	end
	if not Treesitter then
		table.insert(missing, "Treesitter")
	end
	if not Mason then
		table.insert(missing, "Mason")
	end
	if #missing > 0 then
		vim.notify(
			"python requires BeastVim's global " .. table.concat(missing, ", ") .. " (this plugin only works inside the BeastVim ecosystem)",
			vim.log.levels.ERROR,
			{ title = "python" }
		)
		return
	end

	Treesitter.ensure_parser("python")

	Mason.ensure_package({ "basedpyright" }, function()
		Lsp.register("basedpyright", {
			cmd = function(dispatchers)
				local cmd = "basedpyright-langserver"
				if vim.fn.executable(cmd) ~= 1 then
					cmd = Mason.bin(cmd)
				end
				return vim.lsp.rpc.start({ cmd, "--stdio" }, dispatchers)
			end,
			filetypes = { "python", "toml" },
			root_markers = {
				".git",
				"pyproject.toml",
				"setup.py",
				"setup.cfg",
				"requirements.txt",
				"Pipfile",
				"pyrightconfig.json",
			},
			settings = {
				basedpyright = {
					disableOrganizeImports = true, -- Using Ruff
					analysis = {
						typeCheckingMode = "off",
						ignore = { "*" },
					},
				},
			},
			on_attach = function(client, _)
				-- `ruff` does not support hover as well as `basedpyright`
				client.server_capabilities.hoverProvider = true
			end,
		})
	end)

	-- ruff covers three separate roles here: LSP diagnostics/actions, and
	-- (via conform) the `ruff_format` formatter -- all backed by the same
	-- `ruff` binary, so one Mason.ensure_package gates all of it.
	Mason.ensure_package({ "ruff" }, function()
		Lsp.register("ruff", {
			cmd = function(dispatchers)
				local cmd = "ruff"
				if vim.fn.executable(cmd) ~= 1 then
					cmd = Mason.bin(cmd)
				end
				return vim.lsp.rpc.start({ cmd, "server" }, dispatchers)
			end,
			filetypes = { "python" },
			root_markers = { "pyproject.toml", ".ruff.toml", ".git" },
			cmd_env = { RUFF_TRACE = "messages" },
			init_options = {
				settings = {
					logLevel = "error",
          lint = {
            ignore = { "B008", "I001" }
          }
				},
			},
			keys = {
				{
					"<leader>lo",
					function()
            M.organize_imports(vim.api.nvim_get_current_buf())
					end,
					desc = "Organize Imports",
					cond = "textDocument/codeAction",
				},
			},
		})

		-- conform.nvim's `formatters`/`formatters_by_ft` are plain mutable
		-- tables it exposes for exactly this -- see lua_ls for the same
		-- pattern with stylua. `require("conform")` lazy-loads conform itself
		-- via its own module trigger.
		require("conform").formatters.ruff_format = {
			args = { "format", "--line-length", "120", "--force-exclude", "--stdin-filename", "$FILENAME", "-" },
		}
		require("conform").formatters_by_ft.python = { "ruff_format" }
	end)
end

-- Per-project-root formatter list cache, so repeated saves in the
-- same project don't re-stat/re-read config file every time
local root_formatter_cache = {}

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

local function contains(content, pattern)
  return content ~= nil and content:find(pattern, 1, true) ~= nil
end


-- Picks which formatters to run for a project root. 
-- - ruff: has a dedicated ruff config, or opts into '[tool.ruff.format]'
-- - self-declared black/isort: settings live in pyproject.toml/.isort.cfg,
--   so conform's stock 'black'/'isort' formatters can auto-discover them
-- - Makefile-only black/isort: no config file to discover, only a shared
--   Makefile recipe (`black --skip-string-normalization --line-length 120`,
--   `isort --profile black --line-length 120 --force-sort-within-sections`)
local function detect_python_formatters(root)
  local pyproject = read_file(root .. "/pyproject.toml")

  if vim.uv.fs_stat(root .. "/ruff.toml") or vim.uv.fs_stat(root .. "/.ruff.toml") or contains(pyproject, "[tool.ruff.format]") then
    return { "ruff_format" }
  end

  local isort_cfg = read_file(root .. "/.isort.cfg")
  local is_black_project = contains(pyproject, "[tool.black]")
    or contains(pyproject, "[tool.isort]")
    or isort_cfg ~= nil
    or vim.uv.fs_stat(root .. "/.flake8") ~= nil
  if not is_black_project then
    return { "ruff_format" }
  end

  local isort_self_sufficient = contains(isort_cfg, "profile") or contains(pyproject, "[tool.isort]") and contains(pyproject, "profile")
  local black_self_sufficient = contains(pyproject, "[tool.black]")

  return {
    isort_self_sufficient and "isort",
    black_self_sufficient and "black",
  }
end

local FORMATTER_MARKERS = { "pyproject.toml", ".isort.cfg", ".flake8", "ruff.toml" }

function M.pick_python_formatters(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  -- Walk up from the buffer looking for the nearest formatter config,
  -- not just .git root
  local root = vim.fs.root(filename, FORMATTER_MARKERS) or vim.fs.root(filename, ".git") or vim.fn.getcwd()
  local formatters = root_formatter_cache[root]
  if not formatters then
    formatters = detect_python_formatters(root)
    root_formatter_cache[root] = formatters
  end
  return formatters
end

-- `<leader>lo` organize imports by using whichever import-sorter the project
-- actually uses (mirror pick_python_formatters)
function M.organize_imports(bufnr)
  local formatters = M.pick_python_formatters(bufnr)
  local isort_formatter = vim.tbl_contains(formatters, "isort") and "isort"

  if isort_formatter then
    require("conform").format({ bufnr = bufnr, formatters = { isort_formatter } })
    return
  end

  vim.lsp.buf.code_action({
    apply = true,
    context = { only = { "source.organizeImports" }, diagnostics = {} }
  })
end

return M
