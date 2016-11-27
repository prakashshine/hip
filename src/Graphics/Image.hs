{-# OPTIONS_GHC -fno-warn-unused-imports #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleContexts #-}
-- |
-- Module      : Graphics.Image
-- Copyright   : (c) Alexey Kuleshevich 2016
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
-- Haskell Image Processing (HIP) library is a wrapper around any array like
-- data structure and is fully agnostic to the underlying representation. All of
-- the functionality in this library relies upon a few type classes, which
-- corresponding representation types are instances of:
--
-- * @__`Array` arr cs e__@ - this is a base class for every
-- __@`Image`@ @arr@ @cs@ @e@__, where @__arr__@ stands for an underlying array
-- representation, @__cs__@ is the `ColorSpace` of an image and @__e__@ is the
-- type denoting precision of an image.
--
-- * @__`ManifestArray` arr cs e__@ - is a kind of array that is represented by an
-- actual data in memory.
--
-- * @__`SequentialArray` arr cs e__@ - contains functionality that can only be
-- computed sequentially.
--
-- * @__`MutableArray` arr cs e__@ - allows mutation on __@`MImage`@ @st@ @arr@ @cs@ @e@__,
-- which is `Image`'s mutable cousin.
--
-- Array representation type and the above classes it is installed in determine
-- operations that can be done on the image with that representation.
--
-- Representations using <http://hackage.haskell.org/package/vector Vector> and
-- <http://hackage.haskell.org/package/repa Repa> packages:
--
-- * `VU` - Unboxed Vector representation. (Default)
-- * `RD` - Delayed Repa array representation.
-- * `RS` - Unboxed Repa array representation (computation is done sequentially).
-- * `RP` - Unboxed Repa array representation (computation is done in parallel).
--
-- Images with `RD` type hold functions rather then actual data, so this
-- representation should be used for fusing computation together, and later
-- changed to `RS` or `RP` using `exchange`, which in turn performs the fused
-- computation.
--
-- Just as it is mentioned above, Vector representation is a default one, so in
-- order to create images with Repa representation
-- "Graphics.Image.Interface.Repa" module should be used. It has to be imported
-- as qualified, since it contains image generating functions with same names as
-- here.
--
-- Many of the function names exported by this module will clash with the ones
-- from "Prelude", hence it can be more convenient to import it qualified and
-- all relevenat types import using "Graphics.Image.Types" module:
--
-- @
-- import qualified Graphics.Image as I
-- import Graphics.Image.Types
-- @
--
module Graphics.Image (
  -- * Color Space
  -- $colorspace

  -- * Creation
  --
  -- If it is necessary to create an image in an other representation
  -- or with some specific 'Pixel' precision, you can use 'make' from
  -- "Graphics.Image.Interface" module and manually specifying function's output
  -- type, ex:
  --
  -- @ makeImage (256, 256) (PixelY . fromIntegral . fst) :: Image RP Y Word8 @
  --
  makeImage, fromLists, toLists,
  -- * IO
  -- ** Reading
  -- | Read any supported image file into an 'Image' with 'VU' (Vector Unboxed)
  -- representation and pixels with 'Double' precision. In order to read an
  -- image with different representation, color space and precision 'readImage'
  -- or 'readImageExact' from <Graphics-Image-IO.html Graphics.Image.IO> can be
  -- used.
  readImageY, readImageYA, readImageRGB, readImageRGBA, readImageExact,
  -- ** Writing
  writeImage, writeImageExact, displayImage,
  -- * Accessors
  -- ** Dimensions
  rows, cols, dims,
  -- ** Indexing
  index, maybeIndex, defaultIndex, borderIndex,
  -- * Transformation
  -- ** Pointwise
  map, imap, zipWith, izipWith,
  -- ** Geometric
  traverse, traverse2,
  transpose, backpermute,
  (|*|), 
  -- * Reduction
  fold, sum, product, maximum, minimum, normalize,
  -- * Representations
  exchange,
  VU(..), RD(..), RS(..), RP(..),
  ) where

#if MIN_VERSION_base(4,8,0)
import Prelude hiding (map, zipWith, sum, product, maximum, minimum, traverse)
#else
import Prelude hiding (map, zipWith, sum, product, maximum, minimum)
#endif
import qualified Data.Foldable as F
import Graphics.Image.ColorSpace
import Graphics.Image.IO
import Graphics.Image.Interface hiding (makeImage, fromLists)
import Graphics.Image.Interface.Vector as V
import Graphics.Image.Interface.Repa as R (RD(..), RS(..), RP(..))


import Graphics.Image.Processing
import Graphics.Image.Processing.Binary
import Graphics.Image.Processing.Complex
import Graphics.Image.Processing.Geometric
import Graphics.Image.IO.Histogram



-- | Get the number of rows in an image.
--
-- >>> frog <- readImageRGB "images/frog.jpg"
-- >>> frog
-- <Image VectorUnboxed RGB (Double): 200x320>
-- >>> rows frog
-- 200
--
rows :: Array arr cs e => Image arr cs e -> Int
rows = fst . dims
{-# INLINE rows #-}


-- | Get the number of columns in an image.
--
-- >>> frog <- readImageRGB "images/frog.jpg"
-- >>> frog
-- <Image VectorUnboxed RGB (Double): 200x320>
-- >>> cols frog
-- 320
--
cols :: Array arr cs e => Image arr cs e -> Int
cols = snd . dims
{-# INLINE cols #-}


-- | Sum all pixels in the image.
sum :: ManifestArray arr cs e => Image arr cs e -> Pixel cs e
sum = fold (+) 0
{-# INLINE sum #-}


-- | Multiply all pixels in the image.
product :: ManifestArray arr cs e => Image arr cs e -> Pixel cs e
product = fold (+) 1
{-# INLINE product #-}


-- | Retrieve the biggest pixel from an image
maximum :: (ManifestArray arr cs e, Ord (Pixel cs e)) => Image arr cs e -> Pixel cs e
maximum !img = fold max (index img (0, 0)) img
{-# INLINE maximum #-}


-- | Retrieve the smallest pixel from an image
minimum :: (ManifestArray arr cs e, Ord (Pixel cs e)) => Image arr cs e -> Pixel cs e
minimum !img = fold min (index img (0, 0)) img
{-# INLINE minimum #-}


-- | Scales all of the pixels to be in the range @[0, 1]@.
normalize :: (ManifestArray arr cs e, ManifestArray arr Gray e, Fractional e, Ord e) =>
             Image arr cs e -> Image arr cs e
normalize !img = if l == s
                 then (if s < 0 then (*0) else if s > 1 then (*1) else id) img
                 else map normalizer img
  where
    !(PixelGray l, PixelGray s) = (maximum $ map (PixelGray . F.maximum) img,
                                   minimum $ map (PixelGray . F.minimum) img)
    normalizer !px = (px - pure s) / pure (l - s)
    {-# INLINE normalizer #-}
{-# INLINE normalize #-}


-- | Generates a nested list of pixels from an image.
--
-- @ img == fromLists (toLists img) @
--
toLists :: ManifestArray arr cs e => Image arr cs e -> [[Pixel cs e]]
toLists img = [[index img (i, j) | j <- [0..cols img - 1]] | i <- [0..rows img - 1]]

-- $colorspace
-- Here is a list of default Pixels with their respective constructors:
--
-- @
--     * __'Pixel' 'Y' e      = PixelY y__              - Luma, also commonly denoted as __Y'__.
--     * __'Pixel' 'YA' e     = PixelYA y a__           - Luma with alpha.
--     * __'Pixel' 'RGB' e    = PixelRGB r g b__        - Red, Green and Blue.
--     * __'Pixel' 'RGBA' e   = PixelRGBA r g b a__     - RGB with alpha
--     * __'Pixel' 'HSI' e    = PixelHSI h s i__        - Hue, Saturation and Intensity.
--     * __'Pixel' 'HSIA' e   = PixelHSIA h s i a__     - HSI with alpha
--     * __'Pixel' 'CMYK' e   = PixelCMYK c m y k__     - Cyan, Magenta, Yellow and Key (Black).
--     * __'Pixel' 'CMYKA' e  = PixelCMYKA c m y k a__  - CMYK with alpha.
--     * __'Pixel' 'YCbCr' e  = PixelYCbCr y cb cr__    - Luma, blue-difference and red-difference chromas.
--     * __'Pixel' 'YCbCrA' e = PixelYCbCrA y cb cr a__ - YCbCr with alpha.
--       ------------------------------------------------------------------------------------------
--     * __'Pixel' 'Binary' 'Bit'     = 'on' | 'off'__ - Bi-tonal.
--     * __'Pixel' cs ('Complex' e) = ('Pixel' cs e) '+:' ('Pixel' cs e)__ - Complex pixels with any color space.
--     * __'Pixel' 'Gray' e         = PixelGray g__ - Used for separating channels from other color spaces.
-- @
--
-- Every 'Pixel' is an instance of 'Functor', 'Applicative', 'F.Foldable' and
-- 'Num', as well as 'Floating' and 'Fractional' if __e__ is also an instance.
--
-- All of the functionality related to every 'ColorSpace' is re-exported by
-- "Graphics.Image.Types" module.

