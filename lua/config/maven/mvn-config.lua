local uv = vim.loop
local json = vim.fn.json_encode
local parse = vim.fn.json_decode

-- Get project root (or fallback to current working dir)
local function get_project_root()
	local cwd = vim.fn.getcwd()
	local root = cwd

	if vim.fn.isdirectory(cwd .. "/.git") == 1 then
		root = cwd
	end

	return root
end

-- Path to .nvim/maven.json in project
local function get_config_path()
	local root = get_project_root()
	local dir = root .. "/.nvim"
	local file = dir .. "/maven.json"

	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	return file
end

-- Save config to .nvim/maven.json
local function save_maven_env(env)
	local path = get_config_path()
	local file = io.open(path, "w")
	if file then
		file:write(json(env))
		file:close()
	end
end

-- Load config from .nvim/maven.json
local function load_maven_env()
	local path = get_config_path()
	local file = io.open(path, "r")
	if file then
		local contents = file:read("*a")
		file:close()
		local ok, data = pcall(parse, contents)
		if ok and type(data) == "table" then
			return data
		end
	end
	return nil
end

-- Set Maven environment from input or default
local function get_maven_env(custom_mvn, custom_settings, custom_java_home)
	local mvn_cmd = custom_mvn or "mvn"
	local settings_xml = custom_settings or "~/.m2/settings.xml"
	local java_home = custom_java_home or ""

	local env = {
		MAVEN_CMD = mvn_cmd,
		MAVEN_SETTINGS = settings_xml,
		JAVA_HOME = java_home,
	}

	-- Only save if at least one value is non-empty
	if mvn_cmd ~= "" or settings_xml ~= "" or java_home ~= "" then
		vim.g.maven_env = env
		save_maven_env(env)
	end

	return env
end

-- Load env if available
local function ensure_maven_env()
	if vim.g.maven_env then
		return vim.g.maven_env
	end
	local env = load_maven_env()
	if env then
		vim.g.maven_env = env
		return env
	end
	return get_maven_env(nil, nil)
end

