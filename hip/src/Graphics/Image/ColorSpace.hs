{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE BangPatterns, FlexibleInstances, MultiParamTypeClasses, MultiWayIf #-}
module Graphics.Image.ColorSpace (
  module Graphics.Image.ColorSpace.Binary,
  module Graphics.Image.ColorSpace.Gray,
  module Graphics.Image.ColorSpace.Luma,
  module Graphics.Image.ColorSpace.RGB,
  module Graphics.Image.ColorSpace.HSI,
  module Graphics.Image.ColorSpace.YCbCr,
  module Graphics.Image.ColorSpace.CMYK,
  Elevator(..)
  ) where

import Data.Word
import GHC.Float
import Graphics.Image.Interface
import Graphics.Image.ColorSpace.Binary
import Graphics.Image.ColorSpace.Gray
import Graphics.Image.ColorSpace.Luma
import Graphics.Image.ColorSpace.RGB
import Graphics.Image.ColorSpace.HSI
import Graphics.Image.ColorSpace.CMYK
import Graphics.Image.ColorSpace.YCbCr



instance ToY RGB where
  toPixelY (PixelRGB r g b) = PixelY (0.299*r + 0.587*g + 0.114*b)
  {-# INLINE toPixelY #-}

instance ToYA RGBA where

instance ToY HSI where
  toPixelY = toPixelY . toPixelRGB
  {-# INLINE toPixelY #-}

instance ToYA HSIA where

instance ToY YCbCr where
  toPixelY (PixelYCbCr y _ _) = PixelY y
  {-# INLINE toPixelY #-}
  
instance ToYA YCbCrA where
  
instance ToRGB Y where
  toPixelRGB (PixelY g) = fromChannel g
  {-# INLINE toPixelRGB #-}

instance ToRGBA YA where

instance ToRGB HSI where
  toPixelRGB (PixelHSI h s i) = 
    let !is = i*s
        !second = i - is
        getFirst !a !b = i + is*cos a/cos b
        {-# INLINE getFirst #-}
        getThird !v1 !v2 = i + 2*is + v1 - v2
        {-# INLINE getThird #-}
    in if | h < 2*pi/3 -> let !r = getFirst h (pi/3 - h)
                              !b = second
                              !g = getThird b r
                          in PixelRGB r g b
          | h < 4*pi/3 -> let !g = getFirst (h - 2*pi/3) (h + pi)
                              !r = second
                              !b = getThird r g
                          in PixelRGB r g b
          | h < 2*pi   -> let !b = getFirst (h - 4*pi/3) (2*pi - pi/3 - h)
                              !g = second
                              !r = getThird g b
                          in PixelRGB r g b
          | otherwise  -> error ("HSI pixel is not properly scaled, Hue: "++show h)
  {-# INLINE toPixelRGB #-}

instance ToRGBA HSIA where


instance ToRGB YCbCr where

  toPixelRGB (PixelYCbCr y cb cr) = PixelRGB r g b where
    !r = y                      +   1.402*(cr - 0.5)
    !g = y - 0.34414*(cb - 0.5) - 0.71414*(cr - 0.5)
    !b = y +   1.772*(cb - 0.5)
  {-# INLINE toPixelRGB #-}

instance ToRGBA YCbCrA where

instance ToRGB CMYK where

  toPixelRGB (PixelCMYK c m y k) = PixelRGB r g b where
    !r = (1-c)*(1-k)
    !g = (1-m)*(1-k)
    !b = (1-y)*(1-k)
  {-# INLINE toPixelRGB #-}
  
instance ToRGBA CMYKA where

  
instance ToHSI Y where
  toPixelHSI (PixelY g) = PixelHSI 0 0 g
  {-# INLINE toPixelHSI #-}

instance ToHSIA YA where
  
instance ToHSI RGB where
  toPixelHSI (PixelRGB r g b) = PixelHSI h s i where
    !h' = atan2 y x
    !h = if h' < 0 then h' + 2*pi else h'
    !s = if i == 0 then 0 else 1 - minimum [r, g, b] / i
    !i = (r + g + b) / 3
    !x = (2*r - g - b) / 2.449489742783178
    !y = (g - b) / 1.4142135623730951
  {-# INLINE toPixelHSI #-}
    
instance ToHSIA RGBA where


instance ToYCbCr RGB where

  toPixelYCbCr (PixelRGB r g b) = PixelYCbCr y cb cr where
    !y  =          0.299*r +    0.587*g +    0.114*b
    !cb = 0.5 - 0.168736*r - 0.331264*g +      0.5*b
    !cr = 0.5 +      0.5*r - 0.418688*g - 0.081312*b
  {-# INLINE toPixelYCbCr #-}

instance ToYCbCrA RGBA where
  

instance ToCMYK RGB where

  toPixelCMYK (PixelRGB r g b) = PixelCMYK c m y k where
    !c = (1 - r - k)/(1 - k)
    !m = (1 - g - k)/(1 - k)
    !y = (1 - b - k)/(1 - k)
    !k = 1 - max r (max g b)

instance ToCMYKA RGBA where

  
-- | A convenient class with set of functions that allow for changing precision of
-- channels within pixels, while scaling the values to keep them in an appropriate range.
--
-- >>> let rgb = PixelRGB 0.0 0.5 1.0 :: Pixel RGB Double
-- >>> toWord8 rgb
-- <RGB:(0|128|255)>
--
class Elevator e where

  toWord8 :: ColorSpace cs => Pixel cs e -> Pixel cs Word8

  toWord16 :: ColorSpace cs => Pixel cs e -> Pixel cs Word16

  toWord32 :: ColorSpace cs => Pixel cs e -> Pixel cs Word32

  toWord64 :: ColorSpace cs => Pixel cs e -> Pixel cs Word64

  toFloat :: ColorSpace cs => Pixel cs e -> Pixel cs Float

  toDouble :: ColorSpace cs => Pixel cs e -> Pixel cs Double


-- | Values are scaled to @[0, 255]@ range.
instance Elevator Word8 where

  toWord8 = id
  {-# INLINE toWord8 #-}

  toWord16 = pxOp toWord16' where
    toWord16' !e = fromIntegral e * ((maxBound :: Word16) `div` fromIntegral (maxBound :: Word8)) 
    {-# INLINE toWord16' #-}
  {-# INLINE toWord16 #-}

  toWord32 = pxOp toWord32' where
    toWord32' !e = fromIntegral e * ((maxBound :: Word32) `div` fromIntegral (maxBound :: Word8)) 
    {-# INLINE toWord32' #-}
  {-# INLINE toWord32 #-}

  toWord64 = pxOp toWord64' where
    toWord64' !e = fromIntegral e * ((maxBound :: Word64) `div` fromIntegral (maxBound :: Word8))
    {-# INLINE toWord64' #-}
  {-# INLINE toWord64 #-}

  toFloat = pxOp toFloat' where
    toFloat' !e = fromIntegral e / (fromIntegral (maxBound :: Word8))
    {-# INLINE toFloat' #-}
  {-# INLINE toFloat #-}

  toDouble = pxOp toDouble' where
    toDouble' !e = fromIntegral e / (fromIntegral (maxBound :: Word8))
    {-# INLINE toDouble' #-}
  {-# INLINE toDouble #-}


-- | Values are scaled to @[0, 65535]@ range.
instance Elevator Word16 where

  toWord8 = pxOp toWord8' where
    toWord8' !e = fromIntegral $ fromIntegral e `div` ((maxBound :: Word16) `div`
                                                      fromIntegral (maxBound :: Word8)) 
    {-# INLINE toWord8' #-}
  {-# INLINE toWord8 #-}

  toWord16 = id
  {-# INLINE toWord16 #-}
  
  toWord32 = pxOp toWord32' where
    toWord32' !e = fromIntegral e * ((maxBound :: Word32) `div` fromIntegral (maxBound :: Word16)) 
    {-# INLINE toWord32' #-}
  {-# INLINE toWord32 #-}

  toWord64 = pxOp toWord64' where
    toWord64' !e = fromIntegral e * ((maxBound :: Word64) `div` fromIntegral (maxBound :: Word16))
    {-# INLINE toWord64' #-}
  {-# INLINE toWord64 #-}

  toFloat = pxOp toFloat' where
    toFloat' !e = fromIntegral e / (fromIntegral (maxBound :: Word16))
    {-# INLINE toFloat' #-}
  {-# INLINE toFloat #-}

  toDouble = pxOp toDouble' where
    toDouble' !e = fromIntegral e / (fromIntegral (maxBound :: Word16))
    {-# INLINE toDouble' #-}
  {-# INLINE toDouble #-}


-- | Values are scaled to @[0, 4294967295]@ range.
instance Elevator Word32 where

  toWord8 = pxOp toWord8' where
    toWord8' !e = fromIntegral $ fromIntegral e `div` ((maxBound :: Word32) `div`
                                                       fromIntegral (maxBound :: Word8)) 
    {-# INLINE toWord8' #-}
  {-# INLINE toWord8 #-}

  toWord16 = pxOp toWord16' where
    toWord16' !e = fromIntegral $ fromIntegral e `div` ((maxBound :: Word32) `div`
                                                        fromIntegral (maxBound :: Word16)) 
    {-# INLINE toWord16' #-}
  {-# INLINE toWord16 #-}

  toWord32 = id
  {-# INLINE toWord32 #-}

  toWord64 = pxOp toWord64' where
    toWord64' !e = fromIntegral e * ((maxBound :: Word64) `div` fromIntegral (maxBound :: Word32))
    {-# INLINE toWord64' #-}
  {-# INLINE toWord64 #-}

  toFloat = pxOp toFloat' where
    toFloat' !e = fromIntegral e / (fromIntegral (maxBound :: Word32))
    {-# INLINE toFloat' #-}
  {-# INLINE toFloat #-}

  toDouble = pxOp toDouble' where
    toDouble' !e = fromIntegral e / (fromIntegral (maxBound :: Word32))
    {-# INLINE toDouble' #-}
  {-# INLINE toDouble #-}


-- | Values are scaled to @[0, 18446744073709551615]@ range.
instance Elevator Word64 where

  toWord8 = pxOp toWord8' where
    toWord8' !e = fromIntegral $ fromIntegral e `div` ((maxBound :: Word64) `div`
                                                       fromIntegral (maxBound :: Word8)) 
    {-# INLINE toWord8' #-}
  {-# INLINE toWord8 #-}

  toWord16 = pxOp toWord16' where
    toWord16' !e = fromIntegral $ fromIntegral e `div` ((maxBound :: Word64) `div`
                                                        fromIntegral (maxBound :: Word16)) 
    {-# INLINE toWord16' #-}
  {-# INLINE toWord16 #-}

  toWord32 = pxOp toWord32' where
    toWord32' !e = fromIntegral $ fromIntegral e `div` ((maxBound :: Word64) `div`
                                                        fromIntegral (maxBound :: Word32)) 
    {-# INLINE toWord32' #-}
  {-# INLINE toWord32 #-}

  toWord64 = id
  {-# INLINE toWord64 #-}

  toFloat = pxOp toFloat' where
    toFloat' !e = fromIntegral e / (fromIntegral (maxBound :: Word64))
    {-# INLINE toFloat' #-}
  {-# INLINE toFloat #-}

  toDouble = pxOp toDouble' where
    toDouble' !e = fromIntegral e / (fromIntegral (maxBound :: Word64))
    {-# INLINE toDouble' #-}
  {-# INLINE toDouble #-}


-- | Values are scaled to @[0.0, 1.0]@ range.
instance Elevator Float where

  toWord8 = pxOp toWord8' where
    toWord8' !e = round (fromIntegral (maxBound :: Word8) * e)
    {-# INLINE toWord8' #-}
  {-# INLINE toWord8 #-}

  toWord16 = pxOp toWord16' where
    toWord16' !e = round (fromIntegral (maxBound :: Word16) * e)
    {-# INLINE toWord16' #-}
  {-# INLINE toWord16 #-}

  toWord32 = pxOp toWord32' where
    toWord32' !e = round (fromIntegral (maxBound :: Word32) * e)
    {-# INLINE toWord32' #-}
  {-# INLINE toWord32 #-}

  toWord64 = pxOp toWord64' where
    toWord64' !e = round (fromIntegral (maxBound :: Word64) * e)
    {-# INLINE toWord64' #-}
  {-# INLINE toWord64 #-}

  toFloat = id
  {-# INLINE toFloat #-}

  toDouble = pxOp float2Double
  {-# INLINE toDouble #-}


-- | Values are scaled to @[0.0, 1.0]@ range.
instance Elevator Double where

  toWord8 = pxOp toWord8' where
    toWord8' !e = round (fromIntegral (maxBound :: Word8) * e)
    {-# INLINE toWord8' #-}
  {-# INLINE toWord8 #-}

  toWord16 = pxOp toWord16' where
    toWord16' !e = round (fromIntegral (maxBound :: Word16) * e)
    {-# INLINE toWord16' #-}
  {-# INLINE toWord16 #-}

  toWord32 = pxOp toWord32' where
    toWord32' !e = round (fromIntegral (maxBound :: Word32) * e)
    {-# INLINE toWord32' #-}
  {-# INLINE toWord32 #-}

  toWord64 = pxOp toWord64' where
    toWord64' !e = round (fromIntegral (maxBound :: Word64) * e)
    {-# INLINE toWord64' #-}
  {-# INLINE toWord64 #-}

  toFloat = pxOp double2Float
  {-# INLINE toFloat #-}

  toDouble = id
  {-# INLINE toDouble #-}
