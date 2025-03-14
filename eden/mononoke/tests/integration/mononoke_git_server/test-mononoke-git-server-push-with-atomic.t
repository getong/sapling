# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"
  $ REPOTYPE="blob_files"
  $ export ONLY_FAST_FORWARD_BOOKMARK_REGEX=".*ffonly"
  $ setup_common_config $REPOTYPE
  $ GIT_REPO_ORIGIN="${TESTTMP}/origin/repo-git"
  $ GIT_REPO="${TESTTMP}/repo-git"

# Setup git repository
  $ mkdir -p "$GIT_REPO_ORIGIN"
  $ cd "$GIT_REPO_ORIGIN"
  $ git init -q
  $ echo "this is file1" > file1
  $ git add file1
  $ git commit -qam "Add file1"
  $ git tag -a -m "new tag" first_tag
  $ echo "this is file2" > file2
  $ git add file2
  $ git commit -qam "Add file2"
  $ master_commit=$(git rev-parse HEAD)
# Create another branch which will be fast-forward only and add a few commits to it
  $ git checkout -b branch_ffonly
  Switched to a new branch 'branch_ffonly'
  $ echo "fwd file1" > fwdfile1
  $ git add fwdfile1
  $ git commit -qam "Add fwdfile1"
  $ initial_ffonly_commit=$(git rev-parse HEAD)
  $ echo "fwd file2" > fwdfile2
  $ git add fwdfile2
  $ git commit -qam "Add fwdfile2"
  $ echo "fwd file3" > fwdfile3
  $ git add fwdfile3
  $ git commit -qam "Add fwdfile3"
# Create another branch will allow non-fast-forward updates
  $ git checkout -b non_ffwd_branch
  Switched to a new branch 'non_ffwd_branch'
  $ echo "nonfwd file1" > nonfwdfile1
  $ git add nonfwdfile1
  $ git commit -qam "Add nonfwdfile1"
  $ initial_nonffwd_commit=$(git rev-parse HEAD)
  $ echo "nonfwd file2" > nonfwdfile2
  $ git add nonfwdfile2
  $ git commit -qam "Add nonfwdfile2"
  $ git checkout master_bookmark
  Switched to branch 'master_bookmark'

  $ cd "$TESTTMP"
  $ git clone --mirror "$GIT_REPO_ORIGIN" repo-git
  Cloning into bare repository 'repo-git'...
  done.

# Import it into Mononoke
  $ cd "$TESTTMP"
  $ quiet gitimport "$GIT_REPO" --derive-hg --generate-bookmarks full-repo

# Set Mononoke as the Source of Truth
  $ set_mononoke_as_source_of_truth_for_git

# Start up the Mononoke Git Service
  $ mononoke_git_service
# Clone the Git repo from Mononoke
  $ quiet git_client clone $MONONOKE_GIT_SERVICE_BASE_URL/$REPONAME.git
# List all the known refs
  $ cd repo
  $ git show-ref | sort
  33f84db74b1f57fe45ae0fc29edc65ae984b979d refs/remotes/origin/non_ffwd_branch
  8963e1f55d1346a07c3aec8c8fc72bf87d0452b1 refs/tags/first_tag
  e8615d6f149b876be0a2f30a1c5bf0c42bf8e136 refs/heads/master_bookmark
  e8615d6f149b876be0a2f30a1c5bf0c42bf8e136 refs/remotes/origin/HEAD
  e8615d6f149b876be0a2f30a1c5bf0c42bf8e136 refs/remotes/origin/master_bookmark
  eb95862bb5d5c295844706cbb0d0e56fee405f5c refs/remotes/origin/branch_ffonly

# Add some new commits to the master_bookmark branch
  $ echo "Just another file" > another_file
  $ git add .
  $ git commit -qam "Another commit on master_bookmark"
# Try to do a non-ffwd push on branch_ffonly which should fail
  $ git checkout branch_ffonly
  Switched to a new branch 'branch_ffonly'
  ?ranch 'branch_ffonly' set up to track *branch_ffonly*. (glob)
  $ git reset --hard $initial_ffonly_commit
  HEAD is now at 3ea0687 Add fwdfile1
# Try doing a non-ffwd push on non_ffwd_branch branch which should succeed
  $ git checkout non_ffwd_branch
  Switched to a new branch 'non_ffwd_branch'
  ?ranch 'non_ffwd_branch' set up to track *non_ffwd_branch*. (glob)
  $ git reset --hard $initial_nonffwd_commit
  HEAD is now at 676bc3c Add nonfwdfile1


# Push all the changes made so far ATOMICALLY. Only non_ffwd_branch should have failed, but since we use atomic mode
# all the ref updates should fail
  $ git_client push origin master_bookmark branch_ffonly non_ffwd_branch --force --atomic
  To https://localhost:$LOCAL_PORT/repos/git/ro/repo.git
   ! [remote rejected] branch_ffonly -> branch_ffonly (Atomic bookmark update failed with error: Non fast-forward bookmark move of 'heads/branch_ffonly' from eb95862bb5d5c295844706cbb0d0e56fee405f5c to 3ea0687e31d7b65429c774526728dba90cbaabc0
  
  For more information about hooks and bypassing, refer https://fburl.com/wiki/mb4wtk1j)
   ! [remote rejected] master_bookmark -> master_bookmark (Atomic bookmark update failed with error: Non fast-forward bookmark move of 'heads/branch_ffonly' from eb95862bb5d5c295844706cbb0d0e56fee405f5c to 3ea0687e31d7b65429c774526728dba90cbaabc0
  
  For more information about hooks and bypassing, refer https://fburl.com/wiki/mb4wtk1j)
   ! [remote rejected] non_ffwd_branch -> non_ffwd_branch (Atomic bookmark update failed with error: Non fast-forward bookmark move of 'heads/branch_ffonly' from eb95862bb5d5c295844706cbb0d0e56fee405f5c to 3ea0687e31d7b65429c774526728dba90cbaabc0
  
  For more information about hooks and bypassing, refer https://fburl.com/wiki/mb4wtk1j)
  error: failed to push some refs to 'https://localhost:$LOCAL_PORT/repos/git/ro/repo.git'
  [1]

# Just push the master_bookmark branch which should succeed
  $ git_client push origin master_bookmark --atomic
  To https://localhost:$LOCAL_PORT/repos/git/ro/repo.git
     e8615d6..60fb9c7  master_bookmark -> master_bookmark

# Wait for the warm bookmark cache to catch up with the latest changes
  $ wait_for_git_bookmark_move HEAD $master_commit

# Clone the repo in a new folder
  $ cd "$TESTTMP"
  $ quiet git_client clone $MONONOKE_GIT_SERVICE_BASE_URL/$REPONAME.git new_repo  
  $ cd new_repo

# List all the known refs. Ensure that only master_bookmark reflect a change
  $ git show-ref | sort
  33f84db74b1f57fe45ae0fc29edc65ae984b979d refs/remotes/origin/non_ffwd_branch
  60fb9c7880e62a34d49662147f9af7ad50de3e99 refs/heads/master_bookmark
  60fb9c7880e62a34d49662147f9af7ad50de3e99 refs/remotes/origin/HEAD
  60fb9c7880e62a34d49662147f9af7ad50de3e99 refs/remotes/origin/master_bookmark
  8963e1f55d1346a07c3aec8c8fc72bf87d0452b1 refs/tags/first_tag
  eb95862bb5d5c295844706cbb0d0e56fee405f5c refs/remotes/origin/branch_ffonly
