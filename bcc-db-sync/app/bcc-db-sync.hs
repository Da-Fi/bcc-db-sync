{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

import           Godx.Prelude

import           Godx.Config.Git.Rev (gitRev)

import           Godx.DbSync (defDbSyncNodePlugin, runDbSyncNode)
import           Godx.DbSync.Metrics (withMetricSetters)

import           Godx.Sync.Config
import           Godx.Sync.Config.Types

import           Godx.Slotting.Slot (SlotNo (..))

import           Data.String (String)
import qualified Data.Text as Text
import           Data.Version (showVersion)

import           Options.Applicative (Parser, ParserInfo)
import qualified Options.Applicative as Opt

import           MigrationValidations (KnownMigration (..), knownMigrations)
import           Paths_bcc_db_sync (version)

import           System.Info (arch, compilerName, compilerVersion, os)


main :: IO ()
main = do
  cmd <- Opt.execParser opts
  case cmd of
    CmdVersion -> runVersionCommand
    CmdRun params -> do
        prometheusPort <- dncPrometheusPort <$> readSyncNodeConfig (enpConfigFile params)

        withMetricSetters prometheusPort $ \metricsSetters ->
            runDbSyncNode metricsSetters defDbSyncNodePlugin knownMigrationsPlain params
  where
    knownMigrationsPlain :: [(Text, Text)]
    knownMigrationsPlain = (\x -> (hash x, filepath x)) <$> knownMigrations

-- -------------------------------------------------------------------------------------------------

opts :: ParserInfo SyncCommand
opts =
  Opt.info (pCommandLine <**> Opt.helper)
    ( Opt.fullDesc
    <> Opt.progDesc "Godx PostgreSQL sync node."
    )

pCommandLine :: Parser SyncCommand
pCommandLine =
  asum
    [ pVersionCommand
    , CmdRun <$> pRunDbSyncNode
    ]

pRunDbSyncNode :: Parser SyncNodeParams
pRunDbSyncNode =
  SyncNodeParams
    <$> pConfigFile
    <*> pSocketPath
    <*> pLedgerStateDir
    <*> pMigrationDir
    <*> optional pSlotNo

pConfigFile :: Parser ConfigFile
pConfigFile =
  ConfigFile <$> Opt.strOption
    ( Opt.long "config"
    <> Opt.help "Path to the db-sync node config file"
    <> Opt.completer (Opt.bashCompleter "file")
    <> Opt.metavar "FILEPATH"
    )

pLedgerStateDir :: Parser LedgerStateDir
pLedgerStateDir =
  LedgerStateDir <$> Opt.strOption
    (  Opt.long "state-dir"
    <> Opt.help "The directory for persistung ledger state."
    <> Opt.completer (Opt.bashCompleter "directory")
    <> Opt.metavar "FILEPATH"
    )

pMigrationDir :: Parser MigrationDir
pMigrationDir =
  MigrationDir <$> Opt.strOption
    (  Opt.long "schema-dir"
    <> Opt.help "The directory containing the migrations."
    <> Opt.completer (Opt.bashCompleter "directory")
    <> Opt.metavar "FILEPATH"
    )

pSocketPath :: Parser SocketPath
pSocketPath =
  SocketPath <$> Opt.strOption
    ( Opt.long "socket-path"
    <> Opt.help "Path to a bcc-node socket"
    <> Opt.completer (Opt.bashCompleter "file")
    <> Opt.metavar "FILEPATH"
    )

pSlotNo :: Parser SlotNo
pSlotNo =
  SlotNo <$> Opt.option Opt.auto
    (  Opt.long "rollback-to-slot"
    <> Opt.help "Force a rollback to the specified slot (mainly for testing and debugging)."
    <> Opt.metavar "WORD"
    )

pVersionCommand :: Parser SyncCommand
pVersionCommand =
  asum
    [ Opt.subparser
        ( mconcat
          [ command' "version" "Show the program version" (pure CmdVersion) ]
        )
    , Opt.flag' CmdVersion
        (  Opt.long "version"
        <> Opt.help "Show the program version"
        <> Opt.hidden
        )
    ]

command' :: String -> String -> Parser a -> Opt.Mod Opt.CommandFields a
command' c descr p =
  Opt.command c
    $ Opt.info (p <**> Opt.helper)
    $ mconcat [ Opt.progDesc descr ]

runVersionCommand :: IO ()
runVersionCommand = do
    liftIO . putTextLn $ mconcat
                [ "bcc-db-sync ", renderVersion version
                , " - ", Text.pack os, "-", Text.pack arch
                , " - ", Text.pack compilerName, "-", renderVersion compilerVersion
                , "\ngit revision ", gitRev
                ]
  where
    renderVersion = Text.pack . showVersion
