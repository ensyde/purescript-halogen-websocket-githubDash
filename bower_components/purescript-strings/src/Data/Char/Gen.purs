module Data.Char.Gen where

import Prelude

import Control.Monad.Gen (class MonadGen, chooseInt, oneOf)
import Data.Char as C
import Data.NonEmpty ((:|))

-- | Generates a character of the Unicode basic multilingual plane.
genUnicodeChar :: forall m. MonadGen m => m Char
genUnicodeChar = C.fromCharCode <$> chooseInt 0 65536

-- | Generates a character in the ASCII character set, excluding control codes.
genAsciiChar :: forall m. MonadGen m => m Char
genAsciiChar = C.fromCharCode <$> chooseInt 32 127

-- | Generates a character in the ASCII character set.
genAsciiChar' :: forall m. MonadGen m => m Char
genAsciiChar' = C.fromCharCode <$> chooseInt 0 127

-- | Generates a character that is a numeric digit.
genDigitChar :: forall m. MonadGen m => m Char
genDigitChar = C.fromCharCode <$> chooseInt 48 57

-- | Generates a character from the basic latin alphabet.
genAlpha :: forall m. MonadGen m => m Char
genAlpha = oneOf (genAlphaLowercase :| [genAlphaUppercase])

-- | Generates a lowercase character from the basic latin alphabet.
genAlphaLowercase :: forall m. MonadGen m => m Char
genAlphaLowercase = C.fromCharCode <$> chooseInt 97 122

-- | Generates an uppercase character from the basic latin alphabet.
genAlphaUppercase :: forall m. MonadGen m => m Char
genAlphaUppercase = C.fromCharCode <$> chooseInt 65 90
