set laststatus=2
set number
set wrap
set linebreak
set expandtab
set shiftwidth=2
set softtabstop=2
set clipboard=unnamedplus
execute pathogen#infect()
filetype plugin indent on
syntax on
let NERDTreeShowHidden=1
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
autocmd vimenter * if !argc() | NERDTree | endif
map <F7> mzgg=G`z<CR>
map <F5> :NERDTreeToggle<CR>
set paste

"disable insert key replace toggle:
function s:ForbidReplace()
    if v:insertmode isnot# 'i'
        call feedkeys("\<Insert>", "n")
    endif
endfunction
augroup ForbidReplaceMode
    autocmd!
    autocmd InsertEnter  * call s:ForbidReplace()
    autocmd InsertChange * call s:ForbidReplace()
augroup END

"tabs
nnoremap <C-t> :tabnew<Space>
inoremap <C-t> <Esc>:tabnew<Space>

"Tab Navigation
nnoremap <S-h> gT
nnoremap <S-l> gt

"may change from system to system
set background=dark
colorscheme solarized
set fillchars=""


