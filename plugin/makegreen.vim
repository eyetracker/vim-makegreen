" plugin/makegreen.vim
" Author:   Rein Henrichs <reinh@reinh.com>
"           Dirk Wallenstein <halsmit@t-online.de>
" License:  MIT License

" Install this file as plugin/makegreen.vim.

" ============================================================================

" Exit quickly when:
" - this plugin was already loaded (or disabled)
" - when 'compatible' is set
if &cp || exists("g:makegreen_loaded") && g:makegreen_loaded
  finish
endif
let g:makegreen_loaded = 1

if !hlexists('MakeGreenNoErrorBar')
    hi MakeGreenNoErrorBar
            \ term=reverse ctermfg=white ctermbg=green
            \ guifg=white guibg=green
endif
if !hlexists('MakeGreenOneErrorBar')
    hi MakeGreenOneErrorBar
            \ term=reverse ctermfg=white ctermbg=red
            \ guifg=white guibg=red
endif
if !hlexists('MakeGreenMultipleErrorBar')
    hi MakeGreenMultipleErrorBar
            \ term=reverse ctermfg=yellow ctermbg=red
            \ gui=bold guifg=yellow guibg=red
endif
if !hlexists('MakeGreenDifferentBufferErrorBar')
    hi MakeGreenDifferentBufferErrorBar
            \ term=reverse ctermfg=white ctermbg=magenta
            \ guifg=white guibg=magenta
endif

" ---

" record info about one quickfix error
let s:ErrorInfo = {}

fun! s:ErrorInfo.New(qf_line, error) dict
    " Compute further attributes
    let is_in_current_buffer = a:error['bufnr'] == bufnr('%')
    let line_distance = self._Init_GetLineDistance(a:error,
                \ is_in_current_buffer)

    " Create and return a new instance
    let new_instance = copy(self)
    let new_instance.qf_line = a:qf_line
    let new_instance.error = a:error
    let new_instance.is_in_current_buffer = is_in_current_buffer
    let new_instance.line_distance = line_distance
    return new_instance
endfun

fun! s:ErrorInfo._Init_GetLineDistance(error, is_in_current_buffer)
    " Return the number of lines from the error to the current line.  If the
    " error is not in the current buffer, return -1.
    if a:is_in_current_buffer
        return abs(line('.') - a:error['lnum'])
    else
        return -1
    endif
endfun

" ---

" record info about all quickfix errors
let s:QfErrors = {}

fun! s:QfErrors.New() dict
    " Compute attributes
    let error_list = self._Init_GetErrorList()
    let current_buf_first_error = self._Init_GetFirstErrorInCurrentBuffer(
                \ error_list)
    let current_buf_nearest_error = self._Init_GetNearestErrorInCurrentBuffer(
                \ error_list)
    let best_error = self._Init_GetBestError(error_list,
                \ current_buf_nearest_error)

    " Create and return a new instance
    let new_instance = copy(self)
    let new_instance.error_list = error_list
    let new_instance.current_buf_first_error = current_buf_first_error
    let new_instance.current_buf_nearest_error = current_buf_nearest_error
    let new_instance.best_error = best_error
    return new_instance
endfun

fun! s:QfErrors._Init_GetErrorList()
    " Return a list of ErrorInfo instances for each valid error in the quickfix
    " buffer list.
    let error_list = []
    let qf_line_counter = 0
    for line_record in getqflist()
        let qf_line_counter += 1
        if !line_record['valid']
            continue
        endif
        call add(error_list, s:ErrorInfo.New(qf_line_counter, line_record))
    endfor
    return error_list
endfun

fun! s:QfErrors._Init_GetFirstErrorInCurrentBuffer(error_list)
    " Return an empty dictionary if there is no error in the current buffer.
    for error_info in a:error_list
        if error_info.is_in_current_buffer
            return error_info
        endif
    endfor
    return {}
endfun

fun! s:QfErrors._Init_GetNearestErrorInCurrentBuffer(error_list)
    " Return an empty dictionary if there is no error in the current buffer.
    let found_error = {}
    for error_info in a:error_list
        if !error_info.is_in_current_buffer
            continue
        endif
        if empty(found_error)
                \ || error_info.line_distance < found_error.line_distance
            let found_error = error_info
        endif
    endfor
    return found_error
