{-# LANGUAGE OverloadedStrings #-}
module Database where

import Muste hiding (linearizeTree)
import Muste.Grammar

import Database.SQLite.Simple

import Crypto.Random.API

import Crypto.KDF.PBKDF2 hiding (generate)
import Crypto.Hash

import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy.Char8 as LB

import qualified Data.Map.Lazy as M

import Test.QuickCheck

import Data.Time.Clock
import Data.Time.Format

-- | hashPasswd returns a SHA512 hash of a PBKDF2 encoded password (SHA512,10000 iterations,1024 bytes output)
hashPasswd :: B.ByteString -> B.ByteString -> B.ByteString
hashPasswd pass salt =
--  B64.encode $ fastPBKDF2_SHA512 (Parameters 10000 1024) pass salt
  fastPBKDF2_SHA512 (Parameters 10000 1024) pass salt

-- | createSalt returns a SHA512 hash of 512 bytes of random data as a bytestring 
createSalt :: IO (B.ByteString)
createSalt =
  do
    rng <- getSystemRandomGen
    -- return $ B64.encode $ fst $ genRandomBytes 512 rng
    return $ fst $ genRandomBytes 512 rng

initDB :: Connection -> IO ()
initDB conn =
  do
    execute_ conn "DROP TABLE IF EXISTS User;"
    execute_ conn "DROP TABLE IF EXISTS Session;"
    execute_ conn "DROP TABLE IF EXISTS Lesson;"
    execute_ conn "DROP TABLE IF EXISTS Exercise;"
    execute_ conn "DROP TABLE IF EXISTS FinishedExercise;"
    execute_ conn "DROP TABLE IF EXISTS StartedLesson;"
    execute_ conn "DROP TABLE IF EXISTS FinishedLesson;"
    execute_ conn "DROP TABLE IF EXISTS ExerciseList";
    execute_ conn "CREATE TABLE User (Username TEXT, Password BLOB, Salt BLOB, PRIMARY KEY(Username));"
    execute_ conn "CREATE TABLE Session (User TEXT REFERENCES User(Username),Token TEXT, Starttime NUMERIC DEFAULT CURRENT_TIMESTAMP, LastActive NUMERIC DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(Token));"
    execute_ conn "CREATE TABLE Lesson (Name TEXT, Description TEXT, Grammar TEXT, ExerciseCount NUMERIC, PRIMARY KEY(Name));"
    execute_ conn "CREATE TABLE Exercise (SourceTree TEXT, TargetTree TEXT, Lesson TEXT, PRIMARY KEY(SourceTree, TargetTree, Lesson), FOREIGN KEY(Lesson) References Lesson(Name));"
    execute_ conn "CREATE TABLE FinishedExercise (User TEXT, SourceTree TEXT, TargetTree TEXT, Lesson TEXT, Time NUMERIC, ClickCount NUMERIC, PRIMARY KEY (User,SourceTree, TargetTree, Lesson), FOREIGN KEY (User) REFERENCES User(Username), FOREIGN KEY(SourceTree, TargetTree, Lesson) REFERENCES Exercise(SourceTree, TargetTree, Lesson));"
    execute_ conn "CREATE TABLE StartedLesson (Lesson TEXT, User TEXT, PRIMARY KEY(Lesson, User), FOREIGN KEY(Lesson) REFERENCES Lesson(Name), FOREIGN KEY(User) REFERENCES User(Username));"
    execute_ conn "CREATE TABLE FinishedLesson (Lesson TEXT, User TEXT, Time NUMERIC, FOREIGN KEY (User) REFERENCES User(Username), FOREIGN KEY (Lesson) REFERENCES Lesson(Name));"
    execute_ conn "CREATE TABLE ExerciseList (User TEXT, SourceTree TEXT, TargetTree TEXT, Lesson TEXT, PRIMARY KEY (User, SourceTree, TargetTree, Lesson), FOREIGN KEY(User) REFERENCES User(Username), FOREIGN KEY(SourceTree,TargetTree, Lesson) REFERENCES Exercise (SourceTree, TargetTree, Lesson));"
    let users = [("user1","pass1"),("user2","pass2"),("user3","pass3"),("user4","pass4"),("user5","pass5")]
    mapM_ (\(u,p) -> addUser conn u p) users
    let insertLessonQuery = "INSERT INTO Lesson (Name,Description,Grammar,ExerciseCount) VALUES (?,?,?,?);" :: Query
    let lessonData = [("Prima Pars","Den första Lektionen fran boken","Prima.pgf",5),
                      ("Seconda Pars","Den andra Lektionen fran boken","Secunda.pgf",8),
                      ("Tertia Pars","Den tredje Lektionen fran boken","Tertia.pgf",12),
                      ("Quarta Pars","Den fjärde Lektionen fran boken","Quarta.pgf",15)
                     ] :: [(String,String,String,Int)]
    mapM_ (execute conn insertLessonQuery) lessonData
    let insertExerciseQuery = "INSERT INTO Exercise (SourceTree,TargetTree,Lesson) VALUES (?,?,?);" :: Query
    let exercises = [
          ("useS (useCl (simpleCl (useCNindefsg (useN vinum_N)) (complA sapiens_A)))",
           "useS (useCl (simpleCl (usePron he_PP) (complA sapiens_A)))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (transV tenere_V2 (useCNdefsg (useN imperium_N)))))",
           "useS (useCl (simpleCl (useCNdefsg (useN imperator_N)) (transV tenere_V2 (useCNdefsg (useN imperium_N)))))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (complA felix_A)))",
           "useS (useCl (simpleCl (useCNdefsg (useN amicus_N)) (complA felix_A)))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (complA felix_A)))",
           "useS (useCl (simpleCl (useCNdefsg (useN pater_N)) (complA felix_A)))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN imperator_N))))",
           "useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN amicus_N))))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN amicus_N))))",
           "useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN imperator_N))))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN imperator_N))))",
           "useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN pater_N))))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN pater_N))))",
           "useS (useCl (simpleCl (usePN Augustus_PN) (complCN (useN imperator_N))))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (apposCNdefsg (useN Caesar_N) (usePN Augustus_PN)) (transV vincere_V2 (usePN Gallia_PN))))",
           "useS (useCl (simpleCl (apposCNdefsg (useN Caesar_N) (usePN Augustus_PN)) (transV vincere_V2 (usePN Africa_PN))))",
           "Prima Pars"),
          ("useS (useCl (simpleCl (apposCNdefsg (useN Caesar_N) (usePN Augustus_PN)) (transV vincere_V2 (usePN Africa_PN))))",
           "useS (useCl (simpleCl (apposCNdefsg (useN Caesar_N) (usePN Augustus_PN)) (transV vincere_V2 (usePN Gallia_PN))))",
           "Prima Pars")] :: [(String,String,String)]
    mapM_ (execute conn insertExerciseQuery) exercises

initPrecomputed :: Connection -> IO (M.Map String Precomputed)
initPrecomputed conn =
  do
    let selectLessonsGrammarsQuery = "SELECT Name,Grammar FROM Lesson;" :: Query
    let selectStartTreesQuery = "SELECT SourceTree FROM Exercise WHERE Lesson = ?;" :: Query
    l <- query_ conn selectLessonsGrammarsQuery :: IO [(String,String)]
    -- map (\(lesson,grammar) -> do
    --         pgf <-readPGF grammar
    --         langs <- languages pgf
    --         trees <- query conn selectStartTrees
    --         precomputeTrees context 
    --         ) lessons
    foo <- [ (lesson, lang, precomputedTrees (pgfToGrammar pgf,lang) tree) | tree <- query conn selectStartTrees lesson , lang <- languages pgf, pgf <- readPGF grammar, (lesson,grammar) <- grammar]
    return M.empty -- :: IO M.Map String Precomputed
    
addUser :: Connection -> String -> String -> IO ()
addUser conn user pass =
  do
    -- Create a salted password
    salt <- createSalt
    let safePw = hashPasswd (B.pack pass) salt
    -- Remove user if they already exists
    let deleteQuery = "DELETE FROM User WHERE Username = ?;" :: Query
    execute conn deleteQuery [user]
    -- Add new user
    let insertQuery = "INSERT INTO User (Username, Password, Salt) VALUES (?,?,?);" :: Query
    execute conn insertQuery (user,safePw,salt)

authUser :: Connection -> String -> String -> IO (Bool)
authUser conn user pass =
  do
    -- Get password and salt from database
    let selectPasswordSaltQuery = "SELECT Password,Salt FROM User WHERE (Username == ?);" :: Query
    [(dbPass,dbSalt)] <- (query conn selectPasswordSaltQuery [user]) :: IO [(B.ByteString,B.ByteString)]
    -- Generate new password hash and compare to the stored one
    let pwHash = hashPasswd (B.pack pass) dbSalt
    return $ pwHash == dbPass

changePassword :: Connection -> String -> String -> String -> IO ()
changePassword conn user oldPass newPass =
  do
    authed <- authUser conn user oldPass
    if authed then addUser conn user newPass else return ()
                                                          
-- | Creates a new session. at the moment overly simplified
startSession :: Connection -> String -> IO String
startSession conn user =
  do
    -- maybe check for old sessions and clean up?
    let deleteSessionQuery = "DELETE FROM Session WHERE User = ? ;" :: Query
    execute conn deleteSessionQuery [user]
    -- create new session
    timeStamp <- formatTime defaultTimeLocale "%s" <$> getCurrentTime 
    let sessionData = user ++ timeStamp
    let token = show (hash (B.pack sessionData) :: Digest SHA3_512) :: String
    let insertSessionQuery = "INSERT INTO Session (Token,User,Starttime,LastActive) VALUES (?,?,?,?);" :: Query
    execute conn insertSessionQuery (token,user,timeStamp,timeStamp)
    return token

updateActivity :: Connection -> String -> IO()
updateActivity conn token =
  do
    timeStamp <- formatTime defaultTimeLocale "%s" <$> getCurrentTime 
    let updateSessionLastActiveQuery = "UPDATE Session SET LastActive = ? WHERE Token = ?;" :: Query
    execute conn updateSessionLastActiveQuery (timeStamp,token)

verifySession :: Connection -> String -> IO (Bool,String)
verifySession conn token =
  do
    -- Get potential user session(s)
    let selectSessionQuery = "SELECT LastActive FROM Session WHERE Token = ?;" :: Query
    sessions@[[lastActive]] <- query conn selectSessionQuery [token] :: IO [[Int]]
    -- from here might not be executed due to lazy evaluation...
    -- Compute the difference in time stamps
    let oldTimeStamp = lastActive
    timeStamp <- formatTime defaultTimeLocale "%s" <$> getCurrentTime 
    let newTimeStamp = read timeStamp :: Int
    let deleteSessionQuery = "DELETE FROM Session WHERE Token = ? ;"
    let error = if length sessions == 0 then "Not current session" else if newTimeStamp - oldTimeStamp > 60 * 30 then "Session timeout" else "More than one session"
    -- ... until here. check if a session exists and it is has been active in the last 15 minutes
    if length sessions == 1 && newTimeStamp - oldTimeStamp <= 60*30 then return (True,"")
    else do { execute conn deleteSessionQuery [token] ; return (False,error) }

-- | List all the lessons i.e. lesson name, description and exercise count
listLessons :: Connection -> String -> IO [(String,String,Int,Bool)]
listLessons conn token =
  do
    let listUserQuery = "SELECT User FROM Session WHERE Token = ?;"
    let listLessonsQuery = "SELECT Name,Description,ExerciseCount,Name IN (SELECT Name FROM FinishedLesson WHERE User = ?) as Passed FROM Lesson;"
    [[user]] <- query conn listUserQuery [token] :: IO [[String]]
    query conn listLessonsQuery [user] :: IO [(String,String,Int,Bool)]
    
-- | start a new lesson by randomly choosing the right number of exercises and adding them to the users exercise list
startLesson :: Connection -> String -> String -> IO () -- (String,String)
startLesson conn token lesson =
  do
    -- get user name
    let userQuery = "SELECT User FROM Session WHERE Token = ?;" :: Query
    [[user]] <- query conn userQuery [token] :: IO [[String]]
    -- get exercise count
    let exerciseCountQuery = "SELECT ExerciseCount FROM Lesson WHERE Name = ?;" :: Query
    [[count]] <- query conn exerciseCountQuery [lesson] :: IO [[Int]]
    -- get all exercises for lesson
    let exerciseQuery = "SELECT SourceTree,TargetTree FROM Exercise WHERE Lesson = ?;" :: Query
    trees <- query conn exerciseQuery [lesson] :: IO [(String,String)]
    -- randomly select
    selectedTrees <- fmap (take count) $ generate $ shuffle trees
    -- save in database
    let insertStartedLesson = "INSERT INTO StartedLesson (Lesson, User) VALUES (?,?);" :: Query
    execute conn insertStartedLesson (lesson,user)
    let insertExerciseList = "INSERT INTO ExerciseList (Lesson,User,SourceTree,TargetTree) VALUES (?,?,?,?);" :: Query
    mapM_ (\(sTree,tTree) -> execute conn insertExerciseList (lesson,user,sTree,tTree)) selectedTrees
    return ()
    
main =
  do
    putStrLn "Starting"
    con <- open "muste.db"
    initDB con
