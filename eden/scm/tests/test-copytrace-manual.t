
#require no-eden

  $ enable rebase 
  $ hg rebase -r $C -d $D --config=ui.interactive=1 --config copytrace.dagcopytrace=False << EOS
  other [source] changed A which local [dest] is missing
  hint: the missing file was probably deleted by commit c43198279945 in the branch rebasing onto
  use (c)hanged version, leave (d)eleted, or leave (u)nresolved, or input (r)enamed path? r