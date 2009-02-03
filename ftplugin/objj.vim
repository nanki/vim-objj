function ObjJSelect(direction)
  if !a:direction
    normal F:
  endif

  call search(":", a:direction ? '' : 'b')

  while getline('.') !~ '\[.*'
    call search(":", a:direction ? '' : 'b')
  endwhile

  normal l

  let symbol = SymbolUnderCursor(0)
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
  else
    normal hveolo
  endif
endfunction

function ObjJSkip()
  let symbol = SymbolUnderCursor(0)
  while SymbolUnderCursor(0) == symbol
    normal l
  endwhile
endfunction

imap <buffer> <C-L> <Esc>:call ObjJSelect(1)<CR>
 map <buffer> <C-L> <Esc>:call ObjJSelect(1)<CR>
imap <buffer> <C-Y> <Esc>:call ObjJSelect(0)<CR>
 map <buffer> <C-Y> <Esc>:call ObjJSelect(0)<CR>
set omnifunc=objjcomplete#Complete

call extend(g:AutoComplPop_Behavior, {'objj': [{'pattern': '[\[ :\.]\w\+$', 'repeat': 0, 'command': "\<C-X>\<C-O>"}]})
