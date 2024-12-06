---@diagnostic disable:undefined-global

local function nmap(shortcut, command)
  vim.keymap.set('n', shortcut, command, { silent = true })
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.clipboard = 'unnamedplus'

vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true

vim.opt.number = true
vim.opt.ruler = true
vim.opt.hidden = true
vim.opt.wrap = true

nmap('j', 'gj')
nmap('k', 'gk')

nmap('<C-j>', ':cn<CR>')
nmap('<C-k>', ':cp<CR>')
nmap('<C-q>', ':ccl<CR>')

nmap('Q', ':tabclose<CR>')

vim.opt.hlsearch = true
nmap('<space>', ':nohlsearch<CR>')

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

local function config_solarized()
  if vim.fn.has('termguicolors') == 1 then
    vim.opt.termguicolors = true
  end
end

local function config_telescope()
  local builtin = require('telescope.builtin')
  nmap('<C-p>', builtin.find_files)
  nmap('<C-u>', builtin.live_grep)
end

local function config_barbar()
  nmap('<C-y>', ':BufferPick<CR>')
  nmap('bd', ':BufferClose<CR>')
  nmap('bq', ':BufferClose!<CR>')
  nmap('bD', ':BufferCloseAllButCurrent<CR>')
  nmap('bu', ':BufferRestore<CR>')
  nmap('bn', ':BufferNext<CR>')
  nmap('bN', ':BufferMoveNext<CR>')
  nmap('bp', ':BufferPrevious<CR>')
  nmap('bP', ':BufferMovePrevious<CR>')
  for i = 1,9 do
    nmap(string.format('b%d', i), string.format(':BufferGoto %d<CR>', i))
  end
  nmap('b0', ':BufferLast<CR>')
end

local function config_neotree()
  require('neo-tree').setup(
  { close_if_last_window = true,
    filesystem =
      { filtered_items =
        { always_show = { ".gitignore" } } },
    hijack_netrw_behavior = "open_current",
    window =
    { mappings =
      { ["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } }, }, }, })
  nmap('<C-t>', ':Neotree reveal<CR>')
end

local function config_coc()
  vim.opt.backup = false
  vim.opt.writebackup = false

  vim.opt.updatetime = 300

  vim.opt.signcolumn = "yes"

  local opts = {silent = true, noremap = true, expr = true, replace_keycodes = false}

  function _G.check_back_space()
    local col = vim.fn.col('.') - 1
    return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') ~= nil
  end
  vim.keymap.set('i', '<tab>', 'coc#pum#visible() ? coc#pum#confirm() : v:lua.check_back_space() ? "<TAB>" : coc#refresh()', opts)

  vim.keymap.set('i', '<C-space>', 'coc#refresh()', {silent = true, expr = true})

  nmap('<C-d>', ':CocDiagnostics<CR>')
  nmap('gd', '<Plug>(coc-definition)')
  nmap('gy', '<Plug>(coc-type-definition)')
  nmap('gi', '<Plug>(coc-implementation)')
  nmap('gr', '<Plug>(coc-references)')

  function _G.show_docs()
    local cw = vim.fn.expand('<cword>')
    if vim.fn.index({'vim', 'help'}, vim.bo.filetype) >= 0 then
      vim.api.nvim_command('h ' .. cw)
    elseif vim.api.nvim_eval('coc#rpc#ready()') then
      vim.fn.CocActionAsync('doHover')
    else
      vim.api.nvim_command('!' .. vim.o.keywordprg .. ' ' .. cw)
    end
  end
  nmap('K', '<CMD>lua _G.show_docs()<CR>')
end

local auto_dark_mode_opts =
{ update_interval = 1000,
  set_dark_mode = function()
    vim.api.nvim_set_option_value("background", "dark", {})
    vim.cmd("colorscheme solarized8_high")
  end,
  set_light_mode = function()
    vim.api.nvim_set_option_value("background", "light", {})
    vim.cmd("colorscheme solarized8_high")
  end }

require('lazy').setup(
{
  { 'lifepillar/vim-solarized8',
    branch = 'neovim',
    lazy = false, -- load during startup, since it's our colorscheme
    priority = 1000, -- load first
    config = config_solarized, },
  { 'f-person/auto-dark-mode.nvim',
    opts = auto_dark_mode_opts, },

  { 'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies =
    { 'nvim-lua/plenary.nvim' },
    config = config_telescope },
  { 'romgrk/barbar.nvim',
    dependencies =
    { 'nvim-tree/nvim-web-devicons' },
    config = config_barbar },
  { 'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
      '3rd/image.nvim' },
    config = config_neotree, },
  { 'neoclide/coc.nvim',
    branch = 'release',
    config = config_coc },

  { 'sindrets/diffview.nvim',
    config = function()
      nmap('<C-g>', ':DiffviewOpen<CR>')
    end, },
  { 'airblade/vim-gitgutter' },

  { 'tpope/vim-sleuth', },
  { 'strega-nil/gbz80-vim-syntax' },
  { 'tadmccorkle/markdown.nvim',
    config = function ()
      require("markdown").setup()
    end },
  { 'mrcjkb/rustaceanvim',
    version = '^5',
    lazy = false } },
{ ui =
  { icons =
    { cmd = '⌘',
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
      lazy = '💤 ' } } })
