-- Haskell 1.0 Report の Figure 4「Continuation I/O」を動かし、
-- それが継続モナドそのものであることを確認する。
--
-- Haskell 1.0 では継続版はストリーム版の「上に」定義されていた
-- （ストリームが primitive、継続が派生）。以下もその順序で書く。
import Control.Monad (ap, liftM)
import Haskell10

-- Report の型定義そのまま。答えの型が Behaviour になっている点に注目。
type FailCont = String -> Behaviour -- 元は IOError -> Behaviour
type StrCont = String -> Behaviour
type SuccCont = Behaviour

-- Report の readFile の定義そのまま。要求を出し、応答で継続を選ぶ。
-- 引数に ~ が付いているのがストリーム版と同じ事情。
readFileT :: Name -> FailCont -> StrCont -> Behaviour
readFileT name fail_ succ_ ~(resp : resps) =
    ReadFile name
        : case resp of
            Str val -> succ_ val resps
            Failure msg -> fail_ msg resps
            Success -> fail_ "unexpected" resps

readChanT :: Name -> FailCont -> StrCont -> Behaviour
readChanT name fail_ succ_ ~(resp : resps) =
    ReadChan name
        : case resp of
            Str val -> succ_ val resps
            Failure msg -> fail_ msg resps
            Success -> fail_ "unexpected" resps

appendChanT :: Name -> String -> FailCont -> SuccCont -> Behaviour
appendChanT name s fail_ succ_ ~(resp : resps) =
    AppendChan name s
        : case resp of
            Success -> succ_ resps
            Failure msg -> fail_ msg resps
            Str _ -> fail_ "unexpected" resps

done :: Behaviour
done _ = []

abort :: FailCont
abort _ _ = []

letE :: a -> (a -> b) -> b
letE x k = k x

-- Figure 4 そのまま。括弧が積み上がるのが当時の問題点。
figure4 :: Behaviour
figure4 =
    appendChanT stdout "enter filename\n" abort
        ( readChanT stdin abort
            ( \userInput ->
                letE
                    (lines userInput)
                    ( \(name : _) ->
                        appendChanT stdout name abort
                            ( readFileT name fail_
                                (\contents -> appendChanT stdout contents abort done)
                            )
                    )
            )
        )
  where
    fail_ _ = appendChanT stdout "can't open file\n" abort done

-- Report 末期に lambda の優先順位を変えて導入された >>> 版
-- （History of Haskell 7.3「Syntax matters」）。f >>> x = f abort x
infixr 1 >>>
(>>>) :: (FailCont -> b -> Behaviour) -> b -> Behaviour
f >>> x = f abort x

figure4op :: Behaviour
figure4op =
    appendChanT stdout "enter filename\n"
        >>> readChanT stdin
        >>> \userInput ->
            let (name : _) = lines userInput
             in appendChanT stdout name
                    >>> readFileT name fail_
                        (\contents -> appendChanT stdout contents abort done)
  where
    fail_ _ = appendChanT stdout "can't open file\n" abort done

-- ここからが本題。
-- readFileT name abort :: StrCont -> Behaviour
--                      =  (String -> Behaviour) -> Behaviour
-- これは Cont Behaviour String の中身そのもの。
newtype Cont r a = Cont {runCont :: (a -> r) -> r}

instance Functor (Cont r) where
    fmap = liftM

instance Applicative (Cont r) where
    pure x = Cont ($ x)
    (<*>) = ap

instance Monad (Cont r) where
    m >>= k = Cont $ \c -> runCont m (\x -> runCont (k x) c)

-- 失敗継続を abort に固定して Cont で包むだけ
readFileC :: Name -> Cont Behaviour String
readFileC name = Cont (readFileT name abort)

readChanC :: Name -> Cont Behaviour String
readChanC name = Cont (readChanT name abort)

appendChanC :: Name -> String -> Cont Behaviour ()
appendChanC name s = Cont $ \k -> appendChanT name s abort (k ())

evalIO :: Cont Behaviour () -> Behaviour
evalIO m = runCont m (\_ -> done)

-- Figure 4 と同じ内容を do 記法で書く。Figure 6（モナド版）と同形になる。
figureDo :: Behaviour
figureDo = evalIO $ do
    appendChanC stdout "enter filename\n"
    userInput <- readChanC stdin
    let (name : _) = lines userInput
    appendChanC stdout name
    contents <- readFileC name
    appendChanC stdout contents

fs :: [(Name, String)]
fs = [("hello.txt", "Hello, continuation I/O!\n")]

main :: IO ()
main = do
    putStrLn "=== Figure 4: 継続 I/O（入れ子のラムダ） ==="
    run fs "hello.txt\n" figure4
    putStrLn "=== Figure 4: >>> 版 ==="
    run fs "hello.txt\n" figure4op
    putStrLn "=== Cont で包んで do 記法 ==="
    run fs "hello.txt\n" figureDo
    putStrLn "=== Cont 版・存在しないファイル（失敗継続は abort なので途中で終わる） ==="
    run fs "missing.txt\n" figureDo
