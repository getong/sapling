/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! edenfsctl config

use anyhow::Result;
use async_trait::async_trait;
use clap::Parser;
use edenfs_client::instance::EdenFsInstance;

use crate::ExitCode;

#[derive(Parser, Debug)]
#[clap(about = "Clears local caches of objects stored in RocksDB")]
pub struct ClearLocalCachesCmd {}

#[async_trait]
impl crate::Subcommand for ClearLocalCachesCmd {
    async fn run(&self) -> Result<ExitCode> {
        let instance = EdenFsInstance::global();
        let client = instance.get_client();

        client.debug_clear_local_store_caches().await?;
        Ok(0)
    }
}
