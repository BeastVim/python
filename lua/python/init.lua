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
			root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
			cmd_env = { RUFF_TRACE = "messages" },
			init_options = {
				settings = {
					logLevel = "error",
				},
			},
			keys = {
				{
					"<leader>lo",
					function()
						vim.lsp.buf.code_action({
							apply = true,
							context = { only = { "source.organizeImports" }, diagnostics = {} },
						})
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

return M
