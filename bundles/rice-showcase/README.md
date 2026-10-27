# Rice Showcase

A small kit of terminal toys and visual tools that make a desktop rice easier to
show off: Matrix rain, bonsai, audio visualizers, system readouts, ASCII banners,
and a few classic terminal animations. Install it from **Settings, Extras, Rice
Showcase, Install all**.

## Tools

| Tool | What it is | Arch / CachyOS |
| --- | --- | --- |
| cmatrix | Matrix-style terminal rain. | pacman |
| cbonsai | Animated terminal bonsai tree. | AUR |
| cava | Terminal audio visualizer. | pacman |
| fastfetch | System info readout for screenshots. | pacman |
| btop | Polished terminal resource monitor. | pacman |
| figlet / toilet | ASCII banner text. | pacman |
| lolcat | Rainbow text coloring for terminal pipes. | pacman |
| cowsay | Classic speech-bubble terminal toy. | pacman |
| sl | Steam locomotive terminal animation. | pacman |
| pipes.sh | Animated terminal pipes screensaver. | AUR |
| tty-clock | Large terminal clock. | AUR |
| asciiquarium | Animated ASCII aquarium. | pacman |

## On Fedora and Void

The last column is where a tool comes from on Arch and CachyOS. On Fedora and
Void, Ryoku installs each tool from that edition's own repositories, under its
own package name. A tool an edition does not package stays listed in the store,
greyed out with the reason: pipes.sh is not packaged for Fedora or Void (Void's
pipes.c package has the same screensaver as the `cpipes` command), and
tty-clock is not packaged for Fedora.

## Notes

- Every tool above is part of **Install all**, so **Install all** and **Repair**
  bring the whole kit in one go. Tools an edition does not package are skipped
  with their reason instead of blocking the rest.
- This is meant as a showcase/helper bundle, not a required part of any rice.
