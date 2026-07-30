-- コルーチン（ジェネレーター）: 継続モナドは標準の transformers を使い、
-- コルーチンの部分だけを実装したもの。GenMin.hs と同じ出力になる。
import Control.Monad.Trans.Cont (Cont, evalCont, callCC)

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
