# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ CACHEDIR=$PWD/cachepath
  $ . "${TEST_FIXTURES}/library.sh"

# setup config repo

  $ REPOTYPE="blob_files"
  $ setup_common_config $REPOTYPE
  $ cd $TESTTMP

# 1. Setup nolfs hg repo, create several commit to it
  $ hginit_treemanifest repo
  $ cd repo

# Commit small file
  $ echo s > smallfile
  $ hg commit -Aqm "add small file"
  $ hg bookmark master_bookmark -r tip
  $ cd ..

  $ blobimport repo/.hg repo

# 2. Setup Mononoke.
  $ start_and_wait_for_mononoke_server
# 3. Clone hg server repo to hg client repo
  $ hg clone -q mono:repo repo-client --noupdate
  $ cd repo-client

  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > pushrebase =
  > EOF

  $ hg pull -q
  $ hg update -r master_bookmark -q

# 4. Make a commit with corrupted file node, Change file node text
  $ echo "hello_world" > file
  $ hg commit -Aqm "commit"

Corrupt file contents via an extension:
  $ cat > $TESTTMP/corrupt.py <<EOF
  > def _revision(orig, rfl, node, raw=False):
  >     return orig(rfl, node, raw).replace(b"hello_world", b"aaaaaaaaaaa")
  > from edenscm import extensions
  > from edenscm.ext import remotefilelog
  > def uisetup(ui):
  >     extensions.wrapfunction(remotefilelog.remotefilelog.remotefilelog, "revision", _revision)
  > EOF


Do a push, but disable cache verification on the client side, otherwise
filenode won't be send at all
  $ hg push -r . --to master_bookmark -v --config remotefilelog.validatecachehashes=False --config extensions.corrupt=$TESTTMP/corrupt.py
  pushing rev cb67355f2348 to destination mono:repo bookmark master_bookmark
  searching for changes
  validated revset for rebase
  1 changesets found
  uncompressed size of bundle content:
       182 (changelog)
       140  file
  remote: Command failed
  remote:   Error:
  remote:     Error while uploading data for changesets, hashes: [HgChangesetId(HgNodeHash(Sha1(cb67355f234869bb9bf94787d5a69e21e23a8c9b)))]
  remote: 
  remote:     Caused by:
  remote:         0: While creating Changeset Some(HgNodeHash(Sha1(cb67355f234869bb9bf94787d5a69e21e23a8c9b))), uuid: * (glob)
  remote:         1: While creating and verifying Changeset for blobstore
  remote:         2: While processing entries
  remote:         3: While uploading child entries
  remote:         4: While walking dependencies of Root Manifest with id HgManifestId(HgNodeHash(Sha1(314550e1ace48fe6245515c137b38ea8aeb04c7d)))
  remote:         5: Inconsistent node hash for entry: path file 'file', provided: 979d39e9dea4d1f3f1fea701fd4d3bae43eef76b, computed: d159b93d975921924ad128d6a46ef8b1b8f28ba5
  abort: unexpected EOL, expected netstring digit
  [255]
