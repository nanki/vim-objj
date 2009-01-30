if version < 700
  s:ErrMsg( "Error: Required vim >= 7.0" )
  finish
endif

if !has('ruby')
  S:eRRmsg( "Error: Objective-J complete requires vim compiled with +ruby" )
  s:ErrMsg( "Error: falling back to syntax completion" )
  " lets fall back to syntax completion
  setlocal omnifunc=syntaxcomplete#Complete
  finish
endif


function! objjcomplete#Complete(findstart, base)
  "findstart = 1 when we need to get the text length
  if a:findstart
    let line = getline('.')
    let i = col('.')
    while i > 0
      let i -= 1
      try
        throw line[i-1]
      catch '\w'
        continue
      catch '\W'
        break
      catch
        let i = -1
        break
      endtry
    endwhile

    return i
    "findstart = 0 when we need to return the list of completions
  else
    let g:objj_completions = []
    execute "ruby ObjectiveJ::Completion.get_completions('" . a:base . "')"
    return g:objj_completions
  endif
endfunction

echo expand("#:p")
function! s:DefRuby()
ruby << RUBY
$:.concat VIM::evaluate("&runtimepath").split(',')
require 'lib/objjc'
RUBY
endfunction

call s:DefRuby()

function s:ObjJPredictType()
  try 
    throw getline('.')[col('.') - 1]
  catch ']'
    let end = col('.')

    normal %
    call search('\S')

    let target = []

    try
      throw getline('.')[col('.') - 1:-1]
    catch '^\u'
      normal "ayew
      let target = ['+'.getreg('a')]
    catch '^@"\|^"'
      let target = ['CPString']
      call ObjJSkip()
      normal w
    catch '^\['
      normal %w
      let target = s:ObjJPredictPreType()
    catch
      normal w
    endtry

    execute printf('normal "ay%dl', end - col('.'))
    let message = getreg('a')
    let g:return_types = []
    
    execute printf("ruby ObjectiveJ::Completion.predict_return_types_from_pair([%s], '%s')", join(map(target, '"\"".v:val."\""'), ","), message)
    return g:return_types
  catch ')'
    call search('\S', 'b')
    return s:ObjJPredictType()
  catch '"'
    return ['CPString']
  catch
    normal l"ayb

    let result = getreg('a')
    try
      throw result
    catch '\<self$'
      return [ObjJCurrentClass(1), ObjJCurrentClass(0)]
    catch '\<super$'
      return [ObjJCurrentClass(1)]
    catch '^\u\w\+$'
      return ['+'.result]
    catch
      " not implemented.
      " ObjJFindDefinition()
      return ['id']
    endtry
  endtry
endfunction

function s:ObjJPredictPreType()
  let orig = col('.')

  call search('\s', 'b')
  call search('\S', 'b')

  let type = s:ObjJPredictType()
  call cursor(line('.'), orig)
  return type
endfunction

function ObjJCurrentClass(flag)
  let origline = line('.')
  let orig = col('.')
  let pat = '@implementation\s\+\(\h\w\+\)\s\(:\s*\(\h\w\+\)\)\?'

  call search(pat, 'b')
  let matches = matchlist(getline('.'), pat)
  call cursor(origline, orig)
  if a:flag == 1
    return matches[3]
  else
    return matches[1]
  endif
endfunction

call extend(g:AutoComplPop_Behavior, {'objj': [{'pattern': '\s\w\+$', 'repeat': 0, 'command': "\<C-x>\<C-o>"}]})
