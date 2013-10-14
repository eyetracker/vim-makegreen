vim-MakeGreen
=============

This adds more jump and color configuration to the original [vim-makegreen][]
plugin.

Unfortunately, I copied it into my configuration and it grew and grew until
I though that it is too good to be private.  I copied it back and so this is
kind of a rewrite without much history.

What it does is essentially the following:

- Execute the compiler without jumping (`make!`)
- Assemble info about the errors in the quickfix buffer
- Display a colored bar and jump to an error location

There is one public function that takes flags to influence its behavior, and
further arguments to the compiler (`$*` in `makeprg`).

    MakeGreen(<flags>, <compiler_args>)

### Flags
Combine any of the flags in this section into a string and pass it as first
argument to `MakeGreen()`.

- `C` suppress context (non-error) lines in the quickfix buffer
- `f` jump to the first error instead of the nearest error (eg: unittest versus
  compilation).  By default the error in the current buffer that is the nearest
  to the cursor position will be jumped to.
- `J` do not jump at all and do not open a new tab unless explicitly requested
  (execute tests from the System-Under-Test without opening the test file)

Further flags concern the opening of a new tab.  The default behavior is useful
if you use quickfix tabs as special throwaway tabs:  A new tab will be opened
if the target error is in another buffer and the current tab does not have a
quickfix window open.

- `t` always open on a new tab in case of errors and no quickfix window is open
- `T` never open another tab; always jump inside the current window
- `s` open a split with the origin buffer when opening a new tab
- `v` open a vsplit with the origin buffer when opening a new tab

### The Bar
The bar will be displayed in diverse colors:

- green: no error
- red/white: one error in the current file
- red/yellow: further errors -- possibly in different files
- magenta/white: one error in a different file
- magenta/yellow: multiple errors, target error in a different file

You can override these default colors from your configuration if you define
the following highlight-groups:

    MakeGreenNoErrorBar
    MakeGreenOneErrorBar
    MakeGreenMultipleErrorBar
    MakeGreenDifferentBufferErrorBar
    MakeGreenDifferentBufferMultipleErrorBar

### Examples
A mapping to execute the compiler on the current file and suppress context:

    nnoremap <buffer> <F7> :call MakeGreen('C', '%')<CR>

A mapping to execute the compiler for the whole project, pass further flags to
the compiler, and always open the first error in a new tab:

    nnoremap <buffer> <S-F7> :call MakeGreen('tf', '--stop')<CR>

  [vim-makegreen]: https://github.com/reinh/vim-makegreen
