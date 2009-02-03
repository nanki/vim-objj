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

function! CallRuby(rubystr)
  execute "ruby ".a:rubystr
  return s:objj_generic_return
endfunction

function! objjcomplete#Complete(findstart, base)
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
  else
    return CallRuby("ObjectiveJ::Completion.get_completions('" . a:base . "')")
  endif
endfunction

echo expand("#:p")
function! s:DefRuby()
ruby << RUBY
$:.concat VIM::evaluate("&runtimepath").split(',').map{|v| File.join(v, 'lib')}
require 'objjc'
RUBY
endfunction

call s:DefRuby()

function! s:ObjJPredictType()
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
    return CallRuby(printf("ObjectiveJ::Completion.predict_return_types_from_pair([%s], '%s')", join(map(target, '"\"".v:val."\""'), ","), message))
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
      return [ObjJCurrentClass(0), ObjJCurrentClass(1)]
    catch '\<super$'
      return [ObjJCurrentClass(1)]
    catch '^\u\w\+$'
      return ['+'.result]
    catch
      return s:ObjJFindDefinition(result)
    endtry
  endtry
endfunction

function! s:ObjJFindDefinition(varname)
  let origline = line('.')
  let orig = col('.')
  let pat = '^\s*[-+].*\<'.a:varname.'\>'

  call search(pat, 'b')
  let line = getline('.')
  call cursor(origline, orig)

  return CallRuby(printf("ObjectiveJ::Completion.predict_variable_type('%s', '%s')", line, a:varname))
endfunction

function! s:ObjJPredictPreType()
  let orig = col('.')

  call search('\s', 'b')
  call search('\S', 'b')

  let type = s:ObjJPredictType()
  call cursor(line('.'), orig)
  return type
endfunction

function! ObjJCurrentClass(superclass)
  let origline = line('.')
  let orig = col('.')
  let pat = '@implementation\s\+\(\h\w\+\)\s\(:\s*\(\h\w\+\)\)\?'

  call search(pat, 'b')
  let matches = matchlist(getline('.'), pat)
  call cursor(origline, orig)
  if a:superclass == 1
    if len(matches[3])
      return matches[3]
    else
      return CallRuby(printf("ObjectiveJ::Completion.get_superclass('%s')", matches[1]))
    endif
  else
    return matches[1]
  endif
endfunction
