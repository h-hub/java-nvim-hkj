return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"nvimtools/none-ls-extras.nvim",
	},
	config = function()
		local fn = vim.fn

		-- Define paths
		local config_dir = fn.stdpath("config") .. "/lua/config/checkstyle-config"
		local checkstyle_jar = config_dir .. "/checkstyle.jar"
		local google_checks = config_dir .. "/google_checks.xml"

		-- Create folder if missing
		fn.mkdir(config_dir, "p")

		-- Download Checkstyle jar if not present
		if fn.filereadable(checkstyle_jar) == 0 then
			local jar_url =
				"https://github.com/checkstyle/checkstyle/releases/download/checkstyle-10.25.0/checkstyle-10.25.0-all.jar"
			fn.system({ "curl", "-L", "-o", checkstyle_jar, jar_url })
		end

		-- Download Google Checks XML if not present
		if fn.filereadable(google_checks) == 0 then
			local xml_url =
				"https://raw.githubusercontent.com/checkstyle/checkstyle/master/src/main/resources/google_checks.xml"
			fn.system({ "curl", "-L", "-o", google_checks, xml_url })
		end
		-- get access to the none-ls functions
		local null_ls = require("null-ls")

		local h = require("null-ls.helpers")

		local maven_diagnostics = {
			method = null_ls.methods.DIAGNOSTICS,
			filetypes = { "java" },
			generator = h.generator_factory({
				command = vim.fn.expand("~/.sdkman/candidates/maven/current/bin/mvn"),
				args = { "compile", "-T", "1C" },
				cwd = function()
					return vim.fn.expand("~/codes/java/property-crm")
				end,
				env = {
					PATH = os.getenv("PATH"),
					JAVA_HOME = os.getenv("JAVA_HOME"),
					M2_HOME = os.getenv("M2_HOME"),
				},
				format = "line",
				from_stderr = false,
				to_temp_file = false,
				timeout = 10000,
				check_exit_code = function(code)
					return code == 0 or code == 1
				end,
				on_output = function(params)
					local line = params

					local buffer_id = vim.api.nvim_get_current_buf()
					local filename = vim.api.nvim_buf_get_name(buffer_id)

					-- Parse the line
					local file, line_num, col, msg = string.match(line, "%[ERROR%]%s+(.-):%[(%d+),(%d+)%]%s+(.+)")
					if file and line_num and col and msg then
						-- Only include diagnostics for the current buffer
						if vim.fn.trim(file) == filename then
							local diagnostics = {
								filename = vim.fn.trim(file),
								row = tonumber(line_num),
								col = tonumber(col),
								message = msg,
								severity = 1, -- 1 = ERROR
								source = "maven",
							}
							return diagnostics
						end
					end
				end,
			}),
		}

		local checkstyle_diagnostic = {
			filetypes = { "java" },
			command = "java",
			args = {
				"-jar",
				checkstyle_jar,
				"-c",
				google_checks,
				"$filename",
			},
			format = "line",
			to_temp_file = false,
			from_stderr = false,
			on_output = function(params)
				local diagnostics = {}
				for line in vim.gsplit(params.output, "\n") do
					local severity_text, filename, line_num, col_num, message =
						string.match(line, "^%[(%u+)%]%s+(.+):(%d+):(%d+):%s+(.+)%s+%[.-%]$")
					if severity_text and filename and line_num and col_num and message then
						local severity = 3 -- default info
						if severity_text == "error" then
							severity = 1
						elseif severity_text == "warn" or severity_text == "warning" then
							severity = 2
						elseif severity_text == "info" then
							severity = 3
						elseif severity_text == "hint" then
							severity = 4
						end

						table.insert(diagnostics, {
							row = tonumber(line_num),
							col = tonumber(col_num),
							end_col = tonumber(col_num) + 1,
							message = message,
							severity = severity,
							source = "checkstyle",
							bufnr = params.bufnr,
						})
					end
				end
				return diagnostics
			end,
		}

		vim.cmd("let g:null_ls_debug = v:true")
		-- require("null-ls").setup({ debug = true })

		-- run the setup function for none-ls to setup our different formatters
		null_ls.setup({
			debug = true,
			sources = {
				-- setup prettier to format languages that are not lua
				null_ls.builtins.formatting.prettier,

				-- KtLint for Kotlin files ONLY
				null_ls.builtins.formatting.ktlint.with({
					filetypes = { "kotlin" },
				}),

				-- diagnostics (linter)
				null_ls.builtins.diagnostics.ktlint.with({ filetypes = { "kotlin" } }),

				maven_diagnostics,

				null_ls.builtins.diagnostics.checkstyle.with(checkstyle_diagnostic),
			},
			on_attach = function(client, bufnr)
				vim.notify("null-ls attached to buffer " .. bufnr, vim.log.levels.INFO)
			end,
		})

		-- set up a vim motion for <Space> + c + f to automatically format our code based on which langauge server is active
		vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { desc = "[C]ode [F]ormat" })
	end,
}
