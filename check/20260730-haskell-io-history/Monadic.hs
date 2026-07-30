-- Haskell 1.3 (1996) で採用されたモナド版 I/O（論文の Figure 6）を
-- 現行の Haskell に移植したもの。
--
-- Figure 6 の appendChan / readChan は現在の標準ライブラリには無いので、
-- 対応するものに置き換えた。catch は Control.Exception のものを使う。
import Control.Exception (IOException, catch)
import System.IO

-- Figure 6 の appendChan stdout に相当
appendChan :: Handle -> String -> IO ()
appendChan = hPutStr

-- Figure 6 の readChan stdin に相当
readChan :: Handle -> IO String
readChan = hGetContents

figure6 :: IO ()
figure6 = do
    appendChan stdout "enter filename\n"
    userInput <- readChan stdin
    let (name : _) = lines userInput
    appendChan stdout name
    catch
        ( do
            contents <- readFile name
            appendChan stdout contents
        )
        (\e -> appendChan stdout ("can't open file: " ++ show (e :: IOException) ++ "\n"))

main :: IO ()
main = figure6
