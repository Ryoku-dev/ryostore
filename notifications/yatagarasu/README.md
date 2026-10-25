# Yatagarasu

The Kasugai scroll, seated as a Ryoku notification card.

Every notification arrives as a dispatch scroll: a dark glass
plate with a lit priority edge, the sender's seal, the message
set in mono, and a burn line along the foot that spends the
scroll's remaining life while it waits — its spend point
glowing, and flaring softly once before the end.

Priorities wear the Form Eighty colours: LOW cyan, MEDIUM
emerald, HIGH amber, CRITICAL rose. Freedesktop urgency maps
low/normal/critical to LOW/MEDIUM/CRITICAL. A critical scroll
does not burn. It waits, ember-lit, with ACK REQUIRED standing
in its meta row, until the x is pressed.

A picture sent with the notification is framed in the scroll,
honouring the user's show-images choice; a long message folds
at three lines and unfolds in place on request. The card
mirrors itself for the left column and crowns itself for the
centre, draws its measures from the shell's Tokens, its tempo
from Motion, and stands still for reduced-motion users. The
arrival stamp is the user's own time format.

## The suite dialect

Freedesktop urgency has three rungs; the triad has four.
A sender may set the hint `x-jurai-priority` to LOW, MEDIUM,
HIGH or CRITICAL and the scroll obeys it:

    notify-send -h string:x-jurai-priority:HIGH "Title" "Body"

Pair a hinted CRITICAL with expire-timeout 0 so the scroll
truly waits for acknowledgment.

Actions the sender offered appear as a quiet row of chips.
Clicking the plate runs the sender's default action. The x
only ever dismisses.


Her other half lives in the store as **Yatagarasu Roost** (plugins): the crow herself
on the desktop, her eye wearing the last word. The scrolls are her voice; the roost is her.

Part of the Jurai suite, by 0xSrcAura. Maintained by the
author; updates ship as version bumps here and in the store.

License: GPL-3.0-or-later.
