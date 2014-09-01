" operator-insert - operator-insert is an operator for inserting to head(or tail) of textobject
" Version: 0.1.0
" Copyright (C) 2013-2014 deris0126
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

let s:save_cpo = &cpo
set cpo&vim

" Public API {{{1

function! operator#insert#i(motion_wise)
  return s:operator_insert_origin('i', a:motion_wise)
endfunction

function! operator#insert#a(motion_wise)
  return s:operator_insert_origin('a', a:motion_wise)
endfunction



" The variable to stop execution.
" When s:bool_activity is 0, do not execute action.
" Currently it is used only by auxiliary textobjects.
let s:bool_activity = 1

function! operator#insert#deactivate()
  let s:bool_activity = 0
endfunction

function! operator#insert#activate()
  let s:bool_activity = 1
endfunction



" The simple buffer complete function.
function! operator#insert#complete_from_visible_lines(ArgLead, CmdLine, CursorPos)
  let lines = getline(line('w0'), line('w$'))

  " gather words ('\<\k\{3,}\>')
  let words = []
  for line in lines
    let start = 0
    while 1
      let words += [matchstr(line, '\<\k\{3,}\>', start)]
      let start  =  matchend(line, '\<\k\{3,}\>', start)
      if start < 0 | break | endif
    endwhile
  endfor

  " uniquify
  let candidates = []
  call filter(words, 'v:val != ""')
  for word in words
    if !count(candidates, word)
      let candidates += [word]
    endif
  endfor

  return join(candidates, "\n")
endfunction

"}}}

" Public, but it is *not* recommended to be used by users. {{{1

" Set state to ground state. It is used when keymappings are triggered.
function! operator#insert#ground_state()
  call s:set_info('state', 0)

  " kill quencher
  augroup operator-insert
    autocmd!
  augroup END
endfunction

" To bring script-local functions safely as possible
function! operator#insert#funcref_mediator(list)
  let funcrefs = []
  for name in a:list
    let funcrefs += [function('s:' . name)]
  endfor
  return funcrefs
endfunction

"}}}

" Private {{{1

" The definition of null position and region
let s:null_pos    = [0, 0]
let s:null_region = [s:null_pos, s:null_pos]

