" operator-insert - 
" Version: 0.1.0
" Copyright (C) 2013 deris0126
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
  return s:operator_insert_i(a:motion_wise)
endfunction

function! operator#insert#insert_a(motion_wise)
  return s:operator_insert_a(a:motion_wise)
endfunction

"}}}

" Private {{{1

function! s:operator_insert_i(motion_wise)
  call cursor(getpos("'[")[1:])
  startinsert
endfunction

function! s:operator_insert_a(motion_wise)
  call cursor(getpos("']")[1:])
  if col("']") >= col("$") - 1
    startinsert!
  else
    normal! l
    startinsert
  endif
endfunction

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" __END__ "{{{1
" vim: foldmethod=marker
