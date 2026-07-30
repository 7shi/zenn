-- type シノニムで書くと循環でエラーになる（記事の記述に対応する失敗例）
newtype Cont r a = Cont { runCont :: (a -> r) -> r }

type It = (Maybe Int, () -> Cont It It)

main :: IO ()
main = return ()
