-- lazy.nvim
return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"ktlint", -- installs ktlint CLI
				},
				auto_update = false,
				run_on_start = true,
			})
		end,
		dependencies = {
			"WhoIsSethDaniel/mason-tool-installer",
		},
	},
	{

		"dense-analysis/ale",
		enabled = false,
		ft = { "kotlin" },
		config = function()
			vim.g.ale_linters = {
				kotlin = { "ktlint" },
			}
			vim.g.ale_fixers = {
				kotlin = { "ktlint" },
			}
			vim.g.ale_fix_on_save = 1
		end,
	},
}
