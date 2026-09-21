# Kotoba

Japanese flashcards on the wallpaper, on a real spaced-repetition schedule.

A card sits on the desktop. You read it, reveal the answer, and grade yourself
Again / Hard / Good / Easy. FSRS decides when that card comes back — hours for
something you just fumbled, months for something you know cold. Restrict it to
the scripts you can currently read and it only ever shows you those.

## What it does

- **Four card types.** Meaning (猫 → cat), reading (猫 → ねこ), recall
  (cat → 猫) and kana drill (ツ → tsu). Each is scheduled independently, so a
  word can be solid in one direction and shaky in another.
- **Script filters.** Hiragana, katakana and kanji toggle separately.
- **Furigana and romaji** both toggle. Furigana is suppressed on the front of a
  reading card, because there it would be the answer.
- **Your own words.** Point it at a folder of deck files and it picks them up.

## Card types are earned, not assumed

A word only gets the cards that make sense for it:

| | when |
|---|---|
| kana drill | a single kana character — **and nothing else** |
| meaning | every other word |
| recall | every other word |
| reading | only when the written form differs from its kana |

So 猫 gets meaning, recall and reading. たぶん gets meaning and recall — there
is no reading to test. ツ gets a kana drill and nothing more: a kana
character's meaning *is* its sound, so a "meaning" card would ask the identical
question.

### You will never see the same word twice in a row

A word's cards are **buried** once you answer one of them: the others wait
until the next day. So 図書館 might ask its meaning today and its reading
tomorrow, but never both in one sitting.

Scheduled intervals also carry a little randomness, so two cards answered in
the same moment do not come due in the same moment forever after.

## Adding your own words

Copy `data/decks/TEMPLATE.json` into a folder, rename it, and set that folder
in **Ryoku Hub → Addons → Kotoba → Decks**. The file is read on every shell
start; `TEMPLATE.json` itself is always skipped.

> The deck folder is **not** in the tile's right-click menu. The wallpaper layer
> deliberately hides text fields (there is no keyboard on it by default), so any
> setting you type lives in the Hub. The right-click menu carries the toggles,
> choices and sliders.

```json
{
  "$schema": "kotoba-deck-1",
  "id": "my-words",
  "name": "Words I met in the wild",
  "license": "CC0-1.0",
  "cards": [
    { "jp": "猫", "kana": "ねこ", "en": "cat" },
    { "kana": "たぶん", "en": "probably" }
  ]
}
```

Only `kana` and `en` are required. Leave out `jp` and the word *is* the kana.
`romaji` is derived from the kana automatically — write it only to override an
irregular reading. The template file documents every field.

Your review history is keyed to the deck `id`. Renaming a deck's `id` starts it
over as a new deck; the old history is kept, not deleted.

## The dictionary (optional, off by default)

Kotoba ships with 2132 words and works fully offline. Switching on
**Dictionary → Allow downloading a dictionary** in Ryoku Hub reveals an
*install dictionary* button on the tile. Tapping it downloads one pack from
`ftp.edrdg.org` and imports it once:

| Pack | Download | What it adds |
|---|---|---|
| Words + kanji | ~12 MB | 218k entries, lookup, all four deck axes |
| Adds example sentences | ~21 MB | the above plus the Tanaka example corpus |

**After that one download everything is offline again.** Lookup never touches
the network: it queries the imported copy. There are no per-word requests, no
API keys, no rate limits, and nothing is ever uploaded.

The dictionary is stored separately from your review history
(`dict.db` beside `kotoba.db`), so re-importing it can never endanger your
scheduling.

### Looking a word up

With a dictionary installed, a **+** appears in the tile's header. Tap it, type
a word in kanji or kana, press Enter, then *save to deck* to add it to
`kotoba-saved.json` in your deck folder.

> **If the desktop ever stops accepting keystrokes**, the lookup field has kept
> the wallpaper layer's keyboard grab. It self-releases after 45 seconds idle.
> To force it: `systemctl --user restart ryoku-shell`. Closing the field with
> Escape, Enter, or a click outside always releases it.

## What it runs, reads and writes

- **Runs** `bin/kotoba`, a single Python 3 script shipped with the plugin, and
  `notify-send` when notifications are switched on. Both are invoked with
  argument arrays, never through a shell.
- **Reads** its own `data/decks/`, and the deck folder you name in settings.
  Nothing else.
- **Writes** `kotoba.db` and `dict.db` under
  `$XDG_STATE_HOME/ryoku/plugins/kotoba/`, and downloads are cached under
  `$XDG_CACHE_HOME/ryoku/plugins/kotoba/`. The single exception is
  `kotoba-saved.json`, written into the deck folder you nominate, and only when
  you save a looked-up word. It is written atomically and Kotoba never edits any
  other file in that folder.
- **Network: one host, opt-in, download only.** Nothing is fetched unless you
  switch on *Allow downloading a dictionary* and then tap *install dictionary*.
  The only host contacted is `ftp.edrdg.org`, for the dictionary files named
  above. Nothing is ever uploaded, and no telemetry of any kind is sent.
- **No privileged commands.** Nothing is escalated; `pkexec` is not used.

## Settings

Right-click the tile.

Toggles, choices and sliders appear in the tile's right-click menu. The deck
folder is a text field, so it appears in **Ryoku Hub → Addons → Kotoba**.

| Group | What | Where |
|---|---|---|
| Timing | Minutes between cards (strict pacing); advance straight to the next after grading | right-click |
| Scripts | Hiragana / katakana / kanji | right-click |
| Card types | Meaning, reading, recall, kana drill | right-click |
| Display | Romaji, furigana, intervals, notifications, card text size | right-click |
| Decks | Your deck folder | **Hub** |

Turning romaji off also drops kana drills from rotation: a kana drill's answer
*is* romaji, so it would be unanswerable.

**Use the card text size slider, not the tile's resize bracket**, to make the
Japanese bigger. The resize bracket scales the rendered tile and softens the
glyphs; the slider grows the type at native resolution.

## The interval is a promise

**Timing → Minutes** is strict pacing. Set it to 60 and Kotoba will not put a
card in front of you more than once an hour, even when the scheduler says one
came due sooner. It is a rate limit on interruption, not a polling hint.

That means the tile shows two different countdowns, and they mean different
things:

| Shown | Means |
|---|---|
| `17 cards due · next card in 59m` | 17 are ready; your interval decides when one appears |
| `All caught up · Next review in 5m` | nothing is ready; the scheduler's next card is 5 minutes out |

The tile says **All caught up** only when that is actually true. When cards are
waiting it says so, and offers **review now** — one tap pulls a card
immediately and the interval restarts from that moment. So a long interval
costs you nothing: it governs what arrives unprompted, and tapping governs what
you ask for.

## Undo

Misgraded something? A small **↶ 猫 · Easy** chip appears above the footer.
Tapping it puts the card back exactly as it was — the same due date, stability,
difficulty and repetition count — and removes the review from your history.

It also un-buries the word's other cards, so undoing an answer genuinely
rewinds rather than half-rewinding.

Only the most recent answer can be undone, and only answers given since this
feature arrived: older reviews never recorded the state they were in
beforehand, so there is nothing to restore them to.

## Notifications

**Display → Notify on new cards** (off by default) posts a desktop toast each
time a new card comes up.

The toast deliberately carries **no Japanese** — it says a word is ready and
how many are due, nothing more. A toast that showed the word and its meaning
would answer the card before you had a chance to.

Each toast replaces the previous one rather than stacking, so a one-minute
interval leaves a single Kotoba entry in your notification history instead of
sixty an hour.

Notifications go through `notify-send`. On Ryoku, Quickshell is itself the
notification daemon, so they render as native shell notifications and respect
do-not-disturb without Kotoba having to know about it.

## Reading the buttons

Each grade button shows what it will actually do to the card in front of you —
`Good 10m` means you will see it again in ten minutes, `Easy 16d` in sixteen
days. Those numbers come from the scheduler itself, not a lookup table, so they
are always true for that specific card. Turn them off with **Display → Show
intervals on buttons**.

Grade honestly. The scheduler works by finding the edge of what you know, so
marking things Easy that you actually fumbled makes it worse at its job, not
kinder.

## Attribution

The core vocabulary deck is derived from **JMdict** and **KANJIDIC2**,
published by the **EDRDG** under CC BY-SA 4.0, and that credit is shown on the
tile. Scheduling uses the **FSRS** memory model (MIT). See `NOTICE` for the
full terms and `PROVENANCE.md` for the licensing determination.

The plugin code is MIT. The derived dictionary deck is CC BY-SA 4.0.
