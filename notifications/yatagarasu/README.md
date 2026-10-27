# Yatagarasu

> **Part of [Jurai](https://github.com/SourceAura/jurai-suite)** — a living desktop ecosystem by 0xSrcAura. This piece is one of its public doors.

The Kasugai scroll, seated as a Ryoku notification card.

Every notification arrives as a dispatch scroll, and the scroll
unrolls as it lands: a dark glass plate, the sender's seal, the
message set in mono — and the crow herself perched at the foot
of the card, standing on the burn line. Her eye wears the
scroll's own priority. The arrival stamp and the crow share one
line at the foot.

The frame is a prism ribbon along the foot and the right edge.
It bends around the corners at the card's own radius, tapers
into the left and top edges, and its colours travel slowly
around it. The burn line rides over the ribbon's foot: the
scroll's remaining life, spent while it waits, its spend point
glowing and flaring softly once before the end — and as the
burn recedes, the prism shows through behind it.

Priorities wear the Form Eighty colours: LOW cyan, MEDIUM
emerald, HIGH amber, CRITICAL rose. Freedesktop urgency maps
low/normal/critical to LOW/MEDIUM/CRITICAL. A critical scroll
does not burn. It waits, ember-lit, with ACK REQUIRED standing
in its stamp row, and every couple of seconds it shivers — a
small shake, so a waiting critical is hard to ignore — until
the x is pressed.

A picture sent with the notification is framed in the scroll,
honouring the user's show-images choice; a long message folds
at three lines and unfolds in place on request. The card
mirrors itself for the left column and composes the same face
for right, bottom-right and centre seats — placement is the
shell's choice, and the card follows it. It draws its measures
from the shell's Tokens, its tempo from Motion, and stands
still for reduced-motion users: no unroll travel, no drifting
prism, no shiver. The arrival stamp is the user's own time
format.

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

## The crow came home

The crow used to perch on the desktop as a separate piece, the
Yatagarasu Roost. She lives in the card now, and the Roost is
retired. Yatagarasu is one package, listed in Notifications
only. The roost/ folder stays in this repo for reference.

Part of the Jurai suite, by 0xSrcAura. Maintained by the
author; updates ship as version bumps here and in the store.

License: GPL-3.0-or-later.
