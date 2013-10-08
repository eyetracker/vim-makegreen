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

" A request messenger for the main function.
let s:RequestMessenger = {}
let s:RequestMessenger.target_error = {}
let s:RequestMessenger.bar_color = ''
let s:RequestMessenger.want_new_tab = 0
let s:RequestMessenger.want_split = 0
let s:RequestMessenger.want_vsplit = 0
let s:RequestMessenger.want_suppress_context = 0

fun! s:ParseCommandFlags(flags, qf_errors)
    " Assemble values and commands for the main function and return
    " a s:RequestMessenger instance.
    "
    " flags:
    "   C : suppress context, have only errors in the qf buffer -- no context
    "   t : always open on qf-tab in case of errors
    "   T : never open another tab; always jump in current window
    "   f : jump to the first error instead of the nearest
    "   s : open a split with the origin buffer on a new tab
    "   v : open a vsplit with the origin buffer on a new tab
    let request = deepcopy(s:RequestMessenger)

    " short circuit in case of no errors
    if empty(a:qf_errors.error_list)
        let request.bar_color = 'MakeGreenNoErrorBar'
        return request
    endif

    " determine target error
    if a:flags =~# 'f'
        let request.target_error = a:qf_errors.error_list[0]
    else
        let request.target_error = a:qf_errors.best_error
    endif

    " error bar color and new-tab default
    if request.target_error.is_in_current_buffer
        if len(a:qf_errors.error_list) > 1
            let request.bar_color = 'MakeGreenMultipleErrorBar'
        else
            let request.bar_color = 'MakeGreenOneErrorBar'
        endif
        let request.want_new_tab = 0
    else
        let request.bar_color = 'MakeGreenDifferentBufferErrorBar'
        let request.want_new_tab = 1
    endif

    " tab and splits
    if a:flags =~# 't'
        let request.want_new_tab = 1
    elseif a:flags !~# 'T'
        let request.want_new_tab = 0
    endif

    if a:flags =~# 's'
        let request.want_split = 1
    else
        let request.want_split = 0
    endif

    if a:flags =~# 'v'
        let request.want_vsplit = 1
    else
        let request.want_vsplit = 0
    endif

    " context
    if a:flags =~# 'C'
        let request.want_suppress_context = 1
    else
        let request.want_suppress_context = 0
    endif

    return request
endfun

function! MakeGreen(flags, compiler_args)
    " Execute make with the given compiler_args (a string), display a bar and
    " jump to the error.  By default, prefer errors in the current buffer.  If
    " there is no error in the current buffer open a qf-tab and jump to the
    " first error.
    "
    " For valid flags see s:ParseCommandFlags()
    silent! exec "make! " . a:compiler_args
    let qf_errors = s:QfErrors.New()
    let request = s:ParseCommandFlags(a:flags, qf_errors)

    if request.want_suppress_context
        call qf_errors.SetQfToErrorsOnly()
    endif

    if request.want_new_tab
        call s:OpenNewQfTab_cond(request.want_split, request.want_vsplit)
    endif

    let message = ''
    let error_count = 0
    if !empty(request.target_error)
        let message = request.target_error.error['text']
        let error_count = len(qf_errors.error_list)
        silent exe "cc " . request.target_error.qf_line
    endif

    let simplified_message = s:SimplifyErrorMessage(message)
    redraw
    call s:ShowBar(request.bar_color, simplified_message)
    return error_count
endfunction

"
" --- Commands
"

com! -nargs=* MakeGreen :call MakeGreen('', <q-args>)
com! -nargs=* MakeGreenTabFirst :call MakeGreen('tf', <q-args>)
