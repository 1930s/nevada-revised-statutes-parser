{-# LANGUAGE OverloadedStrings #-}

import           BasicPrelude
import qualified Data.Aeson.Encode.Pretty as Aeson (encodePretty)
import qualified Data.ByteString.Lazy     as B
import qualified Data.HashMap.Lazy        as HM
import           Data.Time                (Day, getZonedTime, localDay,
                                           zonedTimeToLocalTime)

import           FileUtil                 (AbsolutePath, listFilesInDirectory, toAbsolutePath, toRelativePath, toFilePath)
import           HtmlUtil
import           Models.NRS
import           NRSParser
import           System.FilePath


main :: IO ()
main = do
    nrs <- parseFiles sourceDir
    let nevadaJson = Aeson.encodePretty nrs
    B.putStr nevadaJson


parseFiles :: AbsolutePath -> IO NRS
parseFiles dir = do
    let indexFile = toAbsolutePath $ (toFilePath dir) </> "index.html"
    chapterFilenames <- listFilesInDirectory dir
    let relativeChapterFilenames = map (toRelativePath . takeFileName . toFilePath) chapterFilenames
    today            <- todaysDate
    indexHtml        <- readHtmlFile indexFile
    chaptersHtml     <- mapM readHtmlFile chapterFilenames
    let chaptersMap  = HM.fromList $ zip relativeChapterFilenames chaptersHtml
    return $ parseNRS indexHtml chaptersMap today


todaysDate :: IO Day
todaysDate = fmap (localDay . zonedTimeToLocalTime) getZonedTime


sourceDir :: AbsolutePath
sourceDir = toAbsolutePath "/tmp/www.leg.state.nv.us/NRS"
