
#require no-eden


Test for the full copytracing algorithm
=======================================

  $ eagerepo
  $ enable rebase
  $ setconfig copytrace.skipduplicatecopies=True

  $ newclientrepo t

  $ echo 1 > a
  $ hg ci -qAm "first"

  $ hg cp a b
  $ hg mv a c
  $ echo 2 >> b
  $ echo 2 >> c

  $ hg ci -qAm "second"

  $ hg co -C 'desc(first)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

  $ echo 0 > a
  $ echo 1 >> a

  $ hg ci -qAm "other"

  $ hg merge --debug
  resolving manifests
   branchmerge: True, force: False
   ancestor: b8bf91eeebbc, local: add3f11052fa+, remote: 17c05bb7fcb6
   preserving a for resolve of b
   preserving a for resolve of c
  removing a
   b: remote moved from a -> m (premerge)
  picktool() hgmerge internal:merge
  picked tool ':merge' for path=b binary=False symlink=False changedelete=False
  merging a and b to b
  my b@add3f11052fa+ other b@17c05bb7fcb6 ancestor a@b8bf91eeebbc
   c: remote moved from a -> m (premerge)
  picktool() hgmerge internal:merge
  picked tool ':merge' for path=c binary=False symlink=False changedelete=False
  merging a and c to c
  my c@add3f11052fa+ other c@17c05bb7fcb6 ancestor a@b8bf91eeebbc
  0 files updated, 2 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

file b
  $ cat b
  0
  1
  2

file c
  $ cat c
  0
  1
  2

Test disabling copy tracing

- first verify copy metadata was kept

  $ hg up -qC 'desc(other)'
  $ hg rebase --keep -d 'desc(second)' -b 'desc(other)'
  rebasing add3f11052fa "other"
  merging b and a to b

  $ cat b
  0
  1
  2

- next verify copy metadata is lost when disabled

  $ hg debugstrip -r .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg up -qC 'desc(other)'
  $ hg rebase --keep -d 'desc(second)' -b 'desc(other)' --config copytrace.dagcopytrace=False --config ui.interactive=True << EOF
  > c
  > EOF
  rebasing add3f11052fa "other"
  other [source] changed a which local [dest] is missing
  hint: if this is due to a renamed file, you can manually input the renamed path
  use (c)hanged version, leave (d)eleted, or leave (u)nresolved, or input (r)enamed path? c

  $ cat b
  1
  2

  $ cd ..

Verify disabling copy tracing still keeps copies from rebase source

  $ newclientrepo copydisable
  $ touch a
  $ hg ci -Aqm 'add a'
  $ touch b
  $ hg ci -Aqm 'add b, c'
  $ hg cp b x
  $ echo x >> x
  $ hg ci -qm 'copy b->x'
  $ hg up -q 'max(desc(add))'
  $ touch z
  $ hg ci -Aqm 'add z'
  $ hg log -G -T '{desc}\n'
  @  add z
  │
  │ o  copy b->x
  ├─╯
  o  add b, c
  │
  o  add a
  
  $ hg rebase -d . -b 'desc(copy)'
  rebasing 6adcf8c12e7d "copy b->x"
  $ hg up -q 'max(desc(copy))'
  $ hg log -f x -T '{desc}\n'
  copy b->x
  add b, c

  $ cd ../

Verify we duplicate existing copies, instead of detecting them

  $ newclientrepo copydisable3
  $ touch a
  $ hg ci -Aqm 'add a'
  $ hg cp a b
  $ hg ci -Aqm 'copy a->b'
  $ hg mv b c
  $ hg ci -Aqm 'move b->c'
  $ hg up -q 'desc(add)'
  $ hg cp a b
  $ echo b >> b
  $ hg ci -Aqm 'copy a->b (2)'
  $ hg log -G -T '{desc}\n'
  @  copy a->b (2)
  │
  │ o  move b->c
  │ │
  │ o  copy a->b
  ├─╯
  o  add a
  
  $ hg rebase -d 'desc(move)' -s 'max(desc(copy))'
  rebasing 47e1a9e6273b "copy a->b (2)"

  $ hg log -G -f b
  @  commit:      76024fb4b05b
  ╷  user:        test
  ╷  date:        Thu Jan 01 00:00:00 1970 +0000
  ╷  summary:     copy a->b (2)
  ╷
  o  commit:      ac82d8b1f7c4
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  
