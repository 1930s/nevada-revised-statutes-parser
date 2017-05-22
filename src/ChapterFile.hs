module ChapterFile where

import           BasicPrelude
import qualified Data.Attoparsec.Text    (parseOnly, Parser, takeText, takeWhile)
import           Data.Char               (isSpace)
import           Data.Text               (pack)
import           Text.HTML.TagSoup
import           Text.Parser.Char

import           HtmlUtil                (shaveBackTagsToLastClosingP, titleText)
import           TextUtil                (normalizeWhiteSpace, normalizedInnerText, titleize)
import           Models


type Html = Text

parseChapter :: Html -> Chapter
parseChapter chapterHtml =
  Chapter {
    chapterName   = name,
    chapterNumber = number,
    chapterUrl    = (pack "https://www.leg.state.nv.us/nrs/NRS-") ++ number ++ (pack ".html"),
    subChapters   = subChaps
  }
  where tags           = parseTags chapterHtml
        rawTitle       = titleText tags
        (number, name) = parseChapterFileTitle rawTitle
        subChaps       = fmap (newSubChapter tags) (headingGroups tags)


newSubChapter :: [Tag Text] -> [Tag Text] -> SubChapter
newSubChapter dom headingGroup =
  SubChapter {
    subChapterName     = subChapterNameFromGroup headingGroup,
    subChapterChildren = children
  }
  where children = if isSimpleSubChapter headingGroup
                     then SubChapterSections $ parseSectionsFromHeadingGroup dom headingGroup
                     else SubSubChapters     $ parseSubSubChapters dom headingGroup


parseSectionsFromHeadingGroup :: [Tag Text] -> [Tag Text] -> [Section]
parseSectionsFromHeadingGroup dom headingGroup =
  fmap (parseSectionFromHeadingParagraph dom) (partitions (~== "<p class=COLeadline>") headingGroup)


parseSectionFromHeadingParagraph :: [Tag Text] -> [Tag Text] -> Section
parseSectionFromHeadingParagraph dom paragraph =
  Section {
    sectionName   = name,
    sectionNumber = number,
    sectionBody   = body
  }
  where
    name   = normalizedInnerText $ dropWhile (~/= "</a>") paragraph
    number = (!! 1) $ words $ normalizedInnerText $ takeWhile (~/= "</a>") paragraph
    body   = parseSectionBody number dom


parseSubSubChapters :: [Tag Text] ->[Tag Text] -> [SubSubChapter]
parseSubSubChapters dom headingGroup =
  fmap (parseSubSubChapter dom) (subSubChapterHeadingGroups headingGroup)


subSubChapterHeadingGroups :: [Tag Text] -> [[Tag Text]]
subSubChapterHeadingGroups headingGroup =
  (partitions (~== "<p class=COHead4>") headingGroup)


parseSubSubChapter :: [Tag Text] ->[Tag Text] -> SubSubChapter
parseSubSubChapter dom subSubChapterHeadingGroup =
  SubSubChapter {
    subSubChapterName     = name,
    subSubChapterSections = parseSectionsFromHeadingGroup dom subSubChapterHeadingGroup
  }
  where
    name = (normalizeWhiteSpace . (!!0) . lines . innerText) subSubChapterHeadingGroup


subchapterNames :: [Tag Text] -> [Text]
subchapterNames tags =
  fmap subChapterNameFromGroup (headingGroups tags)


subChapterNameFromGroup :: [Tag Text] -> Text
subChapterNameFromGroup = 
  titleize . fromTagText . (!! 1)


sectionNamesFromGroup :: [Tag Text] -> [Text]
sectionNamesFromGroup headingGroup =
  fmap sectionNameFromParagraph (partitions (~== "<p class=COLeadline>") headingGroup)


sectionNameFromParagraph :: [Tag Text] -> Text
sectionNameFromParagraph = 
  normalizedInnerText . (dropWhile (~/= "</a>"))


headingGroups :: [Tag Text] -> [[Tag Text]]
headingGroups tags = 
  partitions (~== "<p class=COHead2>") tags


-- Input:  "NRS: CHAPTER 432B - PROTECTION OF CHILDREN FROM ABUSE AND NEGLECT"
-- Output: ("432B", "Protection of Children from Abuse and Neglect")
parseChapterFileTitle :: Text -> (Text, Text)
parseChapterFileTitle input =
  case (Data.Attoparsec.Text.parseOnly chapterTitleParser input) of
    Left e  -> error e
    Right b -> b
        

-- Input:  "NRS: CHAPTER 432B - PROTECTION OF CHILDREN FROM ABUSE AND NEGLECT"
-- Output: ("432B", "Protection of Children from Abuse and Neglect")
chapterTitleParser :: Data.Attoparsec.Text.Parser (Text, Text)
chapterTitleParser = do
  _      <- string "NRS: CHAPTER "
  number <- Data.Attoparsec.Text.takeWhile (not . isSpace)
  _      <- string " - "
  title  <- Data.Attoparsec.Text.takeText
  return $ (number, titleize title)


isSimpleSubChapter :: [Tag Text] -> Bool
isSimpleSubChapter headingGroup =
  null (partitions (~== "<p class=COHead4>") headingGroup)


parseSectionBody :: Text -> [Tag Text] -> Text
parseSectionBody number dom = 
  sectionText
  where sectionGroups   = partitions (~== "<span class=Section") dom
        rawSectionGroup = shaveBackTagsToLastClosingP $ (!! 0) $ filter (isSectionBodyNumber number) sectionGroups 
        sectionText     = normalizeWhiteSpace $ pack "<p class=SectBody>" ++ (renderTags rawSectionGroup)


isSectionBodyNumber :: Text -> [Tag Text] -> Bool
isSectionBodyNumber number dom =
  parseSectionBodyNumber dom == number
  

parseSectionBodyNumber :: [Tag Text] -> Text
parseSectionBodyNumber dom = 
  innerText $ takeWhile (~/= "</span>") dom