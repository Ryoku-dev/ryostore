# Submitting to Ryostore

Thanks for building for Ryoku. This is the one page that gets your work into the
store. It is short on purpose; the deep details live in each catalogue's own
authoring guide, linked below.

**Before you submit, build it and test it live.** The
[DEVELOP.md](DEVELOP.md) guide shows you how to point your running desktop at
your local copy and watch it work. Do that first; it catches almost everything.

## You maintain what you submit

Community items and plugins are **not maintained by the Ryoku team**. You are
responsible for returning to update your submission when Ryoku's shell, APIs,
paths, dependencies, or security requirements change. Keep a reachable author or
upstream contact, investigate reports, bump the product version, regenerate its
manifest, and submit fixes. If you cannot maintain an item, tell us so it can be
retired instead of silently breaking users' desktops.

Store review and automated checks are screening, not security certification.
Users still need to inspect the code they install. Explain what your item runs,
reads, writes, and contacts; do not describe a green check as proof that it is
safe. Follow [SECURITY.md](SECURITY.md) before submitting or updating executable
content.

## The shape of a submission

Ryostore is a catalogue repo. Every item is:

1. **A folder** under its catalogue (for example `plugins/my-plugin/` or
   `rices/my-rice/`), with a manifest and a preview image.
2. **One entry** in that catalogue's `registry.json`. The desktop only shows
   items that are listed there.

Pick your catalogue and follow its authoring guide for the folder layout and
manifest fields:

| You are adding | Start from | Full guide |
| --- | --- | --- |
| A shell plugin (desktop, popout, or QS Bar widget) | `plugins/template/` | [`plugins/AUTHORING.md`](plugins/AUTHORING.md) |
| A rice (whole-desktop look) | Save current setup in Settings | [`rices/AUTHORING.md`](rices/AUTHORING.md) |
| A colour scheme | `colorschemes/template/` | [`colorschemes/AUTHORING.md`](colorschemes/AUTHORING.md) |
| A bundle (tool set) | `bundles/the-ricer/` | [`bundles/README.md`](bundles/README.md) |
| A Nautilus script pack | `nautilus/video-reformat/` | [`nautilus/AUTHORING.md`](nautilus/AUTHORING.md) |
| A live wallpaper | an existing `livewalls/<id>/` | [`livewalls/README.md`](livewalls/README.md) |
| A fastfetch preset (terminal readout) | `fastfetch/ryoku-dossier/` | [`fastfetch/AUTHORING.md`](fastfetch/AUTHORING.md) |
| A Ryotunes skin (palette, type, radii, motion) | `ryotunes-skins/template/` | [`ryotunes-skins/AUTHORING.md`](ryotunes-skins/AUTHORING.md) |
| A lockscreen, bar style, launcher image, decor | an existing item in that catalogue | copy the layout of a neighbour |

A colour scheme is the simplest: add `colorschemes/<name>/` following an existing
scheme's layout, then add its entry to `colorschemes/registry.json`.

Built a plugin in your own shell? `ryoku plugin export <id>` writes a ready folder
and `registry-entry.json`, and `ryoku plugin share <id>` opens the pull request for
you (with `gh` logged in) or prefills the submission form. Doing it by hand instead,
regenerate the plugin's manifest and hash with `tools/pack-product.py plugins/<id>`.

## Two ways to submit

### 1. Open a pull request (preferred)

If you are comfortable with git, this is the fastest path and the one that
scales:

1. Fork this repo and add your item folder plus its `registry.json` entry.
2. Run the check from the repo root:

   ```sh
   tests/validate-catalogue.sh
   ```

   It confirms every item resolves to a real folder, manifest, and installer,
   and that all JSON parses. CI runs the same check, so a green local run means
   a green PR.
3. Open the pull request. The [PR template](.github/PULL_REQUEST_TEMPLATE.md)
   walks you through the checklist.

### 2. Fill in the submission form

Not set up for a pull request, or want a maintainer to help land it? Open the
[**submission form**](https://github.com/neur0map/ryostore/issues/new?template=submit-item.yml).
Tell us the kind, a short description, where the content lives (a repo, gist, or
zip), and a preview image. A maintainer reviews it and opens the pull request
with you.

## What every submission needs

- A **preview image** that is a real screenshot, not a placeholder.
- A **licence** you can honour: your own work, CC0, or content explicitly
  licensed for redistribution. Say so in the item's README or manifest.
- A **`registry.json` entry** with the fields your catalogue's guide lists,
  `lastUpdated` in `YYYY-MM-DD`, and (for community work) `official: false`.
- **Catalogue integrity and security screening passing**, with every finding
  resolved or explicitly reviewed under the security policy.
- A clear **maintenance contact** and acknowledgement that ongoing maintenance
  belongs to the contributor, not the Ryoku team.

That is the whole contract. When in doubt, copy the closest existing item and
change one thing at a time.
