call plug#begin(stdpath('data') . '/plugged')

Plug 'rust-lang/rust.vim'
Plug 'fholgado/minibufexpl.vim'
Plug 'tpope/vim-sleuth'
Plug 'PProvost/vim-ps1'
Plug 'phanviet/vim-monokai-pro'
Plug 'sheerun/vim-polyglot'

call plug#end()

set tabstop=2
set shiftwidth=2
set noexpandtab
set autoindent

set number
set ruler
set hidden
set wrap

nnoremap j gj
nnoremap k gk

set hlsearch
nnoremap <CR> :nohlsearch<CR>

set nofoldenable
set foldnestmax=4
nnoremap <Space> za

nnoremap <C-y> :MBEFocus<CR>
let g:miniBufExplBuffersNeeded=1

set ffs=unix,dos
set encoding=utf-8
set fileencoding=utf-8
set autoread
