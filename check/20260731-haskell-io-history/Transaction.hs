-- Figure 4「Continuation I/O」で共通して使うトランザクション（Report の定義そのまま）。
-- figure4.hs・figure4op.hs・figureDo.hs から共有する。
module Transaction where

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

fs :: [(Name, String)]
fs = [("hello.txt", "Hello, continuation I/O!\n")]
