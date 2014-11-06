#if !MIN_VERSION_base(4,7,0)
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ExistentialQuantification #-}
#if !MIN_VERSION_base(4,6,0)
{-# LANGUAGE KindSignatures #-}
#endif
#endif
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

import Data.Rank1Typeable
import Data.Rank1Dynamic

#if MIN_VERSION_base(4,7,0)
import Data.Constraint (Dict(..))
#else
import qualified Data.Typeable as Typeable (Typeable(..),Typeable1(..), mkTyCon3, mkTyConApp)
#endif
import Test.HUnit hiding (Test)
import Test.Framework
import Test.Framework.Providers.HUnit
import Unsafe.Coerce


main :: IO ()
main = defaultMain tests

#if MIN_VERSION_base(4,7,0)
deriving instance Typeable Monad
#else
data MonadDict m = Monad m => MonadDict

instance Typeable.Typeable1 m => Typeable (MonadDict m) where
  typeOf _ = Typeable.mkTyConApp (Typeable.mkTyCon3 "main" "Main" "MonadDict")
               [ Typeable.typeOf1 (undefined :: m a) ]

returnD :: MonadDict m -> a -> m a
returnD MonadDict = return
#endif

tests :: [Test]
tests =
  [ testGroup "Examples of isInstanceOf"
      [ testCase "CANNOT use a term of type 'Int -> Bool' as 'Int -> Int'" $
          typeOf (undefined :: Int -> Int) `isInstanceOf` typeOf (undefined :: Int -> Bool)
          @?= Left "Cannot unify Int and Bool"

      , testCase "CAN use a term of type 'forall a. a -> Int' as 'Int -> Int'" $
          typeOf (undefined :: Int -> Int) `isInstanceOf` typeOf (undefined :: ANY -> Int)
          @?= Right ()

      , testCase "CAN use a term of type 'forall a b. a -> b' as 'forall a. a -> a'" $
          typeOf (undefined :: ANY -> ANY) `isInstanceOf` typeOf (undefined :: ANY -> ANY1)
          @?= Right ()

      , testCase "CANNOT use a term of type 'forall a. a -> a' as 'forall a b. a -> b'" $
          typeOf (undefined :: ANY -> ANY1) `isInstanceOf` typeOf (undefined :: ANY -> ANY)
          @?= Left "Cannot unify Succ and Zero"

      , testCase "CAN use a term of type 'forall a. a' as 'forall a. a -> a'" $
          typeOf (undefined :: ANY -> ANY) `isInstanceOf` typeOf (undefined :: ANY)
          @?= Right ()

      , testCase "CANNOT use a term of type 'forall a. a -> a' as 'forall a. a'" $
          typeOf (undefined :: ANY) `isInstanceOf` typeOf (undefined :: ANY -> ANY)
#if MIN_VERSION_base(4,7,0)
          @?= Left "Cannot unify Skolem and (->)"
#else
          @?= Left "Cannot unify Skolem and ->"
#endif

      , testCase "CAN use a term of type 'forall a. a -> m a' as 'Int -> Maybe Int'" $
          typeOf (undefined :: Int -> Maybe Int)
            `isInstanceOf`
#if MIN_VERSION_base(4,6,0)
               typeOf (undefined :: ANY1 -> ANY ANY1)
#else
               typeOf (undefined :: ANY1 -> ANY (ANY1 :: *))
#endif
          @?= Right ()

      , testCase "CAN use a term of type 'forall a. Monad a => a -> m a' as 'Int -> Maybe Int'" $
#if MIN_VERSION_base(4,7,0)
          typeOf ((\Dict -> return) :: Dict (Monad Maybe) -> Int -> Maybe Int)
            `isInstanceOf`
               typeOf ((\Dict -> return) :: Dict (Monad ANY) -> ANY1 -> ANY ANY1)
#else
          typeOf (returnD :: MonadDict Maybe -> Int -> Maybe Int)
            `isInstanceOf`
#if MIN_VERSION_base(4,6,0)
               typeOf (returnD :: MonadDict ANY -> ANY1 -> ANY ANY1)
#else
               typeOf (returnD :: MonadDict ANY -> ANY1 -> ANY (ANY1 :: *))
#endif
#endif
          @?= Right ()
      ]

  , testGroup "Examples of funResultTy"
      [ testCase "Apply fn of type (forall a. a -> a) to arg of type Bool gives Bool" $
          show (funResultTy (typeOf (undefined :: ANY -> ANY)) (typeOf (undefined :: Bool)))
          @?= "Right Bool"

      , testCase "Apply fn of type (forall a b. a -> b -> a) to arg of type Bool gives forall a. a -> Bool" $
          show (funResultTy (typeOf (undefined :: ANY -> ANY1 -> ANY)) (typeOf (undefined :: Bool)))
          @?= "Right (ANY -> Bool)" -- forall a. a -> Bool

      , testCase "Apply fn of type (forall a. (Bool -> a) -> a) to argument of type (forall a. a -> a) gives Bool" $
          show (funResultTy (typeOf (undefined :: (Bool -> ANY) -> ANY)) (typeOf (undefined :: ANY -> ANY)))
          @?= "Right Bool"

      , testCase "Apply fn of type (forall a b. a -> b -> a) to arg of type (forall a. a -> a) gives (forall a b. a -> b -> b)" $
        show (funResultTy (typeOf (undefined :: ANY -> ANY1 -> ANY)) (typeOf (undefined :: ANY1 -> ANY1)))
        @?= "Right (ANY -> ANY1 -> ANY1)"

      , testCase "Cannot apply function of type (forall a. (a -> a) -> a -> a) to arg of type (Int -> Bool)" $
          show (funResultTy (typeOf (undefined :: (ANY -> ANY) -> (ANY -> ANY))) (typeOf (undefined :: Int -> Bool)))
          @?= "Left \"Cannot unify Int and Bool\""
      ]

  , testGroup "Examples of fromDynamic"
      [ testCase "CANNOT use a term of type 'Int -> Bool' as 'Int -> Int'" $
          do f <- fromDynamic (toDynamic (even :: Int -> Bool))
             return $ (f :: Int -> Int) 0
          @?= Left "Cannot unify Int and Bool"

      , testCase "CAN use a term of type 'forall a. a -> Int' as 'Int -> Int'" $
          do f <- fromDynamic (toDynamic (const 1 :: ANY -> Int))
             return $ (f :: Int -> Int) 0
          @?= Right 1

      , testCase "CAN use a term of type 'forall a b. a -> b' as 'forall a. a -> a'" $
          do f <- fromDynamic (toDynamic (unsafeCoerce :: ANY1 -> ANY2))
             return $ (f :: Int -> Int) 0
          @?= Right 0

      , testCase "CANNOT use a term of type 'forall a. a -> a' as 'forall a b. a -> b'" $
          do f <- fromDynamic (toDynamic (id :: ANY -> ANY))
             return $ (f :: Int -> Bool) 0
          @?= Left "Cannot unify Bool and Int"

      , testCase "CAN use a term of type 'forall a. a' as 'forall a. a -> a'" $
          case do f <- fromDynamic (toDynamic (undefined :: ANY))
                  return $ (f :: Int -> Int) 0
               of
            Right _ -> return ()
            result  -> assertFailure $ "Expected 'Right _' but got '" ++ show result ++ "'"

      , testCase "CANNOT use a term of type 'forall a. a -> a' as 'forall a. a'" $
          do f <- fromDynamic (toDynamic (id :: ANY -> ANY)) ; return $ (f :: Int)
#if MIN_VERSION_base(4,7,0)
          @?= Left "Cannot unify Int and (->)"
#else
          @?= Left "Cannot unify Int and ->"
#endif

      , testCase "CAN use a term of type 'forall a. Monad a => a -> m a' as 'Int -> Maybe Int'" $
#if MIN_VERSION_base(4,7,0)
          do f <- fromDynamic (toDynamic ((\Dict -> return) :: Dict (Monad Maybe) -> Int -> Maybe Int))
             return $ (f :: Dict (Monad Maybe) -> Int -> Maybe Int) Dict 0
#else
          do f <- fromDynamic (toDynamic (returnD :: MonadDict Maybe -> Int -> Maybe Int))
             return $ ((f :: MonadDict Maybe -> Int -> Maybe Int) MonadDict) 0
#endif
          @?= Right (Just 0)
      ]

  , testGroup "Examples of dynApply"
      [ testCase "Apply fn of type (forall a. a -> a) to arg of type Bool gives Bool" $
          do app <- toDynamic (id :: ANY -> ANY) `dynApply` toDynamic True
             f <- fromDynamic app
             return $ (f :: Bool)
          @?= Right True

      , testCase "Apply fn of type (forall a b. a -> b -> a) to arg of type Bool gives forall a. a -> Bool" $
          do app <- toDynamic (const :: ANY -> ANY1 -> ANY) `dynApply` toDynamic True
             f <- fromDynamic app
             return $ (f :: Int -> Bool) 0
          @?= Right True

      , testCase "Apply fn of type (forall a. (Bool -> a) -> a) to argument of type (forall a. a -> a) gives Bool" $
          do app <- toDynamic (($ True) :: (Bool -> ANY) -> ANY) `dynApply` toDynamic (id :: ANY -> ANY)
             f <- fromDynamic app
             return (f :: Bool)
          @?= Right True

      , testCase "Apply fn of type (forall a b. a -> b -> a) to arg of type (forall a. a -> a) gives (forall a b. a -> b -> b)" $
          do app <- toDynamic (const :: ANY -> ANY1 -> ANY) `dynApply` toDynamic (id :: ANY -> ANY)
             f <- fromDynamic app ; return $ (f :: Int -> Bool -> Bool) 0 True
          @?= Right True

      , testCase "Cannot apply function of type (forall a. (a -> a) -> a -> a) to arg of type (Int -> Bool)" $
          do app <- toDynamic ((\f -> f . f) :: (ANY -> ANY) -> ANY -> ANY) `dynApply` toDynamic (even :: Int -> Bool) ; f <- fromDynamic app ; return (f :: ())
          @?= Left "Cannot unify Int and Bool"
      ]
  ]