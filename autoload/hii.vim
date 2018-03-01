
" helper functions

function! H__file(fmt, ...)
  let text = (a:0 == 0) ? a:fmt : call('printf', H__lpush(a:fmt, a:000))
  return expand(text)
endfunction

function! H__mkdir(dir)
  call H__sh('mkdir -pv %s', shellescape(expand(a:dir)))
endfunction

function! H__fdir(file)
  call H__mkdir(fnamemodify(a:file, ':h'))
endfunction

function! H__sh(fmt, ...)
  let text = (a:0 == 0) ? a:fmt : call('printf', H__lpush(a:fmt, a:000))
  return system(text)
endfunction

function! H__ex(fmt, ...)
  let text = (a:0 == 0) ? a:fmt : call('printf', H__lpush(a:fmt, a:000))
  return execute(text)
endfunction

function! H__puts(fmt, ...)
  let text = (a:0 == 0) ? a:fmt : call('printf', H__lpush(a:fmt, a:000))
  echom text
endfunction

function! H__lpush(a,bs)
  return extend([a:a],a:bs)
endfunction

" main code

function! HHandler(prefix,...)
  if a:0 == 0
    return 0
  endif

  let args = copy(a:000)
  let scmd = remove(args,0)
  let nfun = join([a:prefix, scmd], '_')

  if exists('*' . nfun)
    call call(nfun, args)
    return 1
  end

  return 0
endfunction

function! H(...)
  if call('HHandler', H__lpush('H',a:000)) == 1
    return 1
  endif

  return 0
endfunction

fun! H__prompt(type,input,flines)
  let hprompt = printf('%s/%s', a:type, a:input)
  let bflines = a:flines
  execute '%d'
  execute '0put=hprompt'
  execute '1put=bflines'
  call cursor(1,len(hprompt)+1)
  redraw
endfun

fun! HChr(name)
  let char_map = {
        \ 'bs': nr2char(8),
        \ 'backspace': nr2char(8),
        \ 'delete': nr2char(8),
        \ 'tab': nr2char(9),
        \ 'enter': nr2char(13),
        \ 'newline': nr2char(13),
        \ 'nl': nr2char(13),
        \ 'cr': nr2char(13),
        \ 'sl': nr2char(92),
        \ 'bsl': nr2char(92),
        \ 'bslash': nr2char(92),
        \ }

  if has_key(char_map, a:name)
    return char_map[a:name]
  endif

  return 0
endfun

fun! H_ifilter(...)
  let olmore = &l:more
  execute 'setlocal nomore'
  let nlmore = &l:more
  let all_lines = getline('^','$')
  let flines = copy(all_lines)
  let fstr = ''
  let pattern = ''
  execute 'vnew'
  execute 'set buftype=nofile noswapfile'
  call H__prompt('if',fstr,flines)

  let g:hiiro_captured_keys = []

  let keep_filter = v:false
  let grabkeys = v:true
  redraw
  while grabkeys == v:true
    call cursor(1,1)
    let cchar = getchar()
    let vals = [VarType(cchar),cchar]
    if VarType(cchar) == 'string'
      call add(vals, cchar)
      if match(cchar, "\<BS>") != -1
        let fstr = substitute(fstr,'.$','','')
      elseif cchar == ''
        let grabkeys = v:false
      else
        let fstr = fstr . cchar
      endif
    elseif VarType(cchar) == 'number'
      call add(vals, nr2char(cchar))
      if cchar == 8
        let fstr = substitute(fstr,'.$','','')
      elseif cchar == 27
        let grabkeys = v:false
      elseif cchar == 13
        let grabkeys = v:false
        let keep_filter = v:true
      else
        let fstr = fstr . nr2char(cchar)
      endif
    else
      call add(vals, string(cchar))
    endif

    call add(g:hiiro_captured_keys, vals)

    let pattern = copy(fstr)
    let pattern = substitute(pattern, '[*][?]', '{-}', 'ge')
    let pattern = substitute(pattern, '[+][?]', '{-1,}', 'ge')
    let pattern = substitute(pattern, '\\\@<!|', '\\|', 'ge')
    let pattern = substitute(pattern, '\\\@<!{', '\\{', 'ge')

    let mmsc = []
    let mmec = []
    let match_start = 0
    while match(pattern, '{', match_start) != -1
      call add(mmsc, match(pattern, '{', match_start))
      let match_start = get(mmsc,-1) + 1
    endwhile

    let match_start = 0
    while match(pattern, '}', match_start) != -1
      call add(mmec, match(pattern, '}', match_start))
      let match_start = get(mmec,-1) + 1
    endwhile

    for i in range(len(mmsc) - len(mmec))
      let pattern = pattern . '}'
    endfor

    let pattern = escape(pattern, '\')
    let pattern = escape(pattern, '()|?+{}')

    let flines = filter(copy(all_lines), 'v:val =~? "' . pattern . '"')

    call H__prompt('Filter', fstr, flines)
  endwhile

  if keep_filter == v:false
    execute '%d'
    execute '0put=all_lines'
    call cursor(1,1)
    redraw
  endif
  let &l:more = olmore
endfun

function! H_process(...)
  let text = getline('.')
  let patterns = [['^\s*\$>\?\s*','H_process_sh']]
  let patterns = H__lpush(['^\s*\(fuzzy_filter\|fmatch\):\s*','H_process_fuzzy'], patterns)
  let patterns = H__lpush(['^\s*\(regex_filter\|rematch\):\s*','H_process_regex'], patterns)
  let patterns = H__lpush(['^\s*\(fuzzy_filter\|fmatch\)!\s*','H_process_fuzzy_remove'], patterns)
  let patterns = H__lpush(['^\s*\(regex_filter\|rematch\)!\s*','H_process_regex_remove'], patterns)

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
  call H__fdir(outfile)
  call H__puts('a:text => %s', string(a:text))
  let cmd = substitute(a:text, '\ze\(&\?>>*\|$\)', ' | tee >' . outfile . ' ', '')
  call H__puts('cmd => %s', string(cmd))
  call H__sh(cmd)
  if filereadable(outfile)
    let filterfile = H__file('~/hii/sh/filter/%s.log', epoch)
    call H__fdir(filterfile)
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
  if call('HHandler', H__lpush('H_list',a:000)) == 1
    return 1
  endif

  let split_window = v:true
  for fname in a:000
    let ffname = '~/lists/' . fname

    if filereadable(expand(ffname . '.md'))
      let ffname = ffname . '.md'
      let fname = fname . '.md'
    endif

    call H__fdir(ffname)

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
