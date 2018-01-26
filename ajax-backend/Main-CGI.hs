{-# LANGUAGE OverloadedStrings #-}
module Main where

import Ajax
import Protocol
import Database hiding (main)


import PGF

import Muste
import Muste.Grammar

import Database.SQLite.Simple

import Network.SCGI
import Network.CGI
import Network

import Data.Map

import Control.Monad



-- -- Switch loggin on/off
-- logging = True
-- logFile = "messagelog.txt"

handleCGI :: Connection -> Map String Grammar -> LessonsPrecomputed -> CGI CGIResult
handleCGI conn grammars prec =
  do
    setHeader "Content-type" "text/json"
    b <- getBody
    liftIO $ putStrLn (show b)
    output b
    
-- cgi grammar =
--   do

--     b <- getBody
--     liftIO $ putStrLn $ "CGI" ++ b
--     result <- liftIO $ handleClientRequest grammar b
--     output result
    
main :: IO ()
main =
  do
    dbConn <- open "muste.db"
    (grammars,precs) <- initPrecomputed dbConn
    runSCGIConcurrent 10 (PortNumber 9000) (handleCGI dbConn grammars precs)
    return ()
