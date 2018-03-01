
" helper functions

function! H__file(fmt, ...)
  return expand((a:0 > 0) ? call('printf', extend([a:fmt],a:000)) : a:fmt)
endfunction

function! H__sh(fmt, ...)
  return system((a:0 > 0) ? call('printf', extend([a:fmt],a:000)) : a:fmt)
endfunction

function! H__ex(fmt, ...)
  return execute((a:0 > 0) ? call('printf', extend([a:fmt],a:000)) : a:fmt)
endfunction

function! H__puts(fmt, ...)
  echom (a:0 > 0) ? call('printf', extend([a:fmt],a:000)) : a:fmt
endfunction

" main code

function! HHandler(prefix,...)
  if a:0 == 0
    return 0
  endif

  let nfun = join([a:prefix,a:000[0]], '_')
  if exists('*' . nfun)
    call call(nfun, (a:0 > 1) ? remove(copy(a:000),1,-1) : [])
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
      " - line: the original line of text matching the regex (the entire line)
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
  let outfile = H__file('~/hii/sh/%s.log', epoch)
  call H__sh('mkdir -pv $(dirname %s)', shellescape(outfile))
  echo 'a:text => ' . string(a:text)
  let cmd = substitute(a:text, '\ze\(&\?>>*\|$\)', ' | tee >' . outfile . ' ', '')
  echo 'cmd => ' . string(cmd)
  call system(cmd)
  if filereadable(outfile)
    let filterfile = H__file('~/hii/sh/filter/%s.log', epoch)
    call H__sh('mkdir -pv $(dirname %s)', shellescape(filterfile))
    call H__sh('cp -v %s %s', outfile, filterfile)
    execute 'vs ' . filterfile
  else
    echo 'ERROR: outfile (' . outfile . ') not created!'
  endif
endfunction

function! H_process_regex(regex,line,text)
  call H__ex('delete %d', line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  call H__puts('regex pattern: "%s"', pattern)
  call H__ex('v/%s/d', pattern)
endfunction

function! H_process_fuzzy(regex,line,text)
  call H__ex('delete %d', line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  let pattern = join(split(pattern, '\ze.'),'.\{-}')
  call H__puts('fuzzy pattern: "%s"', pattern)
  call H__ex('v/%s/d', pattern)
endfunction

function! H_process_regex_remove(regex,line,text)
  call H__ex('delete %d', line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  call H__puts('regex pattern: "%s"', pattern)
  call H__ex('g/%s/d', pattern)
endfunction

function! H_process_fuzzy_remove(regex,line,text)
  call H__ex('delete %d', line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  let pattern = join(split(pattern, '\ze.'),'.\{-}')
  call H__puts('fuzzy pattern: "%s"', pattern)
  call H__ex('g/%s/d', pattern)
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

    call H__sh('mkdir -pv $(dirname %s)', shellescape(expand(ffname)))

    if split_window == v:true
      call H__ex('vs %s', ffname)
      call H__ex('lcd ~/lists')
      let split_window = v:false
    else
      call H__ex('e %s', fname)
    endif
  endfor
endfunction

function! H_list_date(...)
  call H__puts(strftime('%Y-%m-%d'))
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

" this probably shouldn't be a global setting, but i'm the only person using
" this right now
nnoremap <leader>hr :H run<cr>

" another mapping i shouldn't force on anyone (i normally don't do this, but
" who wants to exit insert mode, then hit a mapping to run a command you just
" typed, when you could just hit the mapping)
inoremap ;;r <esc>:H run<cr>
