/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {CommitRev, CommitStackState} from '../commitStackState';
import type {DiffCommit, PartiallySelectedDiffCommit} from '../diffSplitTypes';
import {
  bumpStackEditMetric,
  findStartEndRevs,
  SplitRangeRecord,
  type UseStackEditState,
} from './stackEditState';

import {Button} from 'isl-components/Button';
import {InlineErrorBadge} from 'isl-components/ErrorNotice';
import {Icon} from 'isl-components/Icon';
import {Tooltip} from 'isl-components/Tooltip';
import {useEffect, useState} from 'react';
import {randomId} from 'shared/utils';
import {Column} from '../../ComponentUtils';
import {useGeneratedFileStatuses} from '../../GeneratedFile';
import {Internal} from '../../Internal';
import {tracker} from '../../analytics';
import {useFeatureFlagSync} from '../../featureFlags';
import {t, T} from '../../i18n';
import {GeneratedStatus} from '../../types';
import {applyDiffSplit, diffCommit} from '../diffSplit';
import {next} from '../revMath';

type AISplitButtonProps = {
  stackEdit: UseStackEditState;
  commitStack: CommitStackState;
  subStack: CommitStackState;
  rev: CommitRev;
};

type AISplitButtonLoadingState =
  | {type: 'READY'}
  | {type: 'LOADING'; id: string}
  | {type: 'ERROR'; error: Error};

export function AISplitButton({stackEdit, commitStack, subStack, rev}: AISplitButtonProps) {
  const {splitCommitWithAI} = Internal;
  const enableAICommitSplit =
    useFeatureFlagSync(Internal.featureFlags?.AICommitSplit) && splitCommitWithAI != null;

  const [loadingState, setLoadingState] = useState<AISplitButtonLoadingState>({type: 'READY'});

  // Make first commit be emphasized if there's only one commit (size == 2 due to empty right commit)
  const emphasize = rev === 0 && commitStack.size === 2;

  // Reset state if commitStack changes while in LOADING state. E.g., user manually updated commits locally.
  useEffect(() => {
    if (loadingState.type === 'LOADING') {
      setLoadingState({type: 'READY'});
    }
    return () => {
      // Cancel loading state when unmounted
      setLoadingState({type: 'READY'});
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [commitStack]); // Triggered when commitStack changes

  const applyNewDiffSplitCommits = (
    subStack: CommitStackState,
    rev: CommitRev,
    commits: ReadonlyArray<PartiallySelectedDiffCommit>,
  ) => {
    const [startRev, endRev] = findStartEndRevs(stackEdit);
    if (startRev != null && endRev != null) {
      // Replace the current, single rev with the new stack, which might have multiple revs.
      const newSubStack = applyDiffSplit(subStack, rev, commits);
      // Replace the [start, end+1] range with the new stack in the commit stack.
      const newCommitStack = commitStack.applySubStack(startRev, next(endRev), newSubStack);
      // Find the new split range.
      const endOffset = newCommitStack.size - commitStack.size;
      const startKey = newCommitStack.get(rev)?.key ?? '';
      const endKey = newCommitStack.get(next(rev, endOffset))?.key ?? '';
      const splitRange = SplitRangeRecord({startKey, endKey});
      // Update the main stack state.
      stackEdit.push(newCommitStack, {name: 'splitWithAI'}, splitRange);
    }
  };

  const diffWithoutGeneratedFiles = useDiffWithoutGeneratedFiles(subStack, rev);

  const fetch = async () => {
    if (loadingState.type === 'LOADING' || splitCommitWithAI == null) {
      return;
    }
    if (diffWithoutGeneratedFiles.files.length === 0) {
      return;
    }

    bumpStackEditMetric('clickedAiSplit');

    const id = randomId();
    setLoadingState({type: 'LOADING', id});
    try {
      const result: ReadonlyArray<PartiallySelectedDiffCommit> = await tracker.operation(
        'AISplitButtonClick',
        'SplitSuggestionError',
        undefined,
        () => splitCommitWithAI(diffWithoutGeneratedFiles),
      );
      setLoadingState(prev => {
        if (prev.type === 'LOADING' && prev.id === id) {
          const commits = result.filter(c => c.files.length > 0);
          if (commits.length > 0) {
            applyNewDiffSplitCommits(subStack, rev, commits);
          }
          return {type: 'READY'};
        }
        return prev;
      });
    } catch (err) {
      if (err != null) {
        setLoadingState(prev => {
          if (prev.type === 'LOADING' && prev.id === id) {
            return {type: 'ERROR', error: err as Error};
          }
          return prev;
        });
        return;
      }
    }
  };

  const cancel = () => {
    setLoadingState(prev => {
      const {type} = prev;
      if (type === 'LOADING' || type === 'ERROR') {
        return {type: 'READY'};
      }
      return prev;
    });
  };

  if (!enableAICommitSplit) {
    return null;
  }

  switch (loadingState.type) {
    case 'READY':
      return (
        <Tooltip title={t('Automatically split this commit using AI')} placement="bottom">
          <Button onClick={fetch} icon={!emphasize}>
            <Icon icon="sparkle" />
            <T>AI Split</T>
          </Button>
        </Tooltip>
      );
    case 'LOADING':
      return (
        <Tooltip title={t('Split is working, click to cancel')} placement="bottom">
          <Button onClick={cancel}>
            <Icon icon="loading" />
            <T>Splitting</T>
          </Button>
        </Tooltip>
      );
    case 'ERROR':
      return (
        <Column alignStart>
          <Button onClick={fetch}>
            <Icon icon="sparkle" />
            <T>Split this commit with AI</T>
          </Button>
          <InlineErrorBadge error={loadingState.error} placement="bottom">
            <T>AI Split Failed</T>
          </InlineErrorBadge>
        </Column>
      );
  }
}

function useDiffWithoutGeneratedFiles(subStack: CommitStackState, rev: CommitRev): DiffCommit {
  const diffForAllFiles = diffCommit(subStack, rev);
  const allFilePaths = diffForAllFiles.files.map(f => f.bPath);
  const generatedFileStatuses = useGeneratedFileStatuses(allFilePaths);
  const filesWithoutGeneratedFiles = diffForAllFiles.files.filter(
    f => generatedFileStatuses[f.bPath] !== GeneratedStatus.Generated,
  );
  return {
    ...diffForAllFiles,
    files: filesWithoutGeneratedFiles,
  };
}
