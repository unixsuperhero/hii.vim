
function! HHandler(prefix,...)
  if a:0 == 0
    return 0
  endif

  let nfun = join([a:prefix,a:000[0]], '_')
  if exists('*' . nfun)
    if a:0 > 1
      let arg_list = copy(a:000)
      call call(nfun, remove(arg_list,1,-1))
    else
      call call(nfun, [])
    endif
    return 1
  end

  return 0
endfunction

function! H(...)
  if call('HHandler', extend(['H'],a:000)) == 1
    return 1
  endif

  return 0
endfunction

function! H_process(...)
  let text = getline('.')
  let patterns = [['^\s*\$>\?\s*','H_process_sh']]
  let patterns = extend(patterns, [['^\s*\(fuzzy_filter\|fmatch\):\s*','H_process_fuzzy']])
  let patterns = extend(patterns, [['^\s*\(regex_filter\|rematch\):\s*','H_process_regex']])
  let patterns = extend(patterns, [['^\s*\(fuzzy_filter\|fmatch\)!\s*','H_process_fuzzy_remove']])
  let patterns = extend(patterns, [['^\s*\(regex_filter\|rematch\)!\s*','H_process_regex_remove']])

  " allow anyone to add their own line filters (or menus in xiki-speak)
  " let g:hii_patterns take precedence over the default patterns
  if exists('g:hii_patterns') && type(g:hii_patterns) == v:t_list
    let patterns = extend(g:hii_patterns, patterns)
  endif

  for [regex,fname] in patterns
    if match(text,regex) >= 0 && exists('*' . fname)
      " call the line-handler with the args:
      " - regex: the pattern that matched the line
      " - line: the original line of text matching the regex
      " - text: the line without the part matching the regex
      call call(fname, [regex,text,substitute(text,regex,'','')])
      return 1
    endif
  endfor

  echo 'no handler found for the prefix on this line'
  return 0
endfunction

" alias to H_process(...)
function! H_run(...)
  return call('H_process', a:000)
endfunction

function! H_process_sh(regex,line,text)
  let epoch = strftime('%s')
  let outfile = expand(printf('~/hii/sh/%s.log', epoch))
  call system('mkdir -pv $(dirname ' . shellescape(outfile) . ')')
  echo 'a:text => ' . string(a:text)
  let cmd = substitute(a:text, '\ze\(&\?>>*\|$\)', ' | tee >' . outfile . ' ', '')
  echo 'cmd => ' . string(cmd)
  call system(cmd)
  if filereadable(outfile)
    let filterfile = expand(printf('~/hii/sh/filter/%s.log', epoch))
    call system(printf('mkdir -pv $(dirname %s)', shellescape(filterfile)))
    call system(printf('cp -v %s %s', outfile, filterfile))
    execute 'vs ' . filterfile
  else
    echo 'ERROR: outfile (' . outfile . ') not created!'
  endif
endfunction

function! H_process_regex(regex,line,text)
  execute(printf('delete %d', line('.')))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  echom printf('regex pattern: "%s"', pattern)
  execute printf('v/%s/d', pattern)
endfunction

function! H_process_fuzzy(regex,line,text)
  execute('delete ' . line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  let pattern = join(split(pattern, '\ze.'),'.\{-}')
  echom printf('fuzzy pattern: "%s"', pattern)
  execute printf('v/%s/d', pattern)
endfunction

function! H_process_regex_remove(regex,line,text)
  execute(printf('delete %d', line('.')))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  echom printf('regex pattern: "%s"', pattern)
  execute printf('g/%s/d', pattern)
endfunction

function! H_process_fuzzy_remove(regex,line,text)
  execute('delete ' . line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  let pattern = join(split(pattern, '\ze.'),'.\{-}')
  echom printf('fuzzy pattern: "%s"', pattern)
  execute printf('g/%s/d', pattern)
endfunction

" take categorized notes (subdirs = categories)
function! H_list(...)
  if call('HHandler', extend(['H_list'],a:000)) == 1
    return 1
  endif

  let split_window = v:true
  for fname in a:000
    let ffname = '~/lists/' . fname

    if filereadable(expand(ffname . '.md'))
      let ffname = ffname . '.md'
      let fname = fname . '.md'
    endif

    call system('mkdir -pv $(dirname ' . shellescape(expand(ffname)) . ')')

    if split_window == v:true
      execute 'vs ' . ffname
      execute 'lcd ~/lists'
      let split_window = v:false
    else
      execute 'e ' . fname
    endif
  endfor
endfunction

function! H_list_date(...)
  echom strftime('%Y-%m-%d')
  call H_list('date/' . strftime('%Y-%m-%d'))
endfunction

" alias to H_list(...)
function! H_note(...)
  return call('H_list', a:000)
endfunction

" alias to H_list_date(...)
function! H_note_date(...)
  return call('H_list_date', a:000)
endfunction

command! -nargs=+ H call H(<f-args>)

