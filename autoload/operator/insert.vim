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

function! operator#insert#insert_i(motion_wise)
  return s:operator_insert_origin('i', a:motion_wise)
endfunction

function! operator#insert#insert_a(motion_wise)
  return s:operator_insert_origin('a', a:motion_wise)
endfunction

"}}}

" Public, but it is *not* recommended to be used by users. {{{1

" Set state to ground state. It is used when keymappings are triggered.
function! operator#insert#ground_state()
  call s:set_info('state', 0)
endfunction

"}}}

" Private {{{1

function! s:operator_insert_origin(ai, motion_wise)
  " determine a insertion
  let insertion = s:get_info('state') == 0
        \  ? substitute(input("Insertion: ", ""), "\n", "", 'g')
        \  : s:get_info('last_insertion')

  if insertion != ''
    " execute an action
    call s:call_autocmd('OperatorInsertInsertPre')
    call s:insert_{a:motion_wise}wise(a:ai, insertion)
    call s:call_autocmd('OperatorInsertInsertPost')

    " save history
    call s:set_info('last_insertion', insertion)
  endif

  " excite state
  call s:set_info('state', 1)
endfunction

function! s:insert_charwise(ai, insertion)
  if a:ai ==# 'i'
    execute "normal! `[i" . a:insertion
  else
    execute "normal! `]a" . a:insertion
  endif
endfunction

function! s:insert_linewise(ai, insertion)
  let [head, tail] = [line("'["), line("']")]

  if a:ai ==# 'i'
    " not sure... removing '^' might be more natural...
    execute "'[,']normal! ^i" . a:insertion
  else
    execute "'[,']normal! $a" . a:insertion
  endif

  " set marks as wrapping whole lines
  call setpos("'[", [0, head, 0, 0])
  call setpos("']", [0, tail, col([tail, '$']), 0])
endfunction

function! s:insert_blockwise(ai, insertion)
  let processed = []

  if a:ai ==# 'i'
    " lines: [lnum, length]
    let lines = map(range(line("'["), line("']")),
          \           '[v:val, strlen(getline(v:val))]')

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
    " lines: [lnum, length]
    let lines = map(range(line("'["), line("']")),
          \           '[v:val, strlen(getline(v:val))]')

    let col = col("']")
    for line in lines
      if line[1] >= col
        call cursor(line[0], col)
        execute "normal! a" . a:insertion
        let processed += [line[0]]
      endif
    endfor
  endif

  " set marks for the topleft and bottomright edge of the processed lines
  if processed != []
    call setpos("'[", [0, processed[0], col("'["), 0])
    call setpos("']", [0, processed[-1], col("']") - 1, 0])
  endif
endfunction



" History and state management
" The required information is stored to buffer local variable named
" 'b:operator_insert_info' since 'operatorfunc' option is buffer local. There
" are three keys, 'state', 'last_insertion', and, 'last_target'.

" The 'state' keeps managed to distinguish whether the operatorfunc was called
" by a keymapping or by the dot command.
" get_state() == 0 : called by a keymapping
" get_state() == 1 : called by the dot command

" The 'last_insertion' is stored for dot-repeat.

function! s:get_info(name)
  if !exists('b:operator_insert_info')
    let b:operator_insert_info = {}
    let b:operator_insert_info.state = 0
    let b:operator_insert_info.last_insertion = ''
  endif
  return b:operator_insert_info[a:name]
endfunction

function! s:set_info(name, value)
  if !exists('b:operator_insert_info')
    let b:operator_insert_info = {}
    let b:operator_insert_info.state = 0
    let b:operator_insert_info.last_insertion = ''
  endif
  let b:operator_insert_info[a:name] = a:value
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

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" __END__ "{{{1
" vim: foldmethod=marker
