{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections #-}

module Test.Property.Godx.Db.Types
  ( genGodx
  , tests
  ) where

import           Godx.Chain.Common (maxIsaacVal)

import qualified Data.Aeson as Aeson
import           Data.Bifunctor (first)
import           Data.Int (Int64)
import           Data.Ratio ((%))
import qualified Data.Text as Text
import           Data.WideWord.Word128 (Word128 (..))
import           Data.Word (Word64)

import           Database.Persist.Class (PersistField (..))
import           Database.Persist.Types (PersistValue (..))

import           Godx.Db

import           Numeric.Natural (Natural)

import           Hedgehog (Gen, Property, discover, (===))
import qualified Hedgehog as H
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range


prop_roundtrip_Godx_via_JSON :: Property
prop_roundtrip_Godx_via_JSON =
  H.withTests 5000 . H.property $ do
    mv <- H.forAll genGodx
    H.tripping mv Aeson.encode Aeson.eitherDecode

prop_roundtrip_DbInt65_PersistField :: Property
prop_roundtrip_DbInt65_PersistField =
    H.withTests 5000 . H.property $ do
      (i65, pv) <- H.forAll genDbInt65PresistValue
      fromPersistValue pv === Right i65

prop_roundtrip_DbIsaac_PersistField :: Property
prop_roundtrip_DbIsaac_PersistField =
    H.withTests 5000 . H.property $ do
      (w64, pv) <- H.forAll genDbIsaacPresistValue
      fromPersistValue pv === Right w64

prop_roundtrip_DbWord64_PersistField :: Property
prop_roundtrip_DbWord64_PersistField =
    H.withTests 5000 . H.property $ do
      (w64, pv) <- H.forAll genDbWord64PresistValue
      fromPersistValue pv === Right w64

prop_roundtrip_Word128_PersistField :: Property
prop_roundtrip_Word128_PersistField =
  H.withTests 5000 . H.property $ do
    w128 <- H.forAll genWord128
    H.tripping w128 toPersistValue fromPersistValue

-- -----------------------------------------------------------------------------

genGodx :: Gen Godx
genGodx =
    word64ToGodx <$> genWord64Godx
  where
    genWord64Godx :: Gen Word64
    genWord64Godx =
      Gen.choice
        [ Gen.word64 (Range.linear 0 maxIsaacVal) -- Full range
        , Gen.word64 (Range.linear 0 5000)           -- Small values
        , Gen.word64 (Range.linear (maxIsaacVal - 5000) maxIsaacVal) -- Near max.
        ]

genDbWord64 :: Gen DbWord64
genDbWord64 = DbWord64 <$> genWord64

genDbInt65PresistValue :: Gen (DbInt65, PersistValue)
genDbInt65PresistValue = do
    (w64, pv) <- genWord64PresistValue
    Gen.element
      [ (PosInt65 w64, pv)
      , if w64 == 0
          then (PosInt65 0, pv)
          else (NegInt65 w64, negatePresistValue pv)
      ]
  where
    negatePresistValue :: PersistValue -> PersistValue
    negatePresistValue pv =
      case pv of
        PersistText txt -> PersistText ("-" <> txt)
        PersistInt64 i64 -> PersistInt64 (negate i64)
        PersistRational r -> PersistRational (negate r)
        _other -> pv


genDbIsaacPresistValue :: Gen (DbIsaac, PersistValue)
genDbIsaacPresistValue = first DbIsaac <$> genWord64PresistValue

genDbWord64PresistValue :: Gen (DbWord64, PersistValue)
genDbWord64PresistValue = first DbWord64 <$> genWord64PresistValue

genNatural :: Gen Natural
genNatural = fromIntegral <$> Gen.word (Range.linear 0 5000)

genWord64PresistValue :: Gen (Word64, PersistValue)
genWord64PresistValue =
  Gen.choice
    [ (\w64 -> (w64, PersistText (Text.pack $ show w64))) <$> genWord64
    , (\i64 -> (fromIntegral i64, PersistInt64 i64)) . fromIntegral <$> Gen.int64 (Range.linear 0 (maxBound :: Int64))
    , (\w64 -> (w64, PersistRational (fromIntegral w64 % 1))) <$> genWord64
    ]

genWord128 :: Gen Word128
genWord128 = Word128 <$> genWord64 <*> genWord64

genWord64 :: Gen Word64
genWord64 =
  Gen.choice
    [ Gen.word64 Range.constantBounded
    , Gen.word64 (Range.linear 0 5000)           -- Small values
    , Gen.word64 (Range.linear (maxBound - 5000) maxBound) -- Near max.
    ]

-- -----------------------------------------------------------------------------

tests :: IO Bool
tests = H.checkParallel $$discover