endfun

fun! s:QfErrors._Init_GetBestError(error_list, current_buf_nearest_error)
    " The best error is the nearest error in the current buffer.  Fallback to
    " the first in error_list.
    if empty(a:error_list)
        return {}
    elseif !empty(a:current_buf_nearest_error)
        return a:current_buf_nearest_error
    else
        return a:error_list[0]
    endif
endfun

fun! s:QfErrors.SetQfToErrorsOnly() dict
    " Truncate all context lines from the quickfix buffer content.  Adapt the
    " recorded error lines for all error_info records.
    let line_counter = 1
    let new_qflist = []
    for error_info in self.error_list
        let error_info.qf_line = line_counter
        call add(new_qflist, error_info.error)
        let line_counter += 1
    endfor
    call setqflist(new_qflist, 'r')
endfun

" ---

fun! s:OpenNewQfTab_cond(want_split, want_vsplit)
    " Open a new tab with the quickfix window open.  Open a vsplit if
    " a:want_split is true.
    if IsQuickfixTab()
        return
    endif
    tab sp
    if a:want_split
        split
    elseif a:want_vsplit
        vsplit
    endif
    copen
    wincmd p
endfun

fun! s:SimplifyErrorMessage(message)
    " message translation (taken from makegreen)
    let error_message = a:message

    let error_message = substitute(error_message, '^ *', '', 'g')
    let error_message = substitute(error_message, "\n", ' ', 'g')

    " This might falsify error messages:
    "let error_message = substitute(error_message, "  *", ' ', 'g')
    return error_message
endfun

function! s:ShowBar(highlight_group, msg)
    " Display a bar with the message using highlight_group.
    exe "echohl " . a:highlight_group
    echon a:msg repeat(" ", &columns - strlen(a:msg) - 1)
    echohl None
endfunction

function! MakeGreen(flags, compiler_args)
    " Execute make with the given compiler_args (a string), display a bar and
    " jump to the error.  By default, prefer errors in the current buffer.  If
    " there is no error in the current buffer open a qf-tab and jump to the
    " first error.
    "
    " flags:
    "   C : suppress context, have only errors in the qf buffer -- no context
    "   t : always open on qf-tab in case of errors
    "   T : never open another tab; always jump in current window
    "   f : jump to the first error instead of the nearest
    "   s : open a split with the origin buffer on a new tab
    "   v : open a vsplit with the origin buffer on a new tab
    silent! exec "make! " . a:compiler_args

    let qf_errors = s:QfErrors.New()
    if empty(qf_errors.error_list)
        redraw
        call s:ShowBar('MakeGreenNoErrorBar', '')
        return
    endif

    let want_split = 0
    if a:flags =~# 's'
        let want_split = 1
    endif

    let want_vsplit = 0
    if a:flags =~# 'v'
        let want_vsplit = 1
    endif

    " remove context
    if a:flags =~# 'C'
        call qf_errors.SetQfToErrorsOnly()
    endif
    " always open on qf-tab
    if a:flags =~# 't'
        call s:OpenNewQfTab_cond(want_split, want_vsplit)
    endif
    " determine target error
    if a:flags =~# 'f'
        let target_error = qf_errors.error_list[0]
    else
        let target_error = qf_errors.best_error
    endif

    let simplified_message = s:SimplifyErrorMessage(target_error.error['text'])

    if target_error.is_in_current_buffer
        if len(qf_errors.error_list) > 1
            let bar_color = 'MakeGreenMultipleErrorBar'
        else
            let bar_color = 'MakeGreenOneErrorBar'
        endif
    else
        if a:flags !~# 'T'
            call s:OpenNewQfTab_cond(want_split, want_vsplit)
        endif
        let bar_color = 'MakeGreenDifferentBufferErrorBar'
    endif

    silent exe "cc " . target_error.qf_line
    redraw
    call s:ShowBar(bar_color, simplified_message)

endfunction

"
" --- Commands
"

com! -nargs=* MakeGreen :call MakeGreen('', <q-args>)
com! -nargs=* MakeGreenTabFirst :call MakeGreen('tf', <q-args>)
