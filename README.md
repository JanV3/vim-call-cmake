vim-cmake-menu
==============

Show menu(using fzf) withc can be used to configure project(default/debug/release) and select active compilation target.
After configuring/selecting target `makeprg` variable is set with appropriate build command.

Build can be started from cmake menu or by calling command `:CMakeMenuBuild`. If AsyncRun plugin is installed, build will be started asynchronously. Otherwise plain `:make` will be invoked.

If project is not configured, it can be configured from cmake menu.

Selecting of target is possible only after project configuration(default/debug/release) is done.

## Installation

If you don't have a preferred installation method, I recommend
installing [plug.vim](https://github.com/junegunn/vim-plug).

And then install plugin by placing:

`Plug 'JanValiska/vim-cmake-menu'`

## Usage

Set current directory which contains root CMakeLists.txt and run `:CMakeMenu`.

All commands in cmake menu is also available as standalone commands:

- `:CMakeMenuBuild`
- `:CMakeMenuConfigure`
- `:CMakeMenuConfigureDebug`
- `:CMakeMenuConfigureRelease`
- `:CMakeMenuSelectTarget`

## Usefull keybinding

I used this keymaps:

`autocmd FileType c,cpp,objc noremap <F10> :CMakeMenu<CR>`
`autocmd FileType c,cpp,objc noremap <F9> :CMakeMenuBuild<CR>`

## Todo

- add persistent configuration of configured projects
- autodetect CMakeLists.txt on directory change
- propt user to configure unconfigured project
- add support to multiple "opened" projects
- add support for cmake -E server(list of targets)
- add support to run debugger from menu on selected target

## License

As Vim itself. See `:help license`.