-- Select and run Maven command
local function run_maven_command()
	if not package.loaded["toggleterm"] then
		require("lazy").load({ plugins = { "toggleterm.nvim" } })
	end

	local Terminal = require("toggleterm.terminal").Terminal
	local maven_env = ensure_maven_env()

	local command_list = {
		{ label = "🔧 mvn install – Build and install the project", value = "mvn install" },
		{ label = "🧹 mvn clean install – Clean and install project", value = "mvn clean install" },
		{ label = "🧪 mvn test – Run unit tests", value = "mvn test" },
		{ label = "📦 mvn package – Package the project", value = "mvn package" },
		{ label = "✅ mvn verify – Run integration tests", value = "mvn verify" },
		{ label = "🔨 mvn compile – Compile the project", value = "mvn compile" },
		{ label = "🌲 mvn dependency:tree – Show dependency tree", value = "mvn dependency:tree" },
		{ label = "📥 mvn dependency:resolve – Resolve dependencies", value = "mvn dependency:resolve" },
		{ label = "📚 mvn dependency:sources – Download sources", value = "mvn dependency:sources" },
		{
			label = "📚 mvn dependency:resolve -Dclassifier=sources – Download source jars",
			value = "mvn dependency:resolve -Dclassifier=sources",
		},
		{ label = "🚫 mvn install -DskipTests – Install without running tests", value = "mvn install -DskipTests" },
		{
			label = "🚫 mvn clean install -DskipTests – Clean & install without tests",
			value = "mvn clean install -DskipTests",
		},
		{
			label = "🧼 mvn dependency:purge-local-repository – Clear local repo cache",
			value = "mvn dependency:purge-local-repository",
		},
		{ label = "🔍 mvn dependency:analyze – Analyze dependency usage", value = "mvn dependency:analyze" },
		{
			label = "  mvn dependency:copy-dependencies -Dclassifier=sources – Download all soources",
			value = "mvn dependency:copy-dependencies -Dclassifier=sources",
		},
		{
			label = " mvn dependency:copy-dependencies -Dclassifier=javadoc – Download java docs",
			value = "mvn dependency:copy-dependencies -Dclassifier=javadoc",
		},
	}

	local labels = vim.tbl_map(function(item)
		return item.label
	end, command_list)

	vim.ui.select(labels, { prompt = "Select Maven command to run:" }, function(selected_label)
		if not selected_label then
			return
		end

		local selected = vim.iter(command_list):find(function(item)
			return item.label == selected_label
		end)

		local mvn_cmd = maven_env.MAVEN_CMD or "mvn"
		local settings_xml = maven_env.MAVEN_SETTINGS or ""
		local java_home = maven_env.JAVA_HOME or ""
		local cmd = selected.value:gsub("^mvn", mvn_cmd)

		if settings_xml ~= "" then
			cmd = cmd .. " -s " .. vim.fn.shellescape(settings_xml)
		end

		local use_java_home = java_home ~= ""
		local java_cmd = use_java_home and (java_home .. "/bin/java") or "java"

		local shell_script = ""

		if mvn_cmd == "mvn" and settings_xml == "" and java_home == "" then
			shell_script = string.format(
				[[
zsh -c '
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
echo "▶ java -version:";
java -version;
echo "";
echo "▶ mvn -version:";
mvn -version;
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
echo "▶ Running: %s";
%s;
exec zsh'
]],
				selected.value,
				selected.value
			)
		else
			shell_script = string.format(
				[[
zsh -c '
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
echo "▶ JAVA_HOME = %s";
%s
echo "";
echo "▶ java -version:";
%s -version;
echo "";
echo "▶ mvn -version:";
%s -version;
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
echo "▶ Running Maven Command: %s";
%s;
exec zsh'
]],
				java_home,
				use_java_home and ('export JAVA_HOME="' .. java_home .. '"; export PATH="$JAVA_HOME/bin:$PATH";') or "",
				java_cmd,
				mvn_cmd,
				cmd,
				cmd
			)
		end

		local term = Terminal:new({
			cmd = shell_script,
			direction = "float",
			close_on_exit = false,
			hidden = true,
			start_in_insert = true,
			float_opts = {
				border = "double",
			},
		})

		term:toggle()
	end)
end

-- Prompt to set Maven config
local function prompt_maven_config()
	local default_env = {
		MAVEN_CMD = "mvn",
		MAVEN_SETTINGS = "~/.m2/settings.xml",
		JAVA_HOME = "",
	}

	local current_env = load_maven_env() or default_env

	vim.ui.input({
		prompt = "Enter Maven binary path:",
		default = current_env.MAVEN_CMD,
	}, function(mvn_path)
		if not mvn_path then
			mvn_path = ""
		end

		vim.ui.input({
			prompt = "Enter settings.xml path:",
			default = current_env.MAVEN_SETTINGS,
		}, function(settings_path)
			if not settings_path then
				settings_path = ""
			end

			vim.ui.input({
				prompt = "Enter JAVA_HOME path:",
				default = current_env.JAVA_HOME,
			}, function(java_home)
				if not java_home then
					java_home = ""
				end
				get_maven_env(mvn_path, settings_path, java_home)
				vim.notify("✅ Maven + Java config saved in .nvim/maven.json")
			end)
		end)
	end)
end

-- Commands
vim.api.nvim_create_user_command("MvnConfig", prompt_maven_config, {})
vim.api.nvim_create_user_command("MvnRun", run_maven_command, {})

-- Shortcuts
vim.keymap.set("n", "<leader>mv", ":MvnRun<CR>", { desc = "Run Maven command" })
vim.keymap.set("n", "<leader>mc", ":MvnConfig<CR>", { desc = "Configure Maven environment" })
