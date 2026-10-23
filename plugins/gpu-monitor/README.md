# GPU Monitor

A Ryoku bar plugin (`gpu-monitor`): a GPU usage glyph on the bar and a panel
modelled on the Ryoku CPU panel. Works without root on Intel, AMD and NVIDIA.

## Supported GPUs

| Driver | Usage from | Status |
| ------ | ---------- | ------ |
| `i915` (Intel) | per-process engine time in DRM fdinfo; RC6 residency as fallback | tested |
| `xe` (newer Intel) | fdinfo engine cycles | experimental |
| `amdgpu` (AMD) | `gpu_busy_percent` | experimental |
| `nvidia` (proprietary) | `nvidia-smi` | experimental |

With several GPUs, `auto` prefers NVIDIA, then an AMD card with more than 2 GB of
VRAM (a discrete card), then the integrated GPU. Set **GPU** to a card name
(`card1`), PCI slot or driver to choose one.

## What it shows

Bar: a glyph and the GPU's usage %. Panel: name, usage bar and 60-sample history,
clock (current / maximum), requested clock and render/media split (Intel),
frequency range, VRAM (AMD, NVIDIA), GPU temperature (AMD, NVIDIA) or CPU package
temperature (Intel), throttling reasons (Intel), the top three processes by GPU
use, and an Open btop button. Rows a GPU doesn't report are hidden.

## What runs and what it reads

| What | When | Reads |
| ---- | ---- | ----- |
| `bin/gpu-stat.sh <gpu> [top]` | every 2 s, every 1 s with the panel open | `/sys/class/drm/card*` (driver, clocks, RC6, throttle, AMD busy/VRAM), `/sys/class/hwmon/*` (temperatures), `/proc/*/fdinfo/*` DRM entries of your own processes (Intel always, AMD only with the panel open), `/proc/<pid>/comm` |
| `nvidia-smi --query-gpu=…`, and `nvidia-smi pmon -c 1` with the panel open | NVIDIA only, from the script | the NVIDIA driver |
| `lspci -vmm -s <slot>` | once per GPU | GPU name |
| `<terminal> -e btop` | on click | — |

The plugin writes nothing.

## Settings

| key      | type | default | description |
| -------- | ---- | ------- | ----------- |
| gpu      | text | auto    | Which GPU to show: `auto`, a card (`card1`), PCI slot or driver |
| terminal | text | kitty   | Terminal used to open btop, run as `<terminal> -e btop` |

## Preview

Capture the widget as `assets/preview-widget.png` and list it under `files` in
`manifest.json`.
