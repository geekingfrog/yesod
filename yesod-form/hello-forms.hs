{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes, TypeFamilies, TemplateHaskell, MultiParamTypeClasses #-}
import Yesod.Core
import Yesod.Form
import Yesod.Form.MassInput
import Control.Applicative
import Data.Text (Text, pack)
import Network.Wai.Handler.Warp (run)
import Data.Time (utctDay, getCurrentTime)
import qualified Data.Text as T

data Fruit = Apple | Banana | Pear
    deriving (Show, Enum, Bounded, Eq)

fruits :: [(Text, Fruit)]
fruits = map (\x -> (pack $ show x, x)) [minBound..maxBound]

myForm = fixType $ runFormGet $ renderDivs $ pure (,,,,,,,,)
    <*> areq boolField "Bool field" Nothing
    <*> aopt boolField "Opt bool field" Nothing
    <*> areq textField "Text field" Nothing
    <*> areq (selectField fruits) "Select field" Nothing
    <*> aopt (selectField fruits) "Opt select field" Nothing
    <*> areq (multiSelectField fruits) "Multi select field" Nothing
    <*> aopt (multiSelectField fruits) "Opt multi select field" Nothing
    <*> aopt intField "Opt int field" Nothing
    <*> aopt (radioField fruits) "Opt radio" Nothing

data HelloForms = HelloForms
type Handler = GHandler HelloForms HelloForms

fixType :: Handler a -> Handler a
fixType = id

instance RenderMessage HelloForms FormMessage where
    renderMessage _ _ = defaultFormMessage

instance Yesod HelloForms where
    approot _ = ""

mkYesod "HelloForms" [parseRoutes|
/ RootR GET
/mass MassR GET
/valid ValidR GET
|]

getRootR = do
    ((res, form), enctype) <- myForm
    defaultLayout [whamlet|
<p>Result: #{show res}
<form enctype=#{enctype}>
    ^{form}
    <div>
        <input type=submit>
<p>
    <a href=@{MassR}>See the mass form
<p>
    <a href=@{ValidR}>Validation form
|]

myMassForm = fixType $ runFormGet $ renderTable $ inputList "People" massTable
    (\x -> (,)
        <$> areq textField "Name" (fmap fst x)
        <*> areq intField "Age" (fmap snd x)) (Just [("Michael", 26)])

getMassR = do
    ((res, form), enctype) <- myMassForm
    defaultLayout [whamlet|
<p>Result: #{show res}
<form enctype=#{enctype}>
    <table>
        ^{form}
    <div>
        <input type=submit>
<p>
    <a href=@{RootR}>See the regular form
|]

myValidForm = fixType $ runFormGet $ renderTable $ pure (,,)
    <*> areq (check (\x -> if T.length x < 3 then Left "Need at least 3 letters" else Right x) textField) "Name" Nothing
    <*> areq (checkBool (>= 18) "Must be 18 or older" intField) "Age" Nothing
    <*> areq (checkM inPast dayField) "Anniversary" Nothing
  where
    inPast x = do
        now <- getCurrentTime
        return $ if utctDay now < x then Left "Need a date in the past" else Right x

getValidR = do
    ((res, form), enctype) <- myValidForm
    defaultLayout [whamlet|
<p>Result: #{show res}
<form enctype=#{enctype}>
    <table>
        ^{form}
    <div>
        <input type=submit>
<p>
    <a href=@{RootR}>See the regular form
|]

main = toWaiApp HelloForms >>= run 3000