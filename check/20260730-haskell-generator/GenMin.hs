-- コルーチン（ジェネレーター）: 継続モナドも含めて全部自前の最小実装。
-- GenStd.hs（標準の transformers を使う版）と同じ出力になる。
import Control.Monad (ap, liftM)

-- ここから継続モナドの最小実装（標準の Control.Monad.Trans.Cont に相当）
newtype Cont r a = Cont { runCont :: (a -> r) -> r }

-- Monad のスーパークラスなので必要。中身は Monad から導出できる。
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
-- ここまで

-- 以下は GenStd.hs と同一
-- JS の {value, next} に相当する型。
-- Cont の答えの型 r を Gen a 自身にすることで「継続を返す」を型付けする。
-- type シノニムだと循環でエラーになるが、data なら循環を通せる。
data Gen a
    = Done
    | Yield a (Cont (Gen a) (Gen a))  -- 値と、再開用の継続

type GenM a = Cont (Gen a)

-- ジェネレーターから抜ける継続
type Out a = Gen a -> GenM a ()

yield :: Out a -> a -> GenM a ()
yield ccOut v = callCC $ \next -> ccOut (Yield v (next ()))

-- ジェネレーター本体を Gen に変換する
runGen :: (Out a -> GenM a x) -> Gen a
runGen body = evalCont $ callCC $ \ccOut -> body ccOut >> return Done

-- Gen をリストに変換（JS の while ループに相当）
toList :: Gen a -> [a]
toList Done = []
toList (Yield v k) = v : toList (evalCont k)

-- 有限のジェネレーター
g123 :: Gen Int
g123 = runGen $ \ccOut -> do
    let y = yield ccOut
    y 1
    y 2
    y 3

-- 無限のジェネレーター（遅延して動くことの確認）
nats :: Gen Int
nats = runGen $ \ccOut ->
    let loop n = yield ccOut n >> loop (n + 1)
    in loop 0

-- 既存のモナドコンビネーターがそのまま使える例
squares :: Gen Int
squares = runGen $ \ccOut -> mapM_ (\n -> yield ccOut (n * n)) [1 .. 5]

main :: IO ()
main = do
    print (toList g123)
    print (take 5 (toList nats))
    print (toList squares)
    print (toList (runGen (\_ -> return ()) :: Gen Int))  -- yield しない場合
