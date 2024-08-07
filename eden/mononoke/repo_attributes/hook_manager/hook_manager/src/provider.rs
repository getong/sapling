/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

pub mod memory;
pub mod text_only;

use std::collections::HashMap;

use async_trait::async_trait;
use bookmarks_types::BookmarkKey;
use bytes::Bytes;
use changeset_info::ChangesetInfo;
use context::CoreContext;
use mononoke_types::ChangesetId;
use mononoke_types::ContentId;
use mononoke_types::ContentMetadataV2;
use mononoke_types::MPath;
use mononoke_types::NonRootMPath;

use crate::errors::HookFileContentProviderError;

/// Trait implemented by providers of content for hooks to analyze.
#[async_trait]
pub trait HookFileContentProvider: Send + Sync {
    /// The size of a file with a particular content id.
    async fn get_file_metadata<'a>(
        &'a self,
        ctx: &'a CoreContext,
        id: ContentId,
    ) -> Result<ContentMetadataV2, HookFileContentProviderError>;

    /// The text of a file with a particular content id.  If the content is
    /// not appropriate to analyze (e.g. because it is too large), then the
    /// provider may return `None`.
    async fn get_file_text<'a>(
        &'a self,
        ctx: &'a CoreContext,
        id: ContentId,
    ) -> Result<Option<Bytes>, HookFileContentProviderError>;

    /// Find the content of a set of files at a particular bookmark.
    async fn find_content<'a>(
        &'a self,
        ctx: &'a CoreContext,
        bookmark: BookmarkKey,
        paths: Vec<NonRootMPath>,
    ) -> Result<HashMap<NonRootMPath, PathContent>, HookFileContentProviderError>;

    /// Find all changes between two changeset ids.
    async fn file_changes<'a>(
        &'a self,
        ctx: &'a CoreContext,
        new_cs_id: ChangesetId,
        old_cs_id: ChangesetId,
    ) -> Result<Vec<(NonRootMPath, FileChange)>, HookFileContentProviderError>;

    /// Find the latest changesets that affected a set of paths at a particular bookmark.
    async fn latest_changes<'a>(
        &'a self,
        ctx: &'a CoreContext,
        bookmark: BookmarkKey,
        paths: Vec<NonRootMPath>,
    ) -> Result<HashMap<NonRootMPath, ChangesetInfo>, HookFileContentProviderError>;

    /// Find the count of child entries in a set of paths
    async fn directory_sizes<'a>(
        &'a self,
        ctx: &'a CoreContext,
        changeset_id: ChangesetId,
        paths: Vec<MPath>,
    ) -> Result<HashMap<MPath, u64>, HookFileContentProviderError>;
}

#[derive(Clone, Debug)]
pub enum PathContent {
    Directory,
    File(ContentId),
}

#[derive(Clone, Debug)]
pub enum FileChange {
    Added(ContentId),
    Changed(ContentId, ContentId),
    Removed,
}
