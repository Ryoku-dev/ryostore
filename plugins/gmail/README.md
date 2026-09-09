# Gmail Plugin for Ryoku

Native industrial noir Gmail client and notification reader plugin for the [Ryoku](https://github.com/ryoku-dev/ryoku-arch) desktop shell.

## Features

- **Ryoku Industrial Design:** Styled to match the Ryoku design language with hairline borders, Japanese typography markers, and live Matugen color scheme integration.
- **OAuth 2.0 PKCE:** Direct loopback authorization on `http://127.0.0.1:42069/callback` with an anti-CSRF `state` token. Tokens and API keys are stored strictly locally under the plugin state dir (`~/.local/state/ryoku/plugins/gmail/`, files `chmod 0600`) with zero telemetry or cloud relays.
- **Custom Geometry:** Configurable popup width (480px–960px) and height (440px–720px) directly from Ryoku Settings.
- **Full Mailbox Management:** Browse Inbox, Sent, Spam, and Trash with real-time search, read threads, view HTML/plain text, and compose/send emails.

---

## Google Cloud OAuth Setup Guide

To connect your Gmail account, you will need a free Google Cloud OAuth Client ID and Client Secret:

### 1. Create a Google Cloud Project
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Click the **Select a project** dropdown at the top of the page.
3. Click **New Project**, give it a name (e.g. `Ryoku Mail`), and click **Create**.

### 2. Enable the Gmail API
1. In the left panel, select **APIs & Services** → **Library**.
2. Search for **Gmail API** and click **Enable**.

### 3. Start OAuth Consent Screen Setup
1. On the same Gmail API screen, click **Credentials** (in the center of the page, not the left panel).
2. Click **Create Credentials** → **OAuth client ID**.
3. Click **Configure consent screen** > **Get started**.

### 4. Fill App Information & Create
1. Fill in the required fields: **App name** (e.g. `Ryoku Mail`), **User support email**, and **Developer contact information**.
2. Click **Save and Continue**, agree to the policy, and click **Create**.

### 5. Create Desktop App Credentials
1. Return to the main dashboard and select **Gmail API** > **Manage** > **Credentials** (center page, not left panel).
2. Click **Create Credentials** > **OAuth client ID**.
3. Choose **Desktop App** type from the dropdown, enter a name for your client, and click **Create**.

### 6. Save Your Keys Below
1. A popup will appear displaying your **Client ID** and **Client Secret**.
2. Copy and paste them into the input fields in the Ryoku Gmail plugin, then click **Save Credentials & Continue**.

### 7. Authorize & Grant Permissions in Browser
1. Click **Connect with Google**.
2. The setup screen will open in your default browser. Select your Gmail account.
3. When Google displays a warning (**"Google hasn't verified this app"**):
   - Click **Show advanced**
   - Click **Go to [Your Project Name] (unsafe)**
   - Check all requested Gmail permissions and click **Continue** to complete setup!

---

## Permissions & data handling

- **Writes** only under the plugin state dir `~/.local/state/ryoku/plugins/gmail/`
  (`$XDG_STATE_HOME/ryoku/plugins/gmail/`): `gmail.env` (OAuth client id/secret,
  `chmod 0600`) and `accounts.json` (per-account refresh tokens, `chmod 0600`).
  Downloaded attachments are saved to `~/Downloads` (or a folder you pick) on an
  explicit download click; calendar `.ics` files are staged in a temp dir.
- **Secrets** (OAuth tokens, client id/secret, account lists) are passed to the
  helper scripts through the process environment or stdin, never as command-line
  arguments, so they do not appear in process listings.
- **Network** hosts contacted (declared in `manifest.json` `capabilities.network`):
  `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com`,
  `gmail.googleapis.com`. Nothing else is contacted.
- **Commands**: the plugin ships its own Python helpers under `bin/` and shells
  out to `python3` and `xdg-open` (to open the consent screen). `khal` is
  optional and used only by **Add to Calendar** to import an `.ics` event;
  without it, mail features are unaffected.

## Maintenance & support

This is a community plugin. It is maintained by its contributor, not the Ryoku
team; updates and fixes are the contributor's responsibility. Ryostore provides
robust screening of submissions, but that is not a guarantee of correctness or
safety — you are responsible for reviewing the code you install and the Google
Cloud credentials you provide.

---

## License

This plugin is a composite work distributed as a whole under the **GNU GPL v3.0**
(`SPDX: GPL-3.0-only AND MIT`).

- Its QML UI widgets are derived from the GPL-3.0 [illogical-impulse](https://github.com/end-4/dots-hyprland)
  Quickshell config and are styled for the GPL-3.0 [Ryoku](https://github.com/ryoku-dev/ryoku-arch) shell.
- The Gmail-specific code (the `bin/` Python helpers and the `Email*` views) is
  © 2026 Yash Parmar (Zatch07) and is additionally offered under the MIT License.

See [LICENSE](LICENSE) (GPL-3.0), [NOTICE](NOTICE) (upstream attribution + the MIT
notice), and [PROVENANCE.md](PROVENANCE.md) for the full determination.
