-- 記事「リストによる書き換え」の掲載コードの検証
import Data.List (unfoldr)

g123, nats, squares, nats' :: [Int]
g123    = [1, 2, 3]
nats    = [0 ..]
squares = map (^ 2) [1 .. 5]
nats'   = unfoldr (\n -> Just (n, n + 1)) 0

main :: IO ()
main = do
    print g123
    print (take 5 nats)
    print squares
    print (take 5 nats')
