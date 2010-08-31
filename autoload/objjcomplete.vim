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

function! s:DefRuby()
ruby << RUBY
(VIM::evaluate("&runtimepath").split(',').map{|v| $:.unshift(File.join(v, 'lib'))})
require 'objjc'
RUBY
endfunction

call s:DefRuby()

" Pattern A
"  [[CPObject alloc] init]
"  ^^^                   ^
"  123                   4
function! s:PredictType()
  try 
    throw getline('.')[col('.') - 1]
  catch '\[' " A1
    normal %
    return s:PredictType()
  catch ']' " A4
    let end = col('.')

    normal %
    call search('\S')

    let target = []

    try
      throw getline('.')[col('.') - 1:-1]
    catch '^\u' " A3
      normal "ayew
      let target = ['+'.getreg('a')]
    catch '^@"\|^"' " A2
      let target = ['CPString']
      call ObjJSkip()
      normal w
    catch '^]'
      return ['CPArray']
    catch '^\['
      normal %w
      let target = s:PredictPreType()
    catch
      normal "ayew
      let target = s:FindDefinition(getreg('a'))
    endtry

    execute printf('normal "ay%dl', end - col('.'))
    let message = getreg('a')
    return CallRuby(printf("ObjectiveJ::Completion.predict_return_types_from_pair([%s], '%s')", join(map(target, '"\"".v:val."\""'), ","), message))
  catch ')'
    call search('\S', 'b')
    return s:PredictType()
  catch '"'
    return ['CPString']
  catch
    normal l"ayb

    let result = getreg('a')
    try
      throw result
    catch '\<self$'
      return [s:CurrentClass(0), s:CurrentClass(1)]
    catch '\<super$'
      return [s:CurrentClass(1)]
    catch '^\u\w\+$'
      return ['+'.result]
    catch
      return s:FindDefinition(result)
    endtry
  endtry
endfunction

function! s:MethodPrefix()
  let origline = line('.')
  let orig = col('.')
  let pat = '^\s*\([-+]\)'

  call search(pat, 'b')
  let matches = matchlist(getline('.'), pat)

  call cursor(origline, orig)

  if matches[1] == '+'
    return '+'
  else
    return ''
  endif
endfunction

function! s:FindDefinition(varname)
  try
    throw a:varname
  catch 'super'
    return [s:CurrentClass(1)]
  catch 'self'
    return [s:CurrentClass(0), s:CurrentClass(1)]
  catch
    let origline = line('.')
    let orig = col('.')

    let assign = search('\<'.a:varname.'\>\s*=', 'b')
    let col = col('.')

    call cursor(origline, orig)

    let method = search('^\s*[-+].*\<'.a:varname.'\>', 'b')
    let line = getline('.')

    if assign > method
      call cursor(assign, col)
      normal f=w
      let r = s:PredictType()
    else
      let r = CallRuby(printf("ObjectiveJ::Completion.predict_argument_type('%s', '%s')", line, a:varname))
    endif

    call cursor(origline, orig)
    return r
  endtry
endfunction

function! s:PredictPreType()
  let orig = col('.')

  call search('\s', 'b')
  call search('\S', 'b')

  let type = s:PredictType()
  call cursor(line('.'), orig)
  return type
endfunction

function! s:CurrentClass(superclass)
  let origline = line('.')
  let orig = col('.')
  let pat = '@implementation\s\+\(\h\w\+\)\s*\((\h\w\+)\)\?\s*\(:\s*\(\h\w\+\)\)\?'

  call search(pat, 'b')
  let matches = matchlist(getline('.'), pat)
  call cursor(origline, orig)

  let prefix = s:MethodPrefix()
  if a:superclass == 1
    if len(matches[4])
      return prefix.(matches[4])
    else
      return prefix.CallRuby(printf("ObjectiveJ::Completion.get_superclass('%s')", matches[1]))
    endif
  else
    return prefix.(matches[1])
  endif
endfunction
