/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {Tooltip} from '../Tooltip';
import {Button} from '../components/Button';
import {t} from '../i18n';
import {debugToolsEnabledState} from './DebugToolsState';
import {useAtomValue} from 'jotai';
import {lazy, Suspense} from 'react';
import {Icon} from 'shared/Icon';

const DebugToolsMenu = lazy(() => import('./DebugToolsMenu'));

export function DebugToolsButton() {
  const debugEnabled = useAtomValue(debugToolsEnabledState);
  if (!debugEnabled) {
    return null;
  }
  return (
    <Tooltip
      component={dismiss => (
        <Suspense fallback={<Icon icon="loading" />}>
          <DebugToolsMenu dismiss={dismiss} />
        </Suspense>
      )}
      title={t('Debug Tools')}
      trigger="click"
      group="topbar"
      placement="bottom">
      <Button icon>
        <Icon icon="pulse" />
      </Button>
    </Tooltip>
  );
}