" The original of each operator
function! s:operator_insert_origin(ai, motion_wise)
  " if it is not active, then quit immediately
  if !s:is_active()
    call s:set_info('state', 1)
    call operator#insert#activate()
    return
  endif

  let state = s:get_info('state')

  " highlight dummy cursor
  if !state
    let id = s:add_dummy_cursor(a:ai, a:motion_wise)
  endif

  " determine a insertion
  let insertion = state == 0
        \  ? input("Insertion: ", "", g:operator#insert#completefunc)
        \  : s:get_info('last_insertion')

  " clear all highlights
  if !state
    let id += s:get_info('highlight')
    if id != []
      call s:clear_highlight(id)
      call s:set_info('highlight', [])
    endif
  endif

  if insertion != ''
    " execute an action
    call s:call_autocmd('OperatorInsertInsertPre')
    let last_target = s:insert_{a:motion_wise}wise(a:ai, insertion)
    call s:call_autocmd('OperatorInsertInsertPost')

    " save the region of the last target textobject
    call s:set_info('last_target', last_target)

    " save history
    call s:set_info('last_insertion', insertion)

    " excite to the super-excited state
    call s:set_info('state', 2)

    " reserve quencher (to the first excited state)
    augroup operator-insert
      autocmd!
      autocmd TextChanged <buffer> autocmd operator-insert InsertEnter,CursorMoved,TextChanged,WinLeave,FileChangedShellPost <buffer> call s:quench_state()
    augroup END
  else
    " restore view
    call winrestview(s:get_info('view'))

    " close foldings and clear opened_fold
    call s:close_fold()
    call s:set_info('opened_fold', [])

    " excite to the first excited state
    call s:set_info('state', 1)
  endif

  " restore visual area marks
  " This is quite clean and it is impossible for user defined textobjects to
  " do such a post-processing without cooperation between a operator and a
  " textobject. However it is still not perfect, because after an undo, marks
  " are restored as the textobject has selected.
  let [lt, gt] = s:get_info('visualmarks')
  if lt != s:null_pos && gt != s:null_pos
    call setpos("'<", lt)
    call setpos("'>", gt)
    call s:set_info('visualmarks', s:null_region)
  endif
endfunction

function! s:insert_charwise(ai, insertion)
  " memorize the position of target text
  let head_before = getpos("'[")[1:2]
  let tail_before = getpos("']")[1:2]

  if a:ai ==# 'i'
    execute "normal! `[i" . a:insertion

    " calculate the position of shifted target region
    if head_before[0] == tail_before[0]
      " the target text does not include any line-breaking
      let head_after = [line('.'), col('.') + 1]
      let tail_after = [line('.'), col('.') + tail_before[1] - head_before[1] + 1]
    else
      " the target text consists of several lines
      let head_after = [line('.'), col('.') + 1]
      let tail_after = [line('.') - head_before[0] + tail_before[0], tail_before[1]]
    endif
    let region = [head_after, tail_after]
  else
    " record the region of target text
    let region = [head_before, tail_before]

    execute "normal! `]a" . a:insertion
  endif

  return region
endfunction

function! s:insert_linewise(ai, insertion)
  let [head, tail] = [line("'["), line("']")]

  if a:ai ==# 'i'
    " not sure... removing '^' might be more natural...
    for lnum in reverse(range(head, tail))
      execute printf('%snormal! ^i%s', lnum, a:insertion)
    endfor
  else
    for lnum in reverse(range(head, tail))
      execute printf('%snormal! $a%s', lnum, a:insertion)
    endfor
  endif

  " set marks as wrapping whole lines
  call setpos("'[", [0, head, 0, 0])
  call setpos("']", [0, tail, col([tail, '$']), 0])

  " not required to store the target region in a linewise action
  return s:null_region
endfunction

function! s:insert_blockwise(ai, insertion)
  let processed = []

  " lines: [lnum, length]
  let lines = reverse(map(range(line("'["), line("']")),
        \               '[v:val, strlen(getline(v:val))]'))

  if a:ai ==# 'i'
    let col   = col("'[")
    for line in lines
      if line[1] >= col
        call cursor(line[0], col)
        execute "normal! i" . a:insertion
        let processed += [line[0]]
      elseif line[1] == col - 1
        call cursor(line[0], col)
        execute "normal! a" . a:insertion
        let processed += [line[0]]
      endif
    endfor
  else
    let col = col("']")
    for line in lines
      if line[1] >= col
        call cursor(line[0], col)
        execute "normal! a" . a:insertion
        let processed += [line[0]]
      endif
    endfor
  endif

  " set marks for the topleft and bottomright edge of the processed region
  if processed != []
    call setpos("'[", [0, processed[0], col("'["), 0])
    call setpos("']", [0, processed[-1], col("']") - 1, 0])
  endif

  " not required to store the target region in a blocwise action
  return s:null_region
endfunction

function! s:close_fold()
  let opened_fold = s:get_info('opened_fold')

  for lnum in reverse(opened_fold)
    execute lnum . 'foldclose'
  endfor
endfunction

function! s:is_active()
  return s:bool_activity
endfunction



" History and state management
" The required information is stored to buffer local variable named
" 'b:operator_insert_info' since 'operatorfunc' option is buffer local. There
" are three keys, 'state', 'last_insertion', and, 'last_target'.

" The 'state' keeps managed to distinguish whether the operatorfunc was called
" by a keymapping or by the dot command. There are two excited states for
" dot-repeat callings. If it is called just after a keymapping action, then it
" is 'hot' calling. Otherwise it is regarded as 'cold' calling. 'Hot' calling
" changes the behavior of auxiliary textobjects, it would skip the closest
" searched word if necessary. After an action, the state is immediately cool
" down to the first excited state (s:get_info('state') == 1) if the next
" action is not the dot-repeat.
" s:get_info('state') == 0 : called by a keymapping
" s:get_info('state') == 1 : called by the dot command (cold-calling)
" s:get_info('state') == 2 : called by the dot command (hot-calling)

" The 'last_insertion' is stored for dot-repeat.

function! s:get_info(name)
  if !exists('b:operator_insert_info')
    " initialization
    let b:operator_insert_info = {}
    let b:operator_insert_info.state = 0
    let b:operator_insert_info.last_insertion = ''
    let b:operator_insert_info.last_target = s:null_region
    let b:operator_insert_info.view = {}
    let b:operator_insert_info.opened_fold = []
    let b:operator_insert_info.highlight = []
    let b:operator_insert_info.visualmarks = s:null_region
  endif
  return b:operator_insert_info[a:name]
endfunction

" NOTE: s:set_info() and s:add_info should be called only in the function
"       s:operator_insert_origin except for the case of 'state' key as
"       possible. Otherwise it is really easy to mess up.
function! s:set_info(name, value)
  if !exists('b:operator_insert_info')
    " initialization
    call s:get_info('state')
  endif
  let b:operator_insert_info[a:name] = a:value
endfunction

function! s:add_info(name, value)
  if !exists('b:operator_insert_info')
    " initialization
    call s:get_info('state')
  endif

  if a:name ==# 'opened_fold' || a:name ==# 'highlight'
    let b:operator_insert_info[a:name] += a:value
  endif
endfunction

" It is used for quenching the state from the super-excited state to the first
" excited state. This transition switches off the skipping behavior of
" auxiliary textobjects.
function! s:quench_state()
  call s:set_info('state', 1)

  " kill quencher
  augroup operator-insert
    autocmd!
  augroup END
endfunction



" Userdefined autocmd events
" OperatorInsertInsertPre  : Ignited prior to insert a insertion.
" OperatorInsertInsertPost : Ignited after inserting a insertion.
" These events are prepared mainly to suppress unwanted affection from
" auto-complete plugins.
function! s:call_autocmd(name)
  if exists('#' . a:name)
    execute 'doautocmd <nomodeline> ' . a:name
  endif
endfunction



" Put dummy cursor(s) by using highlight
function! s:add_dummy_cursor(ai, motion_wise)
  if a:motion_wise ==# 'char'
    if a:ai ==# 'i'
      let lnum = line("'[")
      let col  = col("'[")
    else
      let lnum = line("']")
      let col  = col("']")
    endif

    if v:version > 704 || v:version == 704 && has('patch343')
      let id = [matchaddpos("OperatorInsertDummyCursor", [[lnum, col]])]
    else
      let id = [matchadd("OperatorInsertDummyCursor", printf('\%%%sl\%%%sc.', lnum, col))]
    endif
  elseif a:motion_wise ==# 'line'
    if a:ai ==# 'i'
      let id = map(range(line("'["), line("']")), 'matchadd("OperatorInsertDummyCursor", printf(''\%%%sl\%%%sc.'', v:val, match(getline(v:val), ''^\s*\zs.'') <= 0 ? 1 : match(getline(v:val), ''^\s*\zs.'') + 1))')
    else
      let id = map(range(line("'["), line("']")), 'matchadd("OperatorInsertDummyCursor", printf(''\%%%sl\%%%sc.'', v:val, match(getline(v:val), ''$'') <= 0 ? 1 : match(getline(v:val), ''$'')))')
    endif
  else
    let head = line("'[")
    let tail = line("']")

    if a:ai ==# 'i'
      let col = col("'[")
    else
      let col = col("']")
    endif

    if (v:version > 704 || v:version == 704 && has('patch343')) && tail - head < 8
      let id = map(range(line("'["), line("']")), 'matchaddpos("OperatorInsertDummyCursor", [[v:val, col]])')
    else
      let id = map(range(line("'["), line("']")), 'matchadd("OperatorInsertDummyCursor", printf(''\%%%sl\%%%sc.'', v:val, col))')
    endif
  endif

  redraw
  return id
endfunction

function! s:clear_highlight(id_list)
  call map(a:id_list, 'matchdelete(v:val)')
endfunction

"}}}

" Options {{{1

" The complete function
let g:operator#insert#completefunc =
      \ get(g:, 'operator#insert#completefunc', 'custom,operator#insert#complete_from_visible_lines')

" Dummy cursor
let g:operator#insert#dummycursor =
      \ get(g:, 'operator#insert#dummycursor', 'Cursor')

if type(g:operator#insert#dummycursor) == type('') && g:operator#insert#dummycursor != ''
  execute 'highlight link OperatorInsertDummyCursor ' . g:operator#insert#dummycursor
elseif type(g:operator#insert#dummycursor) == type({})
  let args = ['term', 'cterm', 'ctermfg', 'ctermbg',
        \     'gui', 'guifg', 'guibg', 'guisp']
  " I never look back
  execute printf('highlight OperatorInsertDummyCursor %s', join(values(map(filter(copy(g:operator#insert#dummycursor), printf("v:key =~# '\%%(%s\)'", join(args, '\|'))), 'printf("%s=%s", v:key, v:val)')), ' '))
  unlet args
endif

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" __END__ "{{{1
" vim: foldmethod=marker
