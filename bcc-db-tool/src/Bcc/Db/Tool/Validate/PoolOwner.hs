module Godx.Db.Tool.Validate.PoolOwner
  ( validateAllPoolsHaveOwners
  ) where

import           Godx.Db.Tool.Validate.Util

import           Godx.Db

import           Control.Monad.IO.Class (MonadIO)
import           Control.Monad.Trans.Reader (ReaderT)

import           Database.Esqueleto.Legacy (Value (..), countRows, from, notExists, select, unValue,
                   where_, (==.), (^.))

import           Database.Persist.Sql (SqlBackend)


validateAllPoolsHaveOwners :: IO ()
validateAllPoolsHaveOwners = do
  putStrF "All pools have owners : "
  count <- runDbNoLogging queryPoolsWithoutOwners
  if count == 0
    then putStrLn $ greenText "ok"
    else putStrLn $ redText ("Failed, " ++ show count ++ " pools are without owners.")

-- -----------------------------------------------------------------------------

-- select * from pool_hash
--  where not exists (select * from pool_owner where pool_owner.pool_hash_id = pool_hash.id) ;

queryPoolsWithoutOwners :: MonadIO m => ReaderT SqlBackend m Int
queryPoolsWithoutOwners = do
    res <- select . from $ \ phash -> do
              where_ . notExists . from $ \ powner -> do
                where_ (phash ^. PoolHashId ==. powner ^. PoolOwnerPoolHashId)
              pure countRows
    pure $ maybe 0 unValue (listToMaybe res)
