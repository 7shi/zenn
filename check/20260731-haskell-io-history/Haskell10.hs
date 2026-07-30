-- Haskell 1.0 (1990) のストリーム I/O モデルの最小再現。
-- Request/Response の定義は History of Haskell 論文 7.1 節の引用に合わせた。
module Haskell10 where

type Name = String

data Request
    = ReadFile Name
    | ReadChan Name
    | AppendChan Name String
    deriving Show

data Response
    = Success
    | Str String
    | Failure String
    deriving Show

-- プログラムそのものの型。応答の列を受け取って要求の列を返す関数。
type Behaviour = [Response] -> [Request]

stdin, stdout :: Name
stdin = "stdin"
stdout = "stdout"

-- OS 側。Haskell 1.0 では付録で「OS を関数として与える」形で仕様化されていた。
-- 要求 1 つに応答 1 つを返す。遅延リストなので要求が来た分だけ応答する。
os :: [(Name, String)] -> String -> [Request] -> [Response]
os _ _ [] = []
os fs input (r : rs) = case r of
    ReadChan _ -> Str input : os fs input rs
    ReadFile n -> case lookup n fs of
        Just s -> Str s : os fs input rs
        Nothing -> Failure ("no such file: " ++ n) : os fs input rs
    AppendChan _ _ -> Success : os fs input rs

-- プログラムと OS を互いに参照させて回す（knot-tying）。
-- reqs が resps を必要とし、resps が reqs を必要とする。
-- 遅延評価だけがこれを可能にしている。
run :: [(Name, String)] -> String -> Behaviour -> IO ()
run fs input behaviour = mapM_ emit reqs
  where
    reqs = behaviour resps
    resps = os fs input reqs
    emit (AppendChan _ s) = putStr s
    emit _ = return ()
