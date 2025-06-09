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
		local methods = require("null-ls.methods")

		local DIAGNOSTICS = methods.internal.DIAGNOSTICS

		local maven_diagnostics = h.make_builtin({
			name = "maven_compile",
			meta = {
				url = "https://maven.apache.org/plugins/maven-compiler-plugin/",
				description = "Uses mvn compile to detect Java compile errors.",
			},
			method = require("null-ls.methods").internal.DIAGNOSTICS_ON_OPEN,
			filetypes = { "java" },
			generator_opts = {
				command = vim.fn.expand("~/.sdkman/candidates/maven/current/bin/mvn"),
				args = { "compile" },
				cwd = function()
					return vim.fn.expand("~/codes/java/property-crm")
				end,
				env = {
					PATH = os.getenv("PATH"),
					JAVA_HOME = os.getenv("JAVA_HOME"),
					M2_HOME = os.getenv("M2_HOME"),
				},
				format = "raw",
				from_stderr = true,
				to_temp_file = false,
				on_output = function(params)
					local diagnostics = {}
					local output = params.output

					for line in vim.gsplit(output, "\n") do
						-- if line:find("BUILD FAILURE") then
						-- 	-- print("found BUil")
						-- 	print(vim.inspect(diagnostics))
						-- 	return diagnostics
						-- end
						local file, line_num, col, msg = string.match(line, "%[ERROR%]%s+(.-):%[(%d+),(%d+)%]%s+(.+)")

						if file and line_num and col and msg then
							-- print("File:", file)
							-- print("Line:", line_num)
							-- print("Col:", col)
							-- print("Msg:", msg)

							table.insert(diagnostics, {
								filename = vim.fn.trim(file),
								row = tonumber(line_num),
								col = tonumber(col),
								message = msg,
								severity = 1, -- 1 = ERROR
								source = "maven",
								-- bufnr = params.bufnr,
							})
						end
						-- rint(line)
						-- print("loop running")
					end

					return diagnostics
				end,
			},
			factory = h.generator_factory,
		})

		vim.cmd("let g:null_ls_debug = v:true")
		-- require("null-ls").setup({ debug = true })

		-- run the setup function for none-ls to setup our different formatters
		null_ls.setup({
			debug = true,
			sources = {
				-- setup lua formatter
				-- null_ls.builtins.formatting.stylua,
				-- -- setup eslint linter for javascript
				-- require("none-ls.diagnostics.eslint_d"),
				-- -- setup prettier to format languages that are not lua
				-- null_ls.builtins.formatting.prettier,
				--
				-- -- KtLint for Kotlin files ONLY
				-- null_ls.builtins.formatting.ktlint.with({
				-- 	filetypes = { "kotlin" },
				-- }),
				--
				-- -- diagnostics (linter)
				-- null_ls.builtins.diagnostics.ktlint.with({ filetypes = { "kotlin" } }),

				maven_diagnostics,

				-- null_ls.builtins.diagnostics.checkstyle.with({
				-- 	filetypes = { "java" }, -- ✅ Restrict to Java only
				-- 	command = "java",
				-- 	args = {
				-- 		"-jar",
				-- 		checkstyle_jar,
				-- 		"-c",
				-- 		google_checks,
				-- 		"$FILENAME",
				-- 	},
				-- 	format = "line",
				-- 	to_temp_file = true,
				-- 	from_stderr = false,
				-- 	on_output = function(params)
				-- 		local diagnostics = {}
				-- 		for line in vim.gsplit(params.output, "\n") do
				-- 			local severity_text, filename, line_num, col_num, message =
				-- 				string.match(line, "^%[(%u+)%]%s+(.+):(%d+):(%d+):%s+(.+)%s+%[.-%]$")
				-- 			if severity_text and filename and line_num and col_num and message then
				-- 				local severity = 3 -- default INFO
				-- 				if severity_text == "ERROR" then
				-- 					severity = 1
				-- 				elseif severity_text == "WARN" or severity_text == "WARNING" then
				-- 					severity = 2
				-- 				elseif severity_text == "INFO" then
				-- 					severity = 3
				-- 				elseif severity_text == "HINT" then
				-- 					severity = 4
				-- 				end
				--
				-- 				table.insert(diagnostics, {
				-- 					row = tonumber(line_num),
				-- 					col = tonumber(col_num),
				-- 					end_col = tonumber(col_num) + 1,
				-- 					message = message,
				-- 					severity = severity,
				-- 					source = "checkstyle",
				-- 					bufnr = params.bufnr,
				-- 				})
				-- 			end
				-- 		end
				-- 		return diagnostics
				-- 	end,
				-- }),
			},
		})

		-- set up a vim motion for <Space> + c + f to automatically format our code based on which langauge server is active
		vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { desc = "[C]ode [F]ormat" })
	end,
}
