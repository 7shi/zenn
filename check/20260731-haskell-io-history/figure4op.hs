-- Haskell 1.0 Report 末期に lambda の優先順位を変えて導入された >>> 版
-- （History of Haskell 7.3「Syntax matters」）。Figure 4 の入れ子のラムダを平らにする。
-- 共通のトランザクションは Transaction.hs にある。
import Haskell10
import Transaction

infixr 1 >>>
(>>>) :: (FailCont -> b -> Behaviour) -> b -> Behaviour
f >>> x = f abort x

figure4op :: Behaviour
figure4op =
    appendChanT stdout "enter filename\n"
        >>> readChanT stdin
        >>> \userInput ->
            let (name : _) = lines userInput
             in appendChanT stdout (name ++ "\n")
                    >>> readFileT name fail_
                        (\contents -> appendChanT stdout contents abort done)
  where
    fail_ _ = appendChanT stdout "can't open file\n" abort done

main :: IO ()
main = do
    putStrLn "=== Figure 4: >>> 版 ==="
    run fs "hello.txt\n" figure4op
