# kitsune-mantra

The companion to the Kitsune lock face. It runs in your session
and sets the mantra gate's standing choices — the gate itself,
your order of the seven folds, the attempt limit, and the stored
key — so nobody has to edit a config file by hand.

    qs -p ~/.local/share/qylock/themes/kitsune/companion/run

(From a git checkout, ./kitsune-mantra in this directory does
the same.)

Speak your order by tapping the cards or typing their numbers;
both are the same act, as at the door. The window prints its own
keyboard map. "Try your mantra" deals a practice fan, shuffled
like the door's, and tells you whether she would open.

Sealing writes the theme's theme.conf through a small writer
(mantraconf.py). Your password crosses to it on standard input
only — never an argument, never shown back — and the file lands
at mode 600. What that means, plainly: the stored key is your
password in plain text inside a private file. The lock's README
says the same. Leave the key empty and the gate simply opens
onto the password field; no setup is ever required to log in.
