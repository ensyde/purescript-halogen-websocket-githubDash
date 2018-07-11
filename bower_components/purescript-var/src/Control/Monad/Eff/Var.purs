-- | `Var`s allow to provide a uniform read/write access to the references in
-- | the `Eff` monad. This is mostly useful when making low-level FFI bindings.

-- | For example we might have some global counter with the following API:
-- | ```purescript
-- | foreign import data COUNT :: !
-- | getCounter :: forall eff. Eff (count :: COUNT | eff) Int
-- | setCounter :: forall eff. Int -> Eff (count :: COUNT | eff) Unit
-- | ```
-- |
-- | `getCounter` and `setCounter` can be kept together in a `Var`:
-- | ```purescript
-- | counter :: forall eff. Var (count :: COUNT | eff) Int
-- | counter = makeVar getCounter setCounter
-- | ```
-- |
-- | `counter` can be used in this way:
-- | ```purescript
-- | main = do
-- |   counter $= 0          -- set counter to 0
-- |   get counter >>= print -- => 0
-- |   counter $= 2          -- set counter to 2
-- |   get counter >>= print -- => 2
-- |   counter $~ (* 5)      -- multiply counter by 5
-- |   get counter >>= print -- => 10
-- | ```

module Control.Monad.Eff.Var
  ( class Gettable
  , get
  , class Settable
  , set
  , ($=)
  , class Updatable
  , update
  , ($~)
  , Var()
  , makeVar
  , GettableVar()
  , makeGettableVar
  , SettableVar()
  , makeSettableVar
  ) where

import Prelude ( class Applicative, class Apply, class Functor
               , pure, bind, apply, unit, Unit, absurd
               , (<<<), (<$>), (>>>), (>>=))
import Control.Monad.Eff (Eff, kind Effect)
import Data.Decidable (class Decidable)
import Data.Decide (class Decide)
import Data.Divide (class Divide)
import Data.Divisible (class Divisible)
import Data.Tuple (Tuple(..))
import Data.Either (either)
import Data.Functor.Contravariant (class Contravariant, (>$<))
import Data.Functor.Invariant (class Invariant)

-- | Typeclass for vars that can be read.
class Gettable (eff :: # Effect) (var :: Type -> Type) (a :: Type) | var -> a, var -> eff where
  get :: var a -> Eff eff a

-- | Typeclass for vars that can be written.
class Settable (eff :: # Effect) (var :: Type -> Type) (a :: Type) | var -> a, var -> eff where
  set :: var a -> a -> Eff eff Unit

-- | Alias for `set`.
infixr 2 set as $=

-- | Typeclass for vars that can be updated.
class Updatable (eff :: # Effect) (var :: Type -> Type) (a :: Type) | var -> a, var -> eff where
  update :: var a -> (a -> a) -> Eff eff Unit

-- | Alias for `get`
infixr 2 update as $~

-- | Read/Write var which holds a value of type `a` and produces effects `eff`
-- | when read or written.
newtype Var (eff :: # Effect) a
  = Var { gettable :: GettableVar eff a
        , settable :: SettableVar eff a
        }

-- | Create a `Var` from getter and setter.
makeVar :: forall eff a. Eff eff a -> (a -> Eff eff Unit) -> Var eff a
makeVar g s = Var { gettable, settable }
  where
    gettable = makeGettableVar g
    settable = makeSettableVar s

instance settableVar :: Settable eff (Var eff) a where
  set (Var { settable } ) = set settable

instance gettableVar :: Gettable eff (Var eff) a where
  get (Var { gettable }) = get gettable

instance updatableVar :: Updatable eff (Var eff) a where
  update v f = get v >>= f >>> set v

instance invariantVar :: Invariant (Var eff) where
  imap ab ba (Var v) = Var { gettable: ab <$> v.gettable
                           , settable: ba >$< v.settable
                           }

-- | Read-only var which holds a value of type `a` and produces effects `eff`
-- | when read.
newtype GettableVar eff a = GettableVar (Eff eff a)

-- | Create a `GettableVar` from getter.
makeGettableVar :: forall eff a. Eff eff a -> GettableVar eff a
makeGettableVar = GettableVar

instance gettableGettableVar :: Gettable eff (GettableVar eff) a where
  get (GettableVar action) = action

instance functorGettableVar :: Functor (GettableVar eff) where
  map f (GettableVar a) = GettableVar (f <$> a)

instance applyGettableVar :: Apply (GettableVar eff) where
  apply (GettableVar f) (GettableVar a) = GettableVar (apply f a)

instance applicativeGettableVar :: Applicative (GettableVar eff) where
  pure = GettableVar <<< pure

-- | Write-only var which holds a value of type `a` and produces effects `eff`
-- | when written.
newtype SettableVar eff a = SettableVar (a -> Eff eff Unit)

-- | Create a `SettableVar` from setter.
makeSettableVar :: forall eff a. (a -> Eff eff Unit) -> SettableVar eff a
makeSettableVar = SettableVar

instance settableSettableVar :: Settable eff (SettableVar eff) a where
  set (SettableVar action) = action

instance contravariantSettableVar :: Contravariant (SettableVar eff) where
  cmap f (SettableVar a) = SettableVar (a <<< f)

instance divideSettableVar :: Divide (SettableVar eff) where
  divide f (SettableVar setb) (SettableVar setc) = SettableVar \a ->
    case f a of
      Tuple b c -> do
        _ <- setb b
        setc c

instance divisibleSettableVar :: Divisible (SettableVar eff) where
  conquer = SettableVar \_ -> pure unit

instance decideSettableVar :: Decide (SettableVar eff) where
  choose f (SettableVar setb) (SettableVar setc) = SettableVar (either setb setc <<< f)

instance decidableSettableVar :: Decidable (SettableVar eff) where
--  lose :: forall a. (a -> Void) -> f a
  lose f = SettableVar (absurd <<< f)