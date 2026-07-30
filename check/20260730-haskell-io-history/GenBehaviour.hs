-- 双方向ジェネレーター（構成案 6 (a)）が Haskell 1.0 の Behaviour そのもの
-- であることの確認。feed の型を見ると
--
--   feed :: Gen i o -> [i] -> [o]
--   feed prog :: [Response] -> [Request]   -- i = Response, o = Request
--            =  Behaviour
--
-- つまり Figure 3 のプログラムをコルーチンとして書き直すと、
-- Haskell 1.0 の OS にそのまま差せる。
import Control.Exception (SomeException, try)
import Control.Monad (ap, liftM)
import Haskell10
import System.Timeout (timeout)

newtype Cont r a = Cont {runCont :: (a -> r) -> r}

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

-- series/haskell-intro/check/gen-bidirectional/GenBi.hs と同じ双方向ジェネレーター
data Gen i o
    = Done
    | Yield o (i -> Cont (Gen i o) (Gen i o))

type GenM i o = Cont (Gen i o)
type Out i o = Gen i o -> GenM i o i

yield :: Out i o -> o -> GenM i o i
yield ccOut v = callCC $ \next -> ccOut (Yield v next)

runGen :: (Out i o -> GenM i o x) -> Gen i o
runGen body = evalCont $ callCC $ \ccOut -> body ccOut >> return Done

-- gen-bidirectional/GenBi.hs の feed。入力リストを先にパターンマッチする。
feedStrict :: Gen i o -> [i] -> [o]
feedStrict (Yield v next) (i : is) = v : feedStrict (evalCont (next i)) is
feedStrict _ _ = []

-- 出力を先に出してから入力を要求する版。
-- Figure 3 の ~ に相当する配慮が、ここに移っている。
feed :: Gen i o -> [i] -> [o]
feed Done _ = []
feed (Yield v next) is =
    v : case is of
        (i : rest) -> feed (evalCont (next i)) rest
        [] -> []

-- Figure 3 と同じプログラムをコルーチンとして書く
prog :: Gen Response Request
prog = runGen $ \ccOut -> do
    _ <- yield ccOut (AppendChan stdout "enter filename\n")
    r2 <- yield ccOut (ReadChan stdin)
    let userInput = case r2 of Str s -> s; _ -> ""
        (name : _) = lines userInput
    _ <- yield ccOut (AppendChan stdout name)
    r4 <- yield ccOut (ReadFile name)
    yield ccOut $
        AppendChan stdout $ case r4 of
            Str contents -> contents
            _ -> "can't open file\n"

fs :: [(Name, String)]
fs = [("hello.txt", "Hello, coroutine!\n")]

main :: IO ()
main = do
    putStrLn "=== ジェネレーターを Behaviour として OS に差す ==="
    run fs "hello.txt\n" (feed prog)

    putStrLn "=== 存在しないファイル ==="
    run fs "missing.txt\n" (feed prog)

    putStrLn "=== 入力を先にパターンマッチする feed（~ なしの Figure 3 と同じ） ==="
    r <- timeout 1000000 $ try (run fs "hello.txt\n" (feedStrict prog))
    case r of
        Nothing -> putStrLn "  → タイムアウト"
        Just (Left e) -> putStrLn ("  → 例外: " ++ show (e :: SomeException))
        Just (Right ()) -> putStrLn "  → 完走した"

    putStrLn "=== feed に有限のリストを渡す（遅延に頼らない使い方） ==="
    print (take 2 (feed prog [Success, Str "hello.txt\n"]))
