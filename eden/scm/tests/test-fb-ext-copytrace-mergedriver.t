
Be sure to record copy metadata.
  $ hg log -r . -p --config diff.git=true
  commit:      599c51a4e5d9
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     B2
  
  diff --git a/B b/B
  new file mode 100644
  --- /dev/null
  +++ b/B
  @@ -0,0 +1,1 @@
  +B
  \ No newline at end of file
  diff --git a/A b/D
  copy from A
  copy to D
  diff --git a/A b/E
  copy from A
  copy to E