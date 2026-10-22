# Localization

The text of a game lives in `strings/<lang>.csv` files of the project (`strings/en.csv`, `strings/de.csv`, `strings/pt-br.csv`, ...), one `key,text` per line. A level script asks for text by key:

```lua
ui.text(28, 22, tr("title"), { size = 30 })
ui.text(28, 60, tr("position", x, y, z))        -- "{1} m east   {2} m north   {3} m up"
ui.text(28, 86, trn("keys", count))              -- picks keys.one / keys.other (/ .few / .many) by the language's rules; {1} is the count
prompt = tr("switch_lanterns")
lang()                                           -- "de"
has_text("key")                                  -- is there a text for it
```

## The files
```
# comment
title,Lantern Cove
position,{1} m east   {2} m north   {3} m up
keys.one,{1} key
keys.other,{1} keys
note,"a text in quotes can hold a comma, a ""quote""
and a second line"
tab,column\tcolumn\nnew line        -- \n \t \\ are escapes
```
- `{1}` .. `{9}` are the arguments (numbers become text the way Lua prints them), `{}` takes them in order, `{{` and `}}` are braces. A missing argument shows as `?`.
- Keys: up to 96 characters, no spaces. Later lines win, so a file can override its own earlier lines (and packs rely on it: see below).
- Plural categories follow the language: English and most European languages `one` / `other`; French and Portuguese count 0 as `one`; Russian, Ukrainian `one` / `few` / `many`; Polish; Czech and Slovak; Arabic (`zero` .. `many`); Japanese, Chinese, Korean `other` only. A form that is missing falls back to `key.other`, then `key`.

## Choosing the language
`language = de` in the settings file, `--lang de`, or `--setting language=de`. A code is lower case letters, digits and `-` (`pt-br`; case and `_` are forgiven). The lookup tries the language, its base language (`pt-br` -> `pt`) and then `en`; a key nobody has shows as itself (so a gap is visible, not blank) and is counted in `Localizer::missing()`. A language without a file is refused with the list of the ones that exist, and the game runs in English.

## Packs
`strings/<lang>.csv` of a pack and of the project are joined like `materials.csv`: the pack's lines first, the project's last. A mod can add its own keys or change the base game's wording in one language without touching the other files.

## Checking
`voxelith --check-project dir` lists the languages, warns about keys `en.csv` has and another language lacks, about lines it cannot read, and about `tr("literal")` keys of the level script that `en.csv` does not have.

## Limits
- It is **presentation only**: in a networked session each peer may read another language, so the simulation must not branch on a text (its length, its content). Prompts, HUD and messages are fine.
- Text is UTF-8, drawn with the UI's font, which has Latin letters with accents (Latin-1: German, French, Spanish, Portuguese, Italian, Nordic); other scripts need a font that is not built in.
- The engine's own tool panels and logs stay in English.
- No right-to-left layout, no number or date formatting by locale (format numbers in the script).
