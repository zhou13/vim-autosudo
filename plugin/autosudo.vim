" autosudo.vim          "E45: 'readonly' option is set" is the past!
" Author:               Yichao Zhou (broken.zhou AT gmail)
" Version:              0.1
" ---------------------------------------------------------------------

if &cp || exists("g:loaded_autosudo")
    finish
endif
let g:loaded_autosudo = 1

if !exists("g:autosudo_autodir")
    let g:autosudo_autodir = 1
endif
if !exists("g:autosudo_reset_readonly")
    let g:autosudo_reset_readonly = 1
endif
if !exists("g:autosudo_always_noreadonly")
    let g:autosudo_always_noreadonly = 1
endif

let s:hassudo = executable("sudo")

function! s:Writeable(fname)
    let dname = fnamemodify(a:fname, ':p:h')
    let readable = filereadable(a:fname)
    let writeable = filewritable(a:fname) == 1
    let dirwritable = filewritable(dname) == 2

    " File exists and writeable
    if writeable == v:true
        return v:true
    endif
    " Directory exists and writeable, file not exists
    if readable == v:false && dirwritable == v:true
        return v:true
    endif
    " File exists but not writeable
    if readable == v:true && writeable == v:false
        return v:false
    endif
    " Directory exists but not writeable
    if isdirectory(dname) && dirwritable == v:false
        return v:false
    endif
    " Try to create dir
    if g:autosudo_autodir
        call system('mkdir -p ' . shellescape(dname))
        return v:shell_error == 0
    else
        return v:false
    endif
endfunction

function! s:SudoWriteable(fname)
    let dname = fnamemodify(a:fname, ':p:h')
    return isdirectory(dname)
endfunction

function! s:SudoWrite(fname)
    let fname = a:fname ? fnamemodify(a:fname, ':p') : expand("%:p")

    if s:hassudo && s:SudoWriteable(fname)
        if a:fname == ""
            " Save current file
            execute "SudoWrite"
            if g:autosudo_reset_readonly
                set noreadonly
            endif
        else
            " Save to other file
            silent! execute "write !sudo tee " . fnameescape(fname) . " > /dev/null"
            let &modified = v:shell_error
        endif
    endif
endfunction

function! s:AutoWrite(fname)
    let fname = a:fname ? fnamemodify(a:fname, ':p') : expand("%:p")

    if s:Writeable(fname)
        execute "write! " . fnameescape(fname)
    else
        call s:SudoWrite(a:fname)
    endif
endfunction

function! s:AutoUpdate(fname)
    if &modified == v:false
        return
    endif

    let fname = a:fname ? fnamemodify(a:fname, ':p') : expand("%:p")

    " If file is writable, directly update it
    if s:Writeable(fname)
        execute "update! " . fnameescape(fname)
    else
        call s:SudoWrite(a:fname)
    endif
endfunction

command! -bar -bang -complete=file -nargs=? AutoWrite  call s:AutoWrite(<q-args>)
command! -bar -bang -complete=file -nargs=? AutoUpdate call s:AutoUpdate(<q-args>)

nmap <silent> <Plug>(autosudo-write)  :AutoWrite<CR>
nmap <silent> <Plug>(autosudo-update) :AutoUpdate<CR>

if g:autosudo_always_noreadonly
    autocmd BufReadPost * if &readonly && s:SudoWriteable(expand("%:p")) | set noreadonly | endif
endif
