Hey, i don't know if you remember or if you saw my `h` or `hero` extensible cmd  
in the shell.  But i made the same thing in vim

if i make the vim function `H_note(name)`  
i can run `:H note msg-to-dante` and it will open a new file in my notes dir  
called msg-to-dante.

the subcommands can go as deep as you want, so you can do:

`:H heroku deploy`

for: `H_heroku_deploy()` (would need the intermediate `H_heroku()` function tho  
that knows it accepts another set of potential subcommands.

(see: `H_list()` and `H_list_date()` for an example)

I also don't know if you've seen xiki, but this kind of lets you do stuff in  
the same vane (sp?).

so I can make a line like this in vim:

`$> ls -1`

with the cursor on that line if i run `:H process` it will run ls -1 and  
redirect the output to a file.  then it will open a copy for editing, preserving  
the original.  so i can filter the output (see below).

then you can have other lines to process like:

`regex_filter: \.log`

call `:H process` on the `regex_filter` line will remove all lines in the buffer  
that don't have `.log` in them.

another example:  

`fuzzy_filter: alog`

will remove all lines without `a.*?l.*?o.*?g` in it  
(that is a pcre regex for clarity, not the ugly vim regex:   
`a.\{-}l.\{-}o\.{-}g`)
