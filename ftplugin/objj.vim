function! SymbolUnderCursor(tran)
  return synIDattr(synID(line("."),col("."), a:tran),"name")
endfunction

function! ObjJSelect(direction)
  if !a:direction
    normal F:
  endif

  call search(":", a:direction ? '' : 'b')

  while getline('.') !~ '\[.*'
    call search(":", a:direction ? '' : 'b')
  endwhile

  normal l

  let symbol = SymbolUnderCursor(1)
  if symbol =~ 'objjString\|objjNumber'
    let start = col('.')
    call ObjJSkip()
    let end = col('.') - 1

    try
      throw symbol
    catch 'objjStringD'
      let start += 1
      let end   -= 1
    catch 'objjString'
      let start += 2
      let end   -= 1
    catch
    endtry
    
    call cursor(line('.'), start)

    if (end - start) > 0
      execute printf('normal v%dl', end - start)
    else
      startinsert
    endif
  elseif getline('.')[col('.') - 1] =~ '[ \]]'
    startinsert
  elseif getline('.')[col('.') - 1] == '['
    normal v%
  else
    normal hveolo
  endif
endfunction

function! ObjJSkip()
  let symbol = SymbolUnderCursor(1)
  while SymbolUnderCursor(1) == symbol
    normal l
  endwhile
endfunction

imap <buffer> <C-L> <Esc>:call ObjJSelect(1)<CR>
 map <buffer> <C-L> <Esc>:call ObjJSelect(1)<CR>
imap <buffer> <C-Y> <Esc>:call ObjJSelect(0)<CR>
 map <buffer> <C-Y> <Esc>:call ObjJSelect(0)<CR>

function! ObjJBrace()
  let line = line('.')
  let col = col('.')
  normal %
  if line('.') == line
    let rcol = col + 1
  else
    let rcol = col
  endif
  "let o_v = getreg('a', 1)
  "let o_t = getregtype('a')
  if line == line('.') && col == col('.')
    call cursor(line, col)
    normal "ayT]
    call cursor(line, col)
    normal F]%i[
    call cursor(line, rcol)
    try
      throw getreg('a')
    catch '^\s\+$'
      normal i
    catch
      normal a
    endtry
  else
    call cursor(line, rcol)
  endif
  "call setreg('a', o_v)
endfunction

inoremap <buffer> ] ]<Esc>:call ObjJBrace()<CR>a
set omnifunc=objjcomplete#Complete

if exists("g:AutoComplPop_Behavior")
  call extend(g:AutoComplPop_Behavior, {'objj': [{'pattern': '[\[ \.]\w\+$\|:\w*$', 'repeat': 0, 'command': "\<C-X>\<C-O>"}]})
endif

if exists('g:neocomplcache_omni_patterns')
  let g:neocomplcache_omni_patterns.objj = '[\[ \.]\w\+$\|:\w*$'
endif
