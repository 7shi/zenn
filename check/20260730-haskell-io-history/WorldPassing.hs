-- 検討されたが採用されなかった第 3 の案「世界渡し」の雰囲気。
-- 却下理由は「世界への単一スレッドなアクセスを保証する手段がなかった」こと。
-- ここではその「保証できない」を実際に破ってみせる。
--
-- 現在の GHC の IO は結局この形（State# RealWorld を渡す）で実装されている。
-- 詳細は articles/haskell/io-monad-internals.md を参照。
import Data.List (intercalate)

-- 世界。ここでは「これまでに出力された行」だけを持つ。
newtype World = World [String]
    deriving Show

type IOw a = World -> (a, World)

putStrLnW :: String -> IOw ()
putStrLnW s (World o) = ((), World (o ++ [s]))

getLineW :: String -> IOw String
getLineW canned w = (canned, w)

returnW :: a -> IOw a
returnW x w = (x, w)

bindW :: IOw a -> (a -> IOw b) -> IOw b
bindW m k w = case m w of (x, w') -> k x w'

runW :: IOw a -> (a, World)
runW m = m (World [])

-- 素直に使えば命令型のように書ける（bindW が >>= に相当）
greet :: IOw ()
greet =
    putStrLnW "enter filename"
        `bindW` \_ ->
            getLineW "hello.txt"
                `bindW` \name ->
                    putStrLnW ("you typed " ++ name)

-- ここが問題。w を 2 回使える。型は何も文句を言わない。
-- 「世界」が複製されてしまい、副作用の順序が意味を失う。
forked :: World -> (World, World)
forked w =
    let (_, w1) = putStrLnW "branch A" w
        (_, w2) = putStrLnW "branch B" w -- ← 同じ w を再利用
    in (w1, w2)

-- 古い世界を使い回して、出力を「巻き戻す」こともできてしまう
rewound :: World
rewound =
    let (_, w1) = putStrLnW "first" (World [])
        (_, w2) = putStrLnW "second" w1
        (_, w3) = putStrLnW "third" w1 -- ← w2 を捨てて w1 から再開
    in seq w2 w3

render :: World -> String
render (World o) = intercalate " / " o

main :: IO ()
main = do
    putStrLn "=== 素直に使えば命令型のように書ける ==="
    putStrLn ("  " ++ render (snd (runW greet)))

    putStrLn "=== 同じ世界を 2 回使える（単一スレッド性が破れる） ==="
    let (a, b) = forked (World ["common"])
    putStrLn ("  branch1: " ++ render a)
    putStrLn ("  branch2: " ++ render b)

    putStrLn "=== 出力を巻き戻せる（second が消える） ==="
    putStrLn ("  " ++ render rewound)
