-- Store last shell command output
local last_shell_output = { lines = {}, command = "" }

-- Function to create and update popup buffer
local function create_popup_buffer()
	local buf = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer
	vim.api.nvim_buf_set_option(buf, "filetype", "sh") -- For syntax highlighting
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile") -- No file association
	vim.api.nvim_buf_set_option(buf, "modifiable", true) -- Allow updates
	vim.api.nvim_buf_set_option(buf, "wrap", true) -- Enable line wrapping
	vim.api.nvim_buf_set_option(buf, "linebreak", true) -- Wrap at word boundaries
	vim.api.nvim_buf_set_option(buf, "breakindent", true) -- Indent wrapped lines

	-- Calculate popup size (80% of window width/height)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Create popup window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	-- Set window options to ensure wrapping
	vim.api.nvim_win_set_option(win, "wrap", true)
	vim.api.nvim_win_set_option(win, "linebreak", true)
	vim.api.nvim_win_set_option(win, "breakindent", true)

	-- Close popup with <Esc> or q
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })

	return buf, win
end

-- Function to execute shell command or show last output
function _G.show_shell_output(cmd, reuse_last)
	local buf, win = create_popup_buffer()
	local display_lines = reuse_last and { "Command: " .. last_shell_output.command } or { "Command: " .. cmd }
	local lines = reuse_last and last_shell_output.lines or {}

	if reuse_last and #last_shell_output.lines > 0 then
		-- Display last output
		vim.list_extend(display_lines, last_shell_output.lines)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		return
	end

	-- Update last_shell_output
	last_shell_output.command = cmd
	last_shell_output.lines = lines

	-- Set initial buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

	-- Start shell command with jobstart
	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = false, -- Stream output
		on_stdout = function(_, data)
			if data then
				-- Filter out empty strings and append new output
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(lines, line)
						table.insert(display_lines, line)
					end
				end
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
				-- Scroll to bottom
				vim.api.nvim_win_set_cursor(win, { #display_lines, 0 })
			end
		end,
		on_stderr = function(_, data)
			if data then
				-- Filter out empty strings and append stderr
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(lines, line)
						table.insert(display_lines, line)
					end
				end
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
				vim.api.nvim_win_set_cursor(win, { #display_lines, 0 })
			end
		end,
		on_exit = function()
			-- Make buffer read-only after command completes
			vim.api.nvim_buf_set_option(buf, "modifiable", false)
			last_shell_output.lines = lines -- Update stored output
		end,
	})

	if job_id <= 0 then
		vim.notify("Failed to start command: " .. cmd, vim.log.levels.ERROR)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Error: Failed to execute command" })
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
	end
end

-- Command to execute new shell command
vim.api.nvim_create_user_command("ShellPopup", function(opts)
	show_shell_output(opts.args, false)
end, { nargs = 1 })

-- Command to show last shell output
vim.api.nvim_create_user_command("ShellPopupLast", function()
	if #last_shell_output.lines == 0 then
		vim.notify("No previous shell output available", vim.log.levels.WARN)
		return
	end
	show_shell_output("", true)
end, {})
