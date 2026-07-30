-- Figure 4「Continuation I/O」が継続モナドそのものであることを確認する。
--
-- readFileT name abort :: StrCont -> Behaviour
--                      =  (String -> Behaviour) -> Behaviour
-- これは Cont Behaviour String の中身そのもの。
import Control.Monad (ap, liftM)
import Haskell10
import Transaction

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
    appendChanC stdout (name ++ "\n")
    contents <- readFileC name
    appendChanC stdout contents

main :: IO ()
main = do
    putStrLn "=== Cont で包んで do 記法 ==="
    run fs "hello.txt\n" figureDo
    putStrLn "=== Cont 版・存在しないファイル（失敗継続は abort なので途中で終わる） ==="
    run fs "missing.txt\n" figureDo
