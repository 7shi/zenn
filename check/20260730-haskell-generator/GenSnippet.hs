-- 記事「Haskell への移植」の「直和型による整理」の掲載コードを、記載どおり（型注釈なし）で検証
import Control.Monad.Trans.Cont (Cont, evalCont, callCC)

data Gen a
    = Done
    | Yield a (Cont (Gen a) (Gen a))  -- 値と、再開用の継続

yield ccOut v = callCC $ \next -> ccOut (Yield v (next ()))

runGen body = evalCont $ callCC $ \ccOut -> body ccOut >> return Done

toList Done = []
toList (Yield v k) = v : toList (evalCont k)

g123    = runGen $ \ccOut -> let y = yield ccOut in do { y 1; y 2; y 3 }
nats    = runGen $ \ccOut -> let loop n = yield ccOut n >> loop (n + 1) in loop 0
squares = runGen $ \ccOut -> mapM_ (\n -> yield ccOut (n * n)) [1 .. 5]

main :: IO ()
main = do
    print (toList g123 :: [Int])
    print (take 5 (toList nats) :: [Int])
    print (toList squares :: [Int])
