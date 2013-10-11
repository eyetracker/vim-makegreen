vim-MakeGreen
=============

This is essentially a complete rewrite of the original [vim-makegreen][] plugin.

What it does is essentially the following:
- Execute the compiler without jumping (`make!`)
- Assemble info about the errors in the quickfix buffer
- According to the info obtained in the previous step, display a colored bar and
  jump to a location

There is one call that takes flags to configure the behavior of makegreen, and
further arguments to the compiler (`$*` in `makeprg`).

    MakeGreen(<flags>, <compiler_args>)

Valid flags are:
`C` suppress context lines in the quickfix buffer
`t` always open on a new tab in case of errors
`T` never open another tab; always jump in current window
`f` jump to the first error instead of the nearest error (good for unittests)
`s` open a split with the origin buffer on a new tab
`v` open a vsplit with the origin buffer on a new tab

The bar will be displayed in diverse colors:
- green: no error
- red: one error in the current file
- darkred: multiple errors in the current file
- magenta: jump to an error in a different file

### Examples
A mapping to execute the compiler on the current file and suppress context:

    nnoremap <buffer> <F7> :call MakeGreen('C', '%')<CR>

A mapping to execute the compiler for the whole project, pass further flags to
the compiler, and always open the first error on a new tab:

    nnoremap <buffer> <S-F7> :call MakeGreen('tf', '--stop')<CR>
