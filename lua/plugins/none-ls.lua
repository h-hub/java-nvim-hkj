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
		local google_format_jar = config_dir .. "/google_format.jar"

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

		if fn.filereadable(google_format_jar) == 0 then
			local jar_url =
				"https://github.com/google/google-java-format/releases/download/v1.27.0/google-java-format-1.27.0-all-deps.jar"
			fn.system({ "curl", "-L", "-o", google_format_jar, jar_url })
		end

		-- get access to the none-ls functions
		local null_ls = require("null-ls")

		local h = require("null-ls.helpers")

		local json = vim.fn.json_decode(vim.fn.readfile(vim.fn.expand(".nvim/maven.json")))

		local maven_cmd = json.MAVEN_CMD ~= "" and json.MAVEN_CMD or "mvn"
		local java_home = json.JAVA_HOME ~= "" and json.JAVA_HOME or os.getenv("JAVA_HOME")

		local maven_diagnostics = {
			method = null_ls.methods.DIAGNOSTICS,
			filetypes = { "java" },
			generator = h.generator_factory({
				command = maven_cmd,
				args = { "compile", "-T", "1C" },
				cwd = function()
					return vim.fn.getcwd()
				end,
				env = {
					JAVA_HOME = java_home,
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
			args = function(params)
				return {
					"-jar",
					checkstyle_jar, -- Ensure this variable points to the Checkstyle JAR path
					"-c",
					google_checks, -- Ensure this variable points to the Google Checks XML file
					params.bufname, -- Use params.bufname to get the file path
				}
			end,
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
							-- filename = filename,
							row = tonumber(line_num),
							col = tonumber(col_num),
							end_col = tonumber(col_num) + 1,
							message = message,
							severity = severity,
							source = "checkstyle",
							-- bufnr = params.bufnr,
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
				null_ls.builtins.formatting.google_java_format.with({
					command = "java",
					args = {
						"-jar",
						google_format_jar,
						"$FILENAME",
					},
				}),
			},
			on_attach = function(bufnr)
				vim.notify("null-ls attached to buffer ", vim.log.levels.INFO)
			end,
		})

		vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format file" })
	end,
}
