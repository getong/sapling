  $ setconfig diff.git=True

setup backing repo

  $ newclientrepo
  $ drawdag <<'EOS'
  > B   # B/foo/x = bbb\n
  > |
  > A   # A/foo/x = aaa\n
  >     # drawdag.defaultfiles=false
  > EOS

  $ hg go $B -q

test subtree copy paths validation
  $ hg subtree copy -r $A
  abort: must provide --from-path and --to-path
  [255]
  $ hg subtree copy -r $A --from-path foo
  abort: must provide same number of --from-path and --to-path
  [255]
  $ hg subtree copy -r $A --from-path bar
  abort: must provide same number of --from-path and --to-path
  [255]
  $ hg subtree copy -r $A --from-path foo --to-path bar --from-path foo --to-path ""
  abort: overlapping --to-path entries
  [255]
  $ hg subtree copy -r $A --from-path nonexist --to-path bar
  abort: path 'nonexist' does not exist in commit d908813f0f7c
  [255]

test subtree copy
  $ hg subtree cp -r $A --from-path foo --to-path bar -m "subtree copy foo -> bar"
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg log -G -T '{node|short} {desc|firstline}\n'
  @  bfc51ae2a942 subtree copy foo -> bar
  │
  o  b9450a0e6ae4 B
  │
  o  d908813f0f7c A
  $ hg show --git
  commit:      bfc51ae2a942
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  description:
  subtree copy foo -> bar
  
  Subtree copy from d908813f0f7c9078810e26aad1e37bdb32013d4b
    Copied path foo to bar
  
  
  diff --git a/bar/x b/bar/x
  new file mode 100644
  --- /dev/null
  +++ b/bar/x
  @@ -0,0 +1,1 @@
  +aaa
  $ hg dbsh -c 'print(repo["."].extra())'
  {'branch': 'default', 'test_branch_info': '{"v":1,"branches":[{"from_path":"foo","to_path":"bar","from_commit":"d908813f0f7c9078810e26aad1e37bdb32013d4b"}]}'}


abort when the working copy is dirty

  $ newclientrepo
  $ drawdag <<'EOS'
  > B   # B/foo/x = bbb\n
  > |
  > A   # A/foo/x = aaa\n
  >     # drawdag.defaultfiles=false
  > EOS  
  $ hg go $B -q
  $ echo bbb >> foo/x
  $ hg st
  M foo/x
  $ hg subtree cp -r $A --from-path foo --to-path bar
  abort: uncommitted changes
  [255]

test subtree graft
  $ newclientrepo
  $ drawdag <<'EOS'
  > C   # C/foo/x = 1a\n2\n3a\n
  > |
  > B   # B/foo/x = 1a\n2\n3\n
  > |
  > A   # A/foo/x = 1\n2\n3\n
  >     # drawdag.defaultfiles=false
  > EOS
  $ hg go $C -q
  $ hg subtree copy -r $B --from-path foo --to-path bar -m 'subtree copy foo -> bar'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg subtree graft -r $C
  abort: must provide --from-path and --to-path
  [255]
  $ hg subtree graft -r $C --from-path foo
  abort: must provide --from-path and --to-path
  [255]
  $ hg subtree graft -r $C --to-path bar
  abort: must provide --from-path and --to-path
  [255]

  $ hg subtree graft -r $C --from-path foo --to-path bar
  grafting 78072751cf70 "C"
  $ hg log -G -T '{node|short} {desc|firstline}\n'
  @  0104513073ef C
  │
  o  2b14f595f5b5 subtree copy foo -> bar
  │
  o  78072751cf70 C
  │
  o  55ff286fb56f B
  │
  o  2f10237b4399 A
  $ hg show
  commit:      0104513073ef
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       bar/x
  description:
  C
  
  Grafted from 78072751cf70f1ca47671c625f3b2d7f86f45f00
  - Grafted path foo to bar
  
  
  diff --git a/bar/x b/bar/x
  --- a/bar/x
  +++ b/bar/x
  @@ -1,3 +1,3 @@
   1a
   2
  -3
  +3a