-- Haskell 1.0 Report の Figure 3「Stream-based I/O」を動かす。
-- 遅延パターン ~ が必須であることの確認も行う。
import Control.Exception (SomeException, evaluate, try)
import Haskell10
import System.Timeout (timeout)

-- Figure 3 そのまま（History of Haskell 論文の引用に一致）。
-- 応答を「見る」前に要求を出せるよう、~ で遅延パターンにしている。
figure3 :: Behaviour
figure3 ~(Success : ~(Str userInput : ~(Success : ~(r4 : _)))) =
    [ AppendChan stdout "enter filename\n"
    , ReadChan stdin
    , AppendChan stdout (name ++ "\n")
    , ReadFile name
    , AppendChan stdout
        (case r4 of
            Str contents -> contents
            Failure _ -> "can't open file\n")
    ]
  where
    (name : _) = lines userInput

-- ~ を外すと、要求を出す前に応答を見ようとして自分を待つ。
figure3Strict :: Behaviour
figure3Strict (Success : Str userInput : Success : r4 : _) =
    [ AppendChan stdout "enter filename\n"
    , ReadChan stdin
    , AppendChan stdout (name ++ "\n")
    , ReadFile name
    , AppendChan stdout
        (case r4 of
            Str contents -> contents
            Failure _ -> "can't open file\n")
    ]
  where
    (name : _) = lines userInput
figure3Strict _ = []

fs :: [(Name, String)]
fs = [("hello.txt", "Hello, stream I/O!\n")]

main :: IO ()
main = do
    putStrLn "=== Figure 3: 遅延パターンあり ==="
    run fs "hello.txt\n" figure3

    putStrLn "=== Figure 3: 存在しないファイル ==="
    run fs "missing.txt\n" figure3

    putStrLn "=== Figure 3: 遅延パターンなし（~ を外す） ==="
    r <- timeout 1000000 $ try (run fs "hello.txt\n" figure3Strict)
    case r of
        Nothing -> putStrLn "  → タイムアウト（自分の出力を待って止まった）"
        Just (Left e) -> putStrLn ("  → 例外: " ++ show (e :: SomeException))
        Just (Right ()) -> putStrLn "  → 完走した"

    -- 上の run は出力を捨てる経路もあるので、リスト自体の評価でも確認する
    putStrLn "=== 要求リストの先頭だけ評価してみる（~ なし） ==="
    let reqs = figure3Strict resps
        resps = os fs "hello.txt\n" reqs
    r2 <- timeout 1000000 $ try (evaluate (length (take 1 reqs)))
    case r2 of
        Nothing -> putStrLn "  → タイムアウト"
        Just (Left e) -> putStrLn ("  → 例外: " ++ show (e :: SomeException))
        Just (Right n) -> putStrLn ("  → 評価できた: " ++ show n)
