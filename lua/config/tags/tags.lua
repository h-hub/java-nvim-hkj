local function generate_jar_tags()
	vim.notify("Generating tags from project and source jars, this may take a while...", vim.log.levels.WARN)

	vim.defer_fn(function()
		local cmd = [[
      mkdir -p .tags/jar-sources
      for jar in target/dependency/*-sources.jar; do
        unzip -oq "$jar" -d .tags/jar-sources
      done
      ctags -R --languages=Java,Kotlin --exclude=.tags/jar-sources -f .tags/project.tags .
      cd .tags
      ctags -R --languages=Java,Kotlin -f jar-sources.tags jar-sources
    ]]

		local result = vim.fn.system(cmd)

		if vim.v.shell_error == 0 then
			-- Replace the 'tags' option with fresh list
			vim.opt.tags = { ".tags/project.tags", ".tags/jar-sources.tags" }

			vim.notify("Tags generated for project and jars. Tags path updated.", vim.log.levels.INFO)
		else
			vim.notify("Tag generation failed:\n" .. result, vim.log.levels.ERROR)
		end
	end, 2000)
end

vim.opt.tags = { ".tags/project.tags", ".tags/jar-sources.tags" }
vim.api.nvim_create_user_command("GenJarTags", generate_jar_tags, {})

vim.keymap.set("n", "<leader>tg", "<cmd>GenJarTags<CR>", { desc = "Generate tags for project and jars" })

vim.keymap.set("n", "<leader>td", function()
	local word = vim.fn.expand("<cword>")
	-- jump to tag normally
	vim.cmd("tag " .. word)

	-- Make buffer read-only & nomodifiable
	vim.bo.readonly = true
	vim.bo.modifiable = false

	-- Disable autocommands for this buffer (prevents formatters, etc.)
	-- by clearing all autocommands for current buffer
	vim.api.nvim_clear_autocmds({ buffer = 0 })

	-- Optional: Disable LSP client(s) attached to this buffer if any
	local clients = vim.lsp.get_active_clients({ bufnr = 0 })
	for _, client in ipairs(clients) do
		client.stop()
	end

	print("Opened tag file in read-only mode, plugins disabled")
end, { desc = "Go to tag under cursor (read-only, plugins disabled)" })

vim.keymap.set("n", "<leader>ts", "<cmd>tselect <cword><CR>", { desc = "Select tag match" })
