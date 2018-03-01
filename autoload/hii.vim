
function! HHandler(prefix,...)
  if a:0 == 0
    return 0
  endif

  let nfun = join([a:prefix,a:000[0]], '_')
  if exists('*' . nfun)
    if len(a:000) > 1
      let arg_list = copy(a:000)
      call call(nfun, remove(arg_list,1,-1))
    else
      call call(nfun, [])
    endif
    return 1
  else
    return 0
  end
endfunction

function! H(...)
  if call('HHandler', extend(['H'],a:000)) == 1
    return 1
  endif
  return 0

endfunction

function! H_process(...)
  let text = getline('.')
  let patterns = [['^\s*\$\s\+','H_process_sh'],['^\s*\$>\s*','H_process_sh'],['^\s*fuzzy_filter:\s*','H_process_fuzzy'],['^\s*regex_filter:\s*','H_process_regex']]
  for [regex,fname] in patterns
    if match(text,regex) >= 0 && exists('*' . fname)
      call call(fname, [regex,text,substitute(text,regex,'','')])
      return 1
    endif
  endfor

  echo 'no handler found for this prefix on this line'
  return 0
endfunction

function! H_process_sh(regex,line,text)
  let epoch = strftime('%s')
  let outfile = expand('~/hii/sh/' . epoch . '.log')
  call system('mkdir -pv $(dirname ' . shellescape(outfile) . ')')
  echo 'a:text => ' . string(a:text)
  let cmd = substitute(a:text, '\ze\(&\?>>*\|$\)', ' | tee >' . outfile . ' ', '')
  echo 'cmd => ' . string(cmd)
  call system(cmd)
  if filereadable(outfile)
    let filterfile = expand('~/hii/sh/filter/' . epoch . '.log')
    call system('mkdir -pv $(dirname ' . shellescape(filterfile) . ')')
    call system('cp -v ' . outfile . ' ' . filterfile)
    execute 'vs ' . filterfile
  else
    echo 'ERROR: outfile (' . outfile . ') not created!'
  endif
endfunction

function! H_process_regex(regex,line,text)
  execute('delete ' . line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  echom 'regex pattern: "' . pattern . '"'
  execute 'v/' . pattern . '/d'
endfunction

function! H_process_fuzzy(regex,line,text)
  execute('delete ' . line('.'))
  let pattern = substitute(a:text, '^\s*\|\s*$', '', 'g')
  let pattern = join(split(pattern, '\ze.'),'.\{-}')
  echom 'fuzzy pattern: "' . pattern . '"'
  execute 'v/' . pattern . '/d'
endfunction

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

command! -nargs=+ H call H(<f-args>)

