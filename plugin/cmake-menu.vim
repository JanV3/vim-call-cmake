" Vim global plugin for call cmake using fzf menu
" Maintainer:	Jan valiska <jan.valiska@gmail.com>
" License:	This file is placed in the public domain.

if exists("g:loaded_call_cmake")
    finish
endif
let g:loaded_call_cmake = 1

let s:save_cpo = &cpo
set cpo&vim

if !exists("g:cmake_menu_autodetect_build_folder")
    let g:cmake_menu_autodetect_build_folder = 1
endif

if !exists("g:cmake_menu_autodetect_prefered_type")
    let g:cmake_menu_autodetect_prefered_type = 'debug'
endif

if !exists("g:cmake_menu_autoconfigure")
    let g:cmake_menu_autoconfigure = 0
endif

if !exists("g:cmake_menu_autoconfigure_type")
    let g:cmake_menu_autoconfigure_type = 'debug'
endif

if !exists("s:cmake_menu_build_configured")
    let s:cmake_menu_build_configured = 0
endif

if !exists("s:cmake_base_build_dir")
    let s:cmake_base_build_dir = 'build'
endif

if !exists("s:cmake_debug_build_dir")
    let s:cmake_debug_build_dir = s:cmake_base_build_dir . '-debug'
endif

if !exists("s:cmake_release_build_dir")
    let s:cmake_release_build_dir = s:cmake_base_build_dir . '-release'
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

function! g:CMakeDone()
    if g:asyncrun_code == 0
        call s:CMakeSetMakeprg()
    endif
endfunction

function! s:CMake(...)
    if filereadable("CMakeLists.txt")
        let l:command = 'mkdir -p ' . s:cmake_build_dir . ' && cd ' . s:cmake_build_dir . ' && cmake ' . join(a:000) . ' ' .  getcwd()

        if exists(":AsyncRun")
            exec "AsyncRun -post=call\\ g:CMakeDone() " . l:command
        else
            execute '!(' . l:command . ')'
            if v:shell_error == 0
                call s:CMakeSetMakeprg()
            endif
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

function! s:CMakeMenuSetBuildDir(build_dir)
    let s:cmake_build_dir = fnameescape(a:build_dir)
    call s:CMakeSetMakeprg()
endfunction

function! s:CMakeMenuConfigure(type)
    if empty(a:type)
        call s:CMakeMenuSetBuildDir(s:cmake_base_build_dir)
        call s:CMake()
    endif
    if a:type == 'debug'
        call s:CMakeMenuSetBuildDir(s:cmake_debug_build_dir)
        call s:CMake('-DCMAKE_BUILD_TYPE=Debug')
    endif
    if a:type == 'release'
        call s:CMakeMenuSetBuildDir(s:cmake_release_build_dir)
        call s:CMake('-DCMAKE_BUILD_TYPE=Release')
    endif
endfunction

function! s:CMakeMenuCommands()
    let l:menu_commands = {
                \ 0: function('s:CMakeMenuBuild'),
                \ 1: function('s:CMakeMenuSelectTargetMenu'),
                \ 2: function('s:CMakeMenuConfigure', ['debug']),
                \ 3: function('s:CMakeMenuConfigure', ['release']),
                \ 4: function('s:CMakeMenuConfigure', [''])}
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

function s:CMakeMenuAutodetectBuildFolder()
    if !filereadable("CMakeLists.txt")
        return
    endif

    let s:cmake_active_target = ''
    let s:cmake_menu_build_configured=0
    let l:found = {'default': 0, 'debug': 0, 'release': 0}
    if isdirectory(s:cmake_base_build_dir)
        let l:found['default']=1
    endif
    if isdirectory(s:cmake_debug_build_dir)
        let l:found['debug']=1
    endif
    if isdirectory(s:cmake_release_build_dir)
        let l:found['release']=1
    endif

    if get(l:found, g:cmake_menu_autodetect_prefered_type, 0) == 1
        call s:CMakeMenuSetBuildDir(s:cmake_base_build_dir . '-' . g:cmake_menu_autodetect_prefered_type)
    elseif l:found['default'] == 1
        call s:CMakeMenuSetBuildDir(s:cmake_base_build_dir)
    elseif l:found['debug'] == 1
        call s:CMakeMenuSetBuildDir(s:cmake_debug_build_dir)
    elseif l:found['release'] == 1
        call s:CMakeMenuSetBuildDir(s:cmake_release_build_dir)
        return
    elseif g:cmake_menu_autoconfigure == 1
        call s:CMakeMenuSetBuildDir(s:cmake_base_build_dir . '-' . g:cmake_menu_autoconfigure_type)
        call s:CMake()
    endif
endfunction

function! s:CMakeMenuDirectoryChanged(event)
    call s:CMakeMenuAutodetectBuildFolder()
endfunction

function! g:CMakeMenuStatus()
    if filereadable("CMakeLists.txt")
        if s:cmake_menu_build_configured == 1
            if s:cmake_active_target == ''
                return "CMake: ALL"
            else
                return "CMake: " . s:cmake_active_target
            endif
        else
            return "CMake: unconfigured"
        endif
    else
        return ''
    endif
endfunction

command! CMakeMenu call s:CMakeMenu()
command! CMakeMenuBuild call s:CMakeMenuBuild()
command! CMakeMenuSelectTarget call s:CMakeMenuSelectTargetMenu(0)
command! CMakeMenuConfigure call s:CMakeMenuConfigure('')
command! CMakeMenuConfigureDebug call s:CMakeMenuConfigure('debug')
command! CMakeMenuConfigureRelease call s:CMakeMenuConfigure('release')

if(g:cmake_menu_autodetect_build_folder == 1)
    autocmd User RooterChDir call s:CMakeMenuDirectoryChanged(v:event)
    call s:CMakeMenuAutodetectBuildFolder()
endif

let &cpo = s:save_cpo
unlet s:save_cpo
