-- Setup our JDTLS server any time we open up a java file
vim.cmd([[
    augroup jdtls_lsp
        autocmd!
        autocmd FileType java lua require'config.jdtls'.setup_jdtls()
    augroup end
]])

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	callback = function()
		local win = vim.api.nvim_get_current_win()
		local config = vim.api.nvim_win_get_config(win)
		-- Skip floating windows (including Telescope)
		if config.relative == "" then
			vim.cmd("normal! zz")
		end
	end,
})
