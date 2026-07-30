-- 型注釈も data も付けず、型推論に任せるとどうなるか
-- Cont は標準の transformers のものを使う
import Control.Monad.Trans.Cont (evalCont, callCC)

-- JS の {value, next} をタプル (value, next) で表す
g = \_ -> callCC $ \ccOut ->
    let yield v = callCC $ \nxt -> ccOut (Just v, nxt)
    in do
        yield 1
        yield 2
        yield 3
        return (Nothing, \_ -> error "done")

-- ここで初めて r と タプル型が結び付く
main :: IO ()
main = case evalCont (g ()) of
    (v, _) -> print (v :: Maybe Int)
