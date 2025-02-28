module Godx.Db.Tool.Validate.Ledger
  ( LedgerValidationParams (..)
  , validateLedger
  ) where

import           Control.Monad (when)
import           Control.Monad.Trans.Except.Exit (orDie)
import           Data.Text (Text)
import qualified Data.Text as Text
import           Prelude

import qualified Godx.Db as DB
import           Godx.Db.Tool.Validate.Balance (ledgerAddrBalance)
import           Godx.Db.Tool.Validate.Util

import           Godx.Sync.Config
import           Godx.Sync.Config.Godx
import           Godx.Sync.Error
import           Godx.Sync.LedgerState
import           Godx.Sync.Tracing.ToObjectOrphans ()

import           Godx.Slotting.Slot (SlotNo (..))

import           Shardagnostic.Consensus.Godx.Node ()
import           Shardagnostic.Consensus.Ledger.Extended
import           Shardagnostic.Network.NodeToClient (withIOManager)

data LedgerValidationParams = LedgerValidationParams
  { vpConfigFile :: !ConfigFile
  , vpLedgerStateDir :: !LedgerStateDir
  , vpAddressUtxo :: !Text
  }

validateLedger :: LedgerValidationParams -> IO ()
validateLedger params =
  withIOManager $ \ _ -> do
    enc <- readSyncNodeConfig (vpConfigFile params)
    genCfg <- orDie renderSyncNodeError $ readGodxGenesisConfig enc
    ledgerFiles <- listLedgerStateFilesOrdered (vpLedgerStateDir params)
    slotNo <- SlotNo <$> DB.runDbNoLogging DB.queryLatestSlotNo
    validate params genCfg slotNo ledgerFiles

validate :: LedgerValidationParams -> GenesisConfig -> SlotNo -> [LedgerStateFile] -> IO ()
validate params genCfg slotNo ledgerFiles =
    go ledgerFiles True
  where
    go :: [LedgerStateFile] -> Bool -> IO ()
    go [] _ = putStrLn $ redText "No ledger found"
    go (ledgerFile : rest) logFailure = do
      let ledgerSlot = lsfSlotNo ledgerFile
      if ledgerSlot <= slotNo
        then do
          Right state <- loadLedgerStateFromFile (mkTopLevelConfig genCfg) False ledgerFile
          validateBalance ledgerSlot (vpAddressUtxo params) state
        else do
          when logFailure . putStrLn $ redText "Ledger is newer than DB. Trying an older ledger."
          go rest False

validateBalance :: SlotNo -> Text -> GodxLedgerState -> IO ()
validateBalance slotNo addr st = do
  balanceDB <- DB.runDbNoLogging $ DB.queryAddressBalanceAtSlot addr (unSlotNo slotNo)
  let eiBalanceLedger = DB.word64ToGodx <$> ledgerAddrBalance addr (ledgerState $ clsState st)
  case eiBalanceLedger of
    Left str -> putStrLn $ redText (Text.unpack str)
    Right balanceLedger ->
      if balanceDB == balanceLedger
        then
          putStrF $ concat
            [ "DB and Ledger balance for address ", Text.unpack addr, " at slot ", show (unSlotNo slotNo)
            , " match (", show balanceLedger, " bcc) : ", greenText "ok", "\n"
            ]
        else
          error . redText $ concat
            [ "failed: DB and Ledger balances for address ", Text.unpack addr, " don't match. "
            , "DB value (", show balanceDB, ") /= ledger value (", show balanceLedger, ")."
            ]
