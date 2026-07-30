-- 記事「CPS 変換から継続モナドへ」の「Haskell への移植」節に掲載するコード
-- JS 版をほぼそのまま移植したもの（data で包めば型は合う）
import Control.Monad (ap, liftM)

newtype Cont r a = Cont { runCont :: (a -> r) -> r }

instance Functor (Cont r) where
    fmap = liftM

instance Applicative (Cont r) where
    pure x = Cont ($ x)
    (<*>) = ap

instance Monad (Cont r) where
    m >>= k = Cont $ \c -> runCont m (\x -> runCont (k x) c)

evalCont :: Cont r r -> r
evalCont = (`runCont` id)

callCC :: ((a -> Cont r b) -> Cont r a) -> Cont r a
callCC f = Cont $ \c -> runCont (f (\x -> Cont $ \_ -> c x)) c

-- JS の {value, next} に相当するレコード
data It = It { value :: Maybe Int, next :: () -> Cont It It }

g :: It
g = It Nothing $ \_ -> callCC $ \ccOut ->
    let yield v = callCC $ \nxt -> ccOut (It (Just v) nxt)
    in do
        yield 1
        yield 2
        yield 3
        return (It Nothing (\_ -> error "done"))

-- JS の while (it = it.next().evalCont()) に相当
main :: IO ()
main = go g
  where
    go it =
        let it' = evalCont (next it ())
        in case value it' of
            Nothing -> return ()
            Just v  -> print v >> go it'
