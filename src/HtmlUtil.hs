module HtmlUtil where

import           BasicPrelude
import qualified Data.Text                     as T
import           Text.HTML.TagSoup              ( Tag
                                                , innerText
                                                , partitions
                                                , (~/=)
                                                , (~==)
                                                )
import           GHC.Generics                   ( Generic )
import           Data.Aeson                     ( ToJSON )

import           FileUtil                       ( AbsolutePath
                                                , readFileLatin1
                                                , toFilePath
                                                , fixture
                                                )


htmlFixture :: FilePath -> IO Html
htmlFixture fname = do
  text <- readFileLatin1 (fixture fname)
  return $ makeHtml text


readHtmlFile :: AbsolutePath -> IO Html
readHtmlFile file = NewHtml <$> readFileLatin1 (toFilePath file)


-- Return the text content of an HTML title.
titleText :: [Tag Text] -> Text
titleText tags = case findFirst "<title>" tags of
  (_ : y : _) -> innerText [y]
  _           -> error $ "No <title> found in: " ++ (show tags)


-- Return the first occurrence of an HTML tag within the given
-- HTML chunk.
findFirst :: Text → [Tag Text] → [Tag Text]
findFirst searchTerm tags = case findAll searchTerm tags of
  (x : _) -> x
  _ ->
    error
      $  "Could not find the tag "
      ++ T.unpack searchTerm
      ++ " in: "
      ++ show tags


-- Return all the occurrences of an HTML tag within the given
-- HTML chunk.
findAll :: Text → [Tag Text] → [[Tag Text]]
findAll searchTerm = partitions (~== T.unpack searchTerm)


shaveBackTagsToLastClosingP :: [Tag Text] -> [Tag Text]
shaveBackTagsToLastClosingP input =
  reverse $ dropWhile (~/= ("</p>" :: String)) $ reverse input


--
-- HTML New Type
--
newtype Html = NewHtml Text
    deriving ( Eq, Generic, IsString, Show )

instance ToJSON Html

makeHtml :: Text -> Html
makeHtml = NewHtml

toText :: Html -> Text
toText (NewHtml t) = t
