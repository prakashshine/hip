{-# LANGUAGE TypeFamilies, TemplateHaskell, MultiParamTypeClasses, BangPatterns,
NoMonomorphismRestriction, ViewPatterns, FlexibleInstances, FlexibleContexts #-}

module Graphics.Image.Pixel.Complex (
  Complex (..),
  mag, arg, conj, real, imag, fromPolar,
  realImage, imagImage, conjImage, toComplex, complexImage
  ) where

import Prelude hiding (map, zipWith)
import Graphics.Image.Interface
import Data.Array.Repa.Eval (Elt(..))
import Data.Vector.Unboxed.Deriving (derivingUnbox)
import Data.Vector.Unboxed (Unbox)

data Complex px = !px :+: !px deriving Eq

mag :: (Floating px, Pixel px) => Complex px -> px
mag (pxReal :+: pxImag) = sqrt (pxReal ^ (2 :: Int) + pxImag ^ (2 :: Int))
{-# INLINE mag #-}


arg :: Pixel px => Complex px -> px
arg (pxX :+: pxY) = pxOp2 f pxX pxY where
  f x y | x /= 0          = atan (y/x) + (pi/2)*(1-signum x)
        | x == 0 && y /=0 = (pi/2)*signum y
        | otherwise = 0
{-# INLINE arg #-}


-- | Create a complex pixel from two real pixels, which represent a magnitude
-- and an argument, ie. radius and phase
fromPolar :: (Floating px, Pixel px) => px -> px -> Complex px
fromPolar r theta = (r * cos theta) :+: (r * sin theta)
{-# INLINE fromPolar #-}

-- | Conjugate a complex pixel
conj :: (Pixel px, Num px) => Complex px -> Complex px
conj (x :+: y) = x :+: (-y)
{-# INLINE conj #-}

-- | Extracts a real part from a complex pixel -}
real :: (Pixel px) => Complex px -> px
real (px :+: _ ) = px

{-| Extracts an imaginary part of a pixel -}
imag :: (Pixel px) => Complex px -> px
imag (_  :+: px) = px


instance (Floating px, Fractional px, Num px, Pixel px) => Pixel (Complex px) where

  pixel v = (pixel v) :+: (pixel v)
  
  pxOp op (px1 :+: px2) = (pxOp op px1 :+: pxOp op px2)

  pxOp2 op (px1 :+: px2) (px1' :+: px2') = (pxOp2 op px1 px1') :+: (pxOp2 op px2 px2')

  strongest (px1 :+: px2) = m :+: m
    where m = pxOp2 max (strongest px1) (strongest px2)

  weakest (px1 :+: px2) = m :+: m
    where m = pxOp2 min (strongest px1) (strongest px2)

  showType (px :+: _) = "Complex "++(showType px)

realImage :: (Pixel px, Image img px, Image img (Complex px)) =>
             img (Complex px)
          -> img px
realImage = map real
{-# INLINE realImage #-}


imagImage :: (Pixel px, Image img px, Image img (Complex px)) =>
             img (Complex px)
          -> img px
imagImage = map imag
{-# INLINE imagImage #-}


complexImage :: (Pixel px, Image img px, Image img (Complex px)) =>
                img px -> img px -> img (Complex px)
complexImage = zipWith (:+:)
{-# INLINE complexImage #-}


toComplex :: (Pixel px, Convertable px (Complex px), Image img px, Image img (Complex px)) =>
             img px
          -> img (Complex px)
toComplex = map convert
{-# INLINE toComplex #-}


conjImage :: (Image img (Complex px), Pixel px, Num px) =>
             img (Complex px)
          -> img (Complex px)
conjImage = map conj
{-# INLINE conjImage #-}



instance (Fractional px, Floating px, Num px, Eq px, Pixel px) => Num (Complex px) where
  (+) = pxOp2 (+)
  (-) = pxOp2 (-)
  (x :+: y) * (x' :+: y') = (x*x' - y*y') :+: (x*y' + y*x')

  negate = pxOp negate
  abs z = (mag z) :+: (fromInteger 0)
  signum z@(x :+: _)
    | mag' == 0 = (fromInteger 0) :+: (fromInteger 0)
    | otherwise = (x / mag') :+: (x / mag')
    where mag' = mag z
  fromInteger n = nd :+: nd where nd = fromInteger n


instance (Fractional px, Floating px, Eq px, Pixel px) => Fractional (Complex px) where
  (x :+: y) / (x' :+: y') = ((x*x' + y*y') / mag2) :+: ((y*x' - x*y') / mag2)
    where mag2 = x'*x' + y'*y'
  recip          = pxOp recip
  fromRational n = nd :+: nd where nd = fromRational n


instance (Floating px, Eq px, Pixel px) => Floating (Complex px) where
    pi             =  pi :+: 0
    exp (x:+:y)    =  (expx * cos y) :+: (expx * sin y)
                      where expx = exp x
    log z          =  (log (mag z)) :+: (arg z)
    --sqrt (0:+:0)    =  0
    {-
    sqrt z@(x:+:y)  =  u :+: (if y < 0 then -v else v)
                      where (u,v) = if x < 0 then (v',u') else (u',v')
                            v'    = abs y / (u'*2)
                            u'    = sqrt ((magnitude z + abs x) / 2)
    -}
    sin (x:+:y)     =  (sin x * cosh y) :+: (cos x * sinh y)
    cos (x:+:y)     =  (cos x * cosh y) :+: (- sin x * sinh y)
    tan (x:+:y)     =  ((sinx*coshy):+:(cosx*sinhy))/((cosx*coshy):+:(-sinx*sinhy))
      where sinx  = sin x
            cosx  = cos x
            sinhy = sinh y
            coshy = cosh y

    sinh (x:+:y)    =  (cos y * sinh x) :+: (sin  y * cosh x)
    cosh (x:+:y)    =  (cos y * cosh x) :+: (sin y * sinh x)
    tanh (x:+:y)    =  ((cosy*sinhx):+:(siny*coshx))/((cosy*coshx):+:(siny*sinhx))
                      where siny  = sin y
                            cosy  = cos y
                            sinhx = sinh x
                            coshx = cosh x

    asin z@(x:+:y)  =  y':+:(-x')
                      where  (x':+:y') = log (((-y):+:x) + sqrt (1 - z*z))
    acos z         =  y'':+:(-x'')
                      where (x'':+:y'') = log (z + ((-y'):+:x'))
                            (x':+:y')   = sqrt (1 - z*z)
    atan z@(x:+:y)  =  y':+:(-x')
                      where (x':+:y') = log (((1-y):+:x) / sqrt (1+z*z))

    asinh z        =  log (z + sqrt (1+z*z))
    acosh z        =  log (z + (z+1) * sqrt ((z-1)/(z+1)))
    atanh z        =  0.5 * log ((1.0+z) / (1.0-z))

    
instance Show px => Show (Complex px) where
  show (px1 :+: px2) = "(" ++show px1 ++" + i" ++show px2 ++")"


instance (Fractional px, Floating px, Elt px, Pixel px) => Elt (Complex px) where
  touch (x :+: y) = touch x >> touch y
  {-# INLINE touch #-}
  
  zero = pixel 0
  {-# INLINE zero #-}
  
  one = pixel 1
  {-# INLINE one #-}
  

derivingUnbox "ComplexPixel"
    [t| (Unbox px, Pixel px) => (Complex px) -> (px, px) |]
    [| \(px1 :+: px2) -> (px1, px2) |]
    [| \(px1, px2) -> px1 :+: px2 |]
