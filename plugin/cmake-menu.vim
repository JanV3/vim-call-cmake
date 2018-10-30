" Vim global plugin for call cmake using fzf menu
" Maintainer:	Jan valiska <jan.valiska@gmail.com>
" License:	This file is placed in the public domain.

if exists("g:loaded_call_cmake")
    finish
endif
let g:loaded_call_cmake = 1

let s:save_cpo = &cpo
set cpo&vim

if !exists("s:cmake_menu_build_configured")
    let s:cmake_menu_build_configured = 0
endif

if !exists("s:cmake_base_build_dir")
    let s:cmake_base_build_dir = 'build'
endif

if !exists("s:cmake_build_dir")
    let s:cmake_build_dir = s:cmake_base_build_dir
endif

if !exists("s:cmake_active_target")
    let s:cmake_active_target = ''
endif

if !exists("s:cmake_build_args")
    let s:cmake_build_args = '-j ' . substitute(system('getconf _NPROCESSORS_ONLN'), '\n', '', 'g')
endif

function! s:CMakeSetMakeprg()
    let l:target_command = ''
    if !empty(s:cmake_active_target)
        let l:target_command = '--target ' . s:cmake_active_target
    endif
    let &makeprg = 'cmake --build ' . s:cmake_build_dir . ' ' . l:target_command . ' -- ' . s:cmake_build_args
    let s:cmake_menu_build_configured = 1
endfunction

function! s:CMake(build_dir, ...)
    if filereadable("CMakeLists.txt")
        let s:cmake_build_dir = fnameescape(a:build_dir)
        execute '!(mkdir -p ' . s:cmake_build_dir . ' && cd ' . s:cmake_build_dir . ' && cmake ' . join(a:000) . ' ' .  getcwd() . ')'
        if v:shell_error == 0
            call s:CMakeSetMakeprg()
        endif
    else
        echoerr 'CMakeLists.txt not found'
    endif
endfunction

function! s:CMakeMenuBuild()
    if s:cmake_menu_build_configured == 0
        " echo not work from fzf sink
        " see: https://github.com/junegunn/fzf/issues/274
        echo "CMakeMenu: Project not configured"
        return
    endif

    if exists(":AsyncRun")
        :AsyncRun -program=make
    else
        :make
    endif
endfunction

function! s:CMakeMenuSelectTarget(target)
    let l:splitted = split(a:target, " ")
    if l:splitted[0] == "all"
        let s:cmake_active_target = ''
    else
        let s:cmake_active_target = l:splitted[0]
    endif
    call s:CMakeSetMakeprg()
endfunction

function! s:CMakeMenuSelectTargetMenu(...)
    let a:feed = get(a:, 1, 1)
    if s:cmake_menu_build_configured == 0
        " echo not work from fzf sink
        " see: https://github.com/junegunn/fzf/issues/274
        echo "CMakeMenu: Project not configured"
        return
    endif
    let l:targets = split(system('cmake --build ' . s:cmake_build_dir . " --target help"), "\n")
    call remove(l:targets, 0)
    call fzf#run({
                \  'source': map(l:targets, "substitute(v:val, '... ', '', '')"),
                \  'sink':    function('s:CMakeMenuSelectTarget'),
                \  'options': '-m -x +s',
                \  'down':    '40%'})
    if has("nvim") && a:feed == 1
        call feedkeys('i')
    endif
endfunction


function! s:CMakeMenuConfigureDebug()
    call s:CMake(s:cmake_base_build_dir . '-debug', '-DCMAKE_BUILD_TYPE=Debug')
endfunction

function! s:CMakeMenuConfigureRelease()
    call s:CMake(s:cmake_base_build_dir . '-release', '-DCMAKE_BUILD_TYPE=Release')
endfunction

function! s:CMakeMenuConfigure()
    call s:CMake(s:cmake_base_build_dir)
endfunction

function! s:CMakeMenuCommands()
    let l:menu_commands = {
                \ 0: function('s:CMakeMenuBuild'),
                \ 1: function('s:CMakeMenuSelectTargetMenu'),
                \ 2: function('s:CMakeMenuConfigureDebug'),
                \ 3: function('s:CMakeMenuConfigureRelease'),
                \ 4: function('s:CMakeMenuConfigure')}
    return l:menu_commands
endfunction

function! s:CMakeMenuMap()
    let l:menu_map = {0: 'Build', 1:'Select Target', 2:'Configure Debug', 3:'Configure Release', 4:'Configure'}
    return l:menu_map
endfunction

function! s:CMakeMenuList()
    let l:menu_list = []
    for [key, value] in items(s:CMakeMenuMap())
        call add(menu_list, value)
        unlet key value
    endfor
    return menu_list
endfunction

function! s:CMakeMenuAction(line)
    let l:commands = s:CMakeMenuCommands()
    for [key, value] in items(s:CMakeMenuMap())
        if value == a:line
            call l:commands[key]()
        endif
        unlet key value
    endfor
endfunction

function! s:CMakeMenu()
    if !exists('g:fzf#vim#buffers')
        echomsg "CMakeMenu: FZF is not installed"
        return
    endif
    call fzf#run({
                \  'source': s:CMakeMenuList(),
                \  'sink':    function('s:CMakeMenuAction'),
                \  'options': '-m -x +s',
                \  'down':    '40%'})
endfunction

command! CMakeMenu call s:CMakeMenu()
command! CMakeMenuBuild call s:CMakeMenuBuild()
command! CMakeMenuSelectTarget call s:CMakeMenuSelectTargetMenu(0)
command! CMakeMenuConfigure call s:CMakeMenuConfigure()
command! CMakeMenuConfigureDebug call s:CMakeMenuConfigureDebug()
command! CMakeMenuConfigureRelease call s:CMakeMenuConfigureRelease()

let &cpo = s:save_cpo
unlet s:save_cpo
