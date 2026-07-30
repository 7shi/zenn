-- Haskell 1.0 Report の Figure 4「Continuation I/O」（入れ子のラムダ版）を動かす。
--
-- Haskell 1.0 では継続版はストリーム版の「上に」定義されていた
-- （ストリームが primitive、継続が派生）。共通のトランザクションは Transaction.hs にある。
import Haskell10
import Transaction

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
                        appendChanT stdout (name ++ "\n") abort
                            ( readFileT name fail_
                                (\contents -> appendChanT stdout contents abort done)
                            )
                    )
            )
        )
  where
    fail_ _ = appendChanT stdout "can't open file\n" abort done

main :: IO ()
main = do
    putStrLn "=== Figure 4: 継続 I/O（入れ子のラムダ） ==="
    run fs "hello.txt\n" figure4
