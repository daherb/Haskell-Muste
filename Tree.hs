{-# LANGUAGE FlexibleInstances #-}
module Tree where
import PGF hiding (showType)
import PGF.Internal hiding (showType)
import Data.Maybe
import Data.List
import Data.Ord
import Grammar
import Debug.Trace
      
class TreeC t where
  showTree :: t -> String
  selectNode :: t -> Path -> Maybe t
  selectBranch :: t -> Int -> Maybe t
--  findPath :: t -> t -> Maybe Path


type Pos = Int
type Path = [Pos]

-- A generic tree with types
data TTree = TNode CId (Maybe FunType) [TTree]
           | TMeta CId

data MetaTTree = MetaTTree {
  metaTree :: TTree,
  subTrees :: [(Path,TTree)]
  }
                 
showType :: Maybe Type -> String
showType Nothing = "NoType"
showType (Just (DTyp hypos id exprs)) = show id

instance Show TTree where
  show (TNode name (Just t) []) = "{"++ (show name) ++ ":"  ++ show t ++ "}";
  show (TNode name (Just t)  children) = "{" ++ (show name) ++ ":" ++ show t ++ " " ++ ( unwords $ map show children ) ++ "}"
  show (TNode name Nothing []) = "{"++ (show name) ++ "}";
  show (TNode name Nothing  children) = "{" ++ (show name) ++ " " ++ ( unwords $ map show children ) ++ "}"
  show (TMeta cat) = "{?" ++ show cat ++ "}"
instance Show MetaTTree where
  show tree =
    "(" ++ show (metaTree tree) ++ 
    ", [" ++ unwords (map show (subTrees tree)) ++ "])\n"
instance TreeC Tree where
  showTree = show
  selectNode t p = Nothing
  selectBranch t i = Nothing
--  findPath s n = Nothing

instance TreeC TTree where
  showTree = show
  selectNode t [] = Just t
  selectNode t [b] = selectBranch t b
  selectNode t (hd:tl) =
    let
        branch = (selectBranch t hd)
    in
      case branch of {
        Just b -> selectNode b tl ;
        Nothing -> Nothing
      }
  selectBranch (TMeta _) _ = Nothing
  selectBranch (TNode _ _ [] ) _ = Nothing
  selectBranch (TNode _ _ trees) i = Just (trees !! i)

instance Eq TTree where
  (==) (TMeta id1) (TMeta id2) = id1 == id2
  (==) (TNode _ typ1 trees1) (TNode _ typ2 trees2) = (typ1 == typ2) && (trees1 == trees2)
  (==) _ _ = False
             
instance Eq MetaTTree where
  (==) t1 t2 =
      (metaTree t1 == metaTree t2) && (subTrees t1 == subTrees t2)
--  findPath s n = Nothing


-- path2upath :: UTree -> Path -> Maybe UPath
-- path2upath ut [] = Just []
-- path2upath (UEFun id pos) [0] = Just [pos]
-- path2upath (UEApp e1 e2 pos) (p:rest)
--   | p == 0 = let next = (path2upath e1 rest) in if isJust next then Just (pos:(fromJust next)) else Nothing
--   | p == 1 = let next = (path2upath e2 rest) in if isJust next then Just (pos:(fromJust next)) else Nothing
--   | otherwise = Nothing

-- Creates a generic tree from an abstract syntax tree
treeToTTree :: PGF -> Tree -> TTree
treeToTTree pgf (EFun f) =
  let
    typ = getFunType pgf f
  in
    TNode f typ []
treeToTTree pgf (EApp e1 e2) =
  let
    (TNode name typ sts) = treeToTTree pgf e1
    st2 = treeToTTree pgf e2
  in
    (TNode name typ (sts ++ [st2]))

-- Creates a AST from a generic tree
ttreeToTree :: TTree -> Tree
ttreeToTree (TNode name _ []) = (EFun name)
ttreeToTree (TNode name _ ts) =
  let
     nts = map ttreeToTree ts
  in
    mkApp name nts


-- Creates a list of all subtrees with its depth for a TTree
tSubTrees :: TTree -> [(Int,[TTree])]
tSubTrees tree =
  let
    internal :: Int -> TTree -> [(Int,[TTree])]
    internal depth (TNode id cat []) = []
    internal depth n@(TNode id cat children) =
      let
        ndepth = depth + 1
      in
        (ndepth,children):(concat $ map (internal ndepth) children) 
  in
    internal 0 tree

-- Prune all subtrees to a certain depth
-- prune :: TTree -> Int -> [MetaTTree]
-- prune tree depth =
--   let
--     inner_prune t@(TNode name cat sts) depth path =
--       let
--         (newTree0,subTree0) = makeMeta t 0
--         (newTree1,subTree1) = makeMeta t 1
--       in
--         [MetaTTree (TMeta ((\(Just (Fun c _)) -> c) cat)) [(path,t)]] ++
--         [MetaTTree newTree0 [(path ++ [0],subTree0)]] ++
--         [MetaTTree newTree1 [(path ++ [0],subTree1)]]
      
--     -- inner_prune :: TTree -> Int -> [Int] -> [MetaTTree]
--     -- inner_prune tree 0 path = [MetaTTree tree []]
--     -- inner_prune (TMeta cat) _ path = [MetaTTree (TMeta cat) []]
--     -- inner_prune (TNode name cat sts) depth path =
--     --   let
--     --     mapPruneOverTrees [] _ _ pos = []
--     --     mapPruneOverTrees trees depth path pos =
--     --       let
--     --         npath = path ++ [pos]
--     --         pruned = inner_prune (head trees) depth npath
--     --       in
--     --         pruned ++ (mapPruneOverTrees (tail trees) depth path (pos + 1))
--     --   in
--     --     mapPruneOverTrees sts (depth - 1) path 0
--   in
--     inner_prune tree depth []

-- makeMeta (TNode name typ sts) pos =
--   let
--     subTree = sts !! pos
--     (nSts1,nSts2) = splitAt pos sts
--     meta = TMeta ((\(TNode _ typ _) -> (\(Just (Fun cat _)) -> cat) typ) subTree)
--     nSts = nSts1 ++ (meta:(tail nSts2))
--     newTree = (TNode name typ nSts)
--   in
--     (newTree,subTree)

makeMeta :: TTree -> MetaTTree
makeMeta tree =
    MetaTTree tree []
replaceBranchByMeta :: TTree -> Pos -> TTree
replaceBranchByMeta t@(TNode id typ trees) pos =
    let
        subTree = trees !! pos
        cat = (\(TNode _ (Just (Fun id _)) _) -> id) subTree

    in
      case subTree of {
        (TNode _ (Just (Fun id _)) _) ->
            let newTrees = let (pre,post) = splitAt pos trees in (pre ++ ((TMeta cat):tail post))
            in (TNode id typ newTrees) ;
        _ -> t
      }

replaceNodeByMeta :: MetaTTree -> Path -> MetaTTree
replaceNodeByMeta tree fullpath =
    let
        internal :: MetaTTree -> Path -> Path -> MetaTTree
        internal tree fullpath [] =
            let
                oldMeta = metaTree tree
            in
              case oldMeta of {
                (TNode _ (Just (Fun id _)) _ ) -> MetaTTree (TMeta id) [(fullpath,oldMeta)] ;
                (TMeta _) -> tree
              }
        internal tree fullpath [pos] =
            let
                oldMeta = metaTree tree
                newBranch = fromJust (selectBranch oldMeta pos) 
                newSub = (fullpath, newBranch)
                newMeta = replaceBranchByMeta oldMeta pos
            in
              MetaTTree newMeta (newSub:subTrees tree)
        internal tree fullpath (p:ps) =
            let
                (TNode id typ trees) = metaTree tree
                (pre,post) = splitAt p trees
                (MetaTTree newMeta newInner) = internal (MetaTTree (trees !! p) (subTrees tree)) fullpath ps
            in
              (MetaTTree (TNode id typ (pre ++ (newMeta:tail post))) newInner)
    in
      internal tree fullpath fullpath

          
maxPath :: Int -> TTree -> [Path]
maxPath 0 _ = [[]]
maxPath _ (TNode _ _ []) = [[]]
maxPath maxDepth (TNode _ _ trees) =
    let
        branches :: [(Pos, TTree)] -- List of branch positions and subtrees 
        branches = (zip [0..(length trees)] trees)
        relevantBranches :: [(Pos, TTree)] -- List of all branches that don't end in a meta
        relevantBranches = (filter (\t -> case t of { (_, (TNode _ _ _)) -> True ; _ -> False } ) branches)
        relevantPaths :: [(Pos, [Path])] -- List of the maximum pathes of the subtrees for each branch
        relevantPaths = map (\(p,t) -> (p,(maxPath (maxDepth - 1) t))) relevantBranches
        nPaths :: [Path]
        nPaths = concat $ map (\(p,ps) -> map (\s -> p:s) ps ) relevantPaths
        mDepth :: Int
        mDepth = maximum $ 0:(map length nPaths)
        filtered :: [Path]
        filtered = filter (\x -> (length x) == mDepth) nPaths
    in
      case filtered of {
        [] -> [[]] ;
        _ -> filtered
      }
maxPath _ (TMeta _) = [[]]

prune :: TTree -> Int -> [MetaTTree]
prune tree depth =
  let
    pruneTrees :: [MetaTTree] -> Int -> [MetaTTree]
    pruneTrees [] _ = []
    pruneTrees trees depth =
      let
        tree = head trees
        dPath = maxPath depth (metaTree tree)
      in
        case dPath of {
          [] -> [] ;
--          [[]] -> [tree] ;
          _ -> let
                 nTree = (replaceNodeByMeta tree $ head dPath)
                 nTrees = nTree : (pruneTrees [nTree] depth) ++ (pruneTrees (tail trees) depth)
               in
                 if trees == nTrees then [] else nTrees --nTree : (pruneTrees (tail trees) depth) -- (pruneTrees [nTree] depth) ++ (pruneTrees (tail trees) depth)
        }
  in
    pruneTrees [(makeMeta tree)] depth

getMetaLeaves :: TTree -> [CId]
getMetaLeaves (TMeta id) = [id]
getMetaLeaves (TNode _ _ trees) = concat $ map getMetaLeaves trees

findRules :: Grammar -> [CId] -> [Rule]
findRules grammar cats =
    let
        rs = rules grammar
    in
      concat $ map (\c -> filter (\(Function _ (Just (Fun fcat _))) -> fcat == c ) rs) cats
             
combine :: MetaTTree -> Rule -> [MetaTTree]
combine tree rule =
  let
      combined = combineFoo tree [] rule
      cleaned = map
                  (
                    \(MetaTTree metaTree subTrees) ->
                      let
                          filteredSubTrees = filter (\(path,_) -> case (selectNode metaTree path) of { (Just (TMeta _)) -> True ; _ -> False }) subTrees
                          sortedSubTrees = sortBy (\(p1,_) -> \(p2,_) -> compare p1 p2) filteredSubTrees
                      in
                        MetaTTree metaTree filteredSubTrees
                  ) combined
  in
    cleaned
    -- BOOOOOOOOHOOOOOOOOOO here be bugs
combineFoo :: MetaTTree -> Path -> Rule -> [MetaTTree]
combineFoo m@(MetaTTree (TMeta lcat) sts) path (Function fid funtype@(Just (Fun fcat cats))) =
    if lcat == fcat then -- matching rule
        let
            -- Generate new metaTree by converting function type to meta nodes
            newMetaTree = (TNode fid funtype (map TMeta cats))
            -- Generate new subtrees also by converting the function type to meta subtrees plus the old one minus what is no longer meta
            newSubTrees = nub $ (sts ++ (map (\(p,c) -> (path ++ [p], TMeta c)) (zip [0..(length cats)] cats)))
        in
          [MetaTTree newMetaTree newSubTrees]
    else -- not matching -> just keep it as a list
        [m]
combineFoo (MetaTTree (TNode fid funtype trees) subTrees) path rule =
  let
      -- Convert subtrees to metattrees
      metaSubtrees = (map (\t -> MetaTTree t subTrees) trees)
      -- Number all trees in the list -> needed for remembering the path
      numberedMetaSubtrees = (zip [0..length trees] metaSubtrees)
      -- Try to apply the rule
      combinedTrees = concat $ map (\(p,t) -> combineFoo t (p:path) rule) numberedMetaSubtrees
      -- Number again
      numberedCombinedTrees = (zip [0..length combinedTrees] combinedTrees)
  in
      map
        (
           \(p,(MetaTTree metaTree newSubtrees)) ->
             let
               (pre,post) = splitAt p trees
             in
               MetaTTree (TNode fid funtype (pre ++ metaTree:(tail post))) -- Replace old subtrees by new subtrees
                         (nub $ ((delete (subTrees !! p) subTrees) ++ newSubtrees))
         ) numberedCombinedTrees

extendTree :: Grammar -> Int -> MetaTTree -> [MetaTTree]
extendTree grammar maxDepth tree =
  let
      mTree :: TTree
      mTree = metaTree tree
      sTrees :: [(Path,TTree)]
      sTrees = subTrees tree
      metaLeaves :: [CId]
      metaLeaves = nub $ getMetaLeaves mTree
      rules :: [Rule]
      rules = findRules grammar metaLeaves
  in
--    convergeTrees grammar maxDepth $ concat $ map (combine tree) rules
    concat $ map (combine tree) rules

convergeTrees :: Grammar -> Int -> [MetaTTree] -> [MetaTTree]
convergeTrees grammar maxDepth trees =
  let
      newTrees =  filter (\t -> (length $ maxPath maxDepth $ metaTree t) < maxDepth) (nub $ concat $ map (extendTree grammar maxDepth) trees)
  in
    trace "CONVERGETREES" $ if newTrees == trees then
        newTrees
    else
        convergeTrees grammar maxDepth newTrees

generate :: Grammar -> CId -> Int -> [MetaTTree]
generate grammar cat maxDepth =
    let
        loop :: Int -> [MetaTTree] -> [MetaTTree]
        loop 0 oldTrees = oldTrees
        loop count oldTrees =
           let
               newTrees = (concat $ map (extendTree grammar maxDepth) oldTrees)
           in
             oldTrees ++ (loop (count - 1) newTrees)
        startTree = MetaTTree (TMeta cat) [([],(TMeta cat))]
    in
      trace "GENERATE" $ nub $ loop maxDepth [startTree]
--      extendTree grammar maxDepth startTree
                           
t = (TNode (mkCId "f") (Just (Fun (mkCId "A") [(mkCId "A"),(mkCId "B")])) [(TNode (mkCId "a") (Just (Fun (mkCId "A") [])) []),(TNode (mkCId "g") (Just (Fun (mkCId "B") [(mkCId "B"),(mkCId "C")])) [(TNode (mkCId "b") (Just (Fun (mkCId "B") [])) []),(TNode (mkCId "c") (Just (Fun (mkCId "C") [])) [])])])

t2 = (TNode (mkCId "f") (Just (Fun (mkCId "F") [(mkCId "A"), (mkCId "G")])) [(TMeta (mkCId "A")), (TNode (mkCId "g") (Just (Fun (mkCId "G") [(mkCId "B"), (mkCId "H")])) [(TMeta (mkCId "B")), (TNode (mkCId "h") (Just (Fun (mkCId "H") [(mkCId "C"), (mkCId "I")])) [(TMeta (mkCId "C")), (TNode (mkCId "i") (Just (Fun (mkCId "I") [(mkCId "D"),(mkCId "E")])) [(TMeta (mkCId "D")), (TMeta (mkCId "E"))])])])])

t3 = metaTree $ replaceNodeByMeta (replaceNodeByMeta (makeMeta t) [1,0]) [1,1]

t4 = (TNode (mkCId "f") (Just (Fun (mkCId "A") [(mkCId "A"),(mkCId "B")])) [(TMeta (mkCId "A")), (TMeta (mkCId "B"))])
g1 = Grammar (mkCId "A")
     [
      Function (mkCId "f") (Just (Fun (mkCId "A") [(mkCId "A"),(mkCId "B")])),
      Function (mkCId "g") (Just (Fun (mkCId "B") [(mkCId "B"),(mkCId "C")])),
      Function (mkCId "a") (Just (Fun (mkCId "A") [])),
      Function (mkCId "b") (Just (Fun (mkCId "B") [])),
      Function (mkCId "c") (Just (Fun (mkCId "C") []))
     ]
g2 = Grammar (mkCId "A")
     [
      Function (mkCId "f") (Just (Fun (mkCId "A") [(mkCId "A"),(mkCId "A")])),
      Function (mkCId "a") (Just (Fun (mkCId "A") [])) -- ,
--      Function (mkCId "aa") (Just (Fun (mkCId "A") [(mkCId "A")]))
     ]

main =
    generate g1 (mkCId "A") 2
