function nmap(shortcut, command)
	vim.keymap.set('n', shortcut, command, { silent = true })
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = false
vim.opt.autoindent = true

vim.opt.number = true
vim.opt.ruler = true
vim.opt.hidden = true
vim.opt.wrap = true

nmap('j', 'gj')
nmap('k', 'gk')

vim.opt.hlsearch = true
nmap(' ', ':nohlsearch<CR>')

vim.opt.foldenable = false
vim.opt.foldnestmax = 4

vim.opt.ffs = { 'unix' , 'dos' }
vim.opt.encoding = 'utf-8'
vim.opt.fileencoding = 'utf-8'
vim.opt.autoread = true

vim.cmd('autocmd BufRead,BufNewFile *.z80 set filetype=gbz80')

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		'git',
		'clone',
		'--filter=blob:none',
		'https://github.com/folke/lazy.nvim.git',
		'--branch=stable', -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
	{
		'lifepillar/vim-solarized8',
		branch = 'neovim',
		lazy = false, -- load during startup, since it's our colorscheme
		priority = 1000, -- load first
		config = function()
			if vim.fn.has('termguicolors') == 1 then
				vim.opt.termguicolors = true
			end

			vim.opt.background = 'light'
			vim.cmd('colorscheme solarized8_high')
		end
	},
	{
		'ctrlpvim/ctrlp.vim'
	},
	{
		'strega-nil/gbz80-vim-syntax'
	},
	{
		'airblade/vim-gitgutter'
	},
	{
		'romgrk/barbar.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
		config = function()
			nmap('<C-y>', ':BufferPick<CR>')

			nmap('bq', ':BufferClose<CR>')
			nmap('bd', ':BufferClose<CR>')
			nmap('bQ', ':BufferClose!<CR>')
			nmap('bu', ':BufferRestore<CR>')
			nmap('bn', ':BufferNext<CR>')
			nmap('bN', ':BufferMoveNext<CR>')
			nmap('bp', ':BufferPrevious<CR>')
			nmap('bP', ':BufferMovePrevious<CR>')

			nmap('b1', ':BufferGoto 1<CR>')
			nmap('b2', ':BufferGoto 2<CR>')
			nmap('b3', ':BufferGoto 3<CR>')
			nmap('b4', ':BufferGoto 4<CR>')
			nmap('b5', ':BufferGoto 5<CR>')
			nmap('b6', ':BufferGoto 6<CR>')
			nmap('b7', ':BufferGoto 7<CR>')
			nmap('b8', ':BufferGoto 8<CR>')
			nmap('b9', ':BufferGoto 9<CR>')
			nmap('b0', ':BufferLast<CR>')
		end
	},
	{
		'nvim-neo-tree/neo-tree.nvim',
		dependencies = {
			'nvim-lua/plenary.nvim',
			'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
      '3rd/image.nvim',
    },
		config = function()
			require('neo-tree').setup({
				close_if_last_window = true,
				filesystem = {
					filtered_items = {
						always_show = {
							".gitignore"
						}
					}
				},
				follow_current_file = true,
				hijack_netrw_behavior = "open_current",
				window = {
					mappings = {
						["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
					}
				},
			})
			nmap('<C-t>', ':Neotree<CR>')
		end
	},
	{
		'mattia72/vim-ripgrep'
	},
	{
		'sheerun/vim-polyglot'
	}
},
{
	ui = {
		icons = {
			cmd = '⌘',
			config = '🛠',
			event = '📅',
			ft = '📂',
			init = '⚙',
			keys = '🗝',
			plugin = '🔌',
			runtime = '💻',
			require = '🌙',
			source = '📄',
			start = '🚀',
			task = '📌',
			lazy = '💤 ',
		},
	},
})
