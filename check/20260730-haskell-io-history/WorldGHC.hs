{-# LANGUAGE UnboxedTuples #-}

import GHC.Base

main = IO $ \world ->
    let (# world1, _  #) = unIO (print "hello") world
        (# world2, _  #) = unIO (print "world") world1
    in  (# world2, () #)
