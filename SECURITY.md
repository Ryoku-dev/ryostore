# Security and maintenance

## Trust model

Ryostore is a distribution catalogue, not an application sandbox. Plugins and bar
styles execute inside a user's desktop process with that user's permissions.
Installer scripts, shell commands, Python helpers, and Fastfetch command modules
can also execute code. A file hash verifies integrity against a manifest; it does
not establish that the code is trustworthy. A valid manifest is not a security
review.

**Community submissions and plugins are maintained by their contributors, not by
the Ryoku team.** Contributors are responsible for compatibility, dependency
updates, bug fixes, security fixes, and responding to reports. When Ryoku changes,
a contributor must return to update their tool. Helping with a merge does not
transfer maintenance responsibility. We may remove a listing that is unsafe,
incompatible, abandoned, or no longer has a reachable maintainer.

**Users remain responsible for inspecting code and updates before installation.**
Check the author's identity, upstream, licence, commands, network destinations,
file access, and authorization prompts. Disable or remove an item you no longer
trust. Store presence, a green check, and a previous review are not guarantees.

Automated screening and maintainer review are defensive filters intended to
reduce exposure. They can miss vulnerabilities, malicious behavior, obfuscation,
transitive dependencies, runtime-loaded content, and future upstream changes.
Screening is not certification, a comprehensive audit, or proof of safety.

## Secure contribution rules

- **Minimize authority.** Use current, documented shell APIs instead of reaching
  into shell internals, copying service daemons, or editing user shell files. A
  plugin may only import the public PluginKit, Qt/Quickshell, and its own files.
- **Declare behavior.** List every external command and network host in the
  plugin manifest; document reads, writes, dependencies, and any privilege
  request in the README. A declaration is disclosure, not permission to do
  arbitrary work.
- **Treat settings and external data as untrusted.** Pass command arguments as
  arrays. Never concatenate settings, email text, filenames, device names,
  clipboard data, or command output into shell programs. Avoid `eval`, dynamic
  code generation, and shell interpreters for data processing.
- **Never download and execute code.** No curl-to-shell pipelines, remote QML/JS
  imports, hidden self-updaters, or install-time execution of unreviewed scripts.
  Package dependencies belong in the supported package-manager path with explicit
  user authorization, not an in-process plugin download routine.
- **Keep privilege explicit.** No `sudo`, `doas`, or `su` in plugins. An approved
  privileged operation must use the existing authorization boundary, have an
  exact manifest declaration, and occur only after a deliberate user action.
- **Constrain storage.** Plugins write only to their own state/cache directory or
  temporary files. Do not modify another plugin, a receipt-owned install tree,
  shell startup files, SSH configuration, system paths, or shell configuration
  directly. Validate archive members and destinations, reject path traversal and
  symlinks, and create files atomically without following attacker-controlled
  links. Do not overwrite existing user files without consent.
- **Protect credentials.** Never commit secrets, tokens, private keys, cookies,
  or populated environment files. Do not log them. Store runtime secrets with
  restrictive permissions; protect the parent directory as well as the file.
  OAuth flows need unpredictable state, PKCE where applicable, a loopback-only
  local callback, bounded lifetime, and clear cancellation/error handling.
- **Treat remote content as data.** Validate schemes and hosts before opening
  links. Sanitize attachment names and HTML, do not run embedded scripts, and
  ensure rendering email or notifications cannot silently execute commands.
- **Bound work and clean up.** Limit requests, input sizes, retries, and process
  lifetimes. Stop work when unloaded, avoid global process killing, and report
  failures rather than pretending an unavailable dependency succeeded.
- **Ship inspectable source.** No compiled executable payloads, disguised binaries,
  submodules, or symlinks in store products. Include licences and upstream
  attribution. Keep previews genuine and capability claims accurate.
- **Maintain the release contract.** Update all affected callers and docs, bump
  versions when behavior changes, regenerate per-file manifests, and exercise
  the supported shell version before submitting. Never weaken a scanner or add
  broad exclusions just to make a contribution pass.

## Local checks

From a **reviewed checkout**, install the opt-in hooks:

```sh
bash tools/install-hooks.sh
```

The installer snapshots the hooks, scanner, and exception policy into the Git
common directory, outside the checked-out tree. Switching to a contribution
branch cannot replace that installed scanner. Re-run the installer deliberately
after reviewing updates to the security tools or policy. It refuses to overwrite
an unrelated `core.hooksPath`.

- **Pre-commit** screens the entire staged index, not unstaged working files.
- **Pre-push** screens the exact tip of every non-deleted ref being pushed,
  including new branches and force updates, not merely the current `HEAD`.
- Missing tools, scanner errors, and blocking findings stop the operation.
  Hooks remain bypassable local safeguards; they do not replace server checks.

Run the scanner manually against a working tree or a specific revision:

```sh
python3 tools/security-screen.py --root . --format text
python3 tools/security-screen.py --root . --revision HEAD --format json
python3 -m pytest tests/test_security_screen.py tests/test_gmail_security.py -q
```

The scanner checks executable magic, secrets, unsafe paths/imports, dangerous
execution patterns, sensitive configuration writes, manifest declarations, and
policy integrity. It reads Git blobs without running contribution hooks, filters,
scripts, QML, or Python. Blocking findings return exit 1; infrastructure errors
return exit 2. Advisory findings still require human review. Pattern matching
cannot fully understand shell substitutions, aliases, or runtime behavior.

## GitHub checks and exceptions

`pr-security-screen` runs from the **trusted base branch** using
`pull_request_target`, with read-only repository permissions and no referenced
secrets. The candidate revision is only data: it cannot provide the workflow,
scanner, validator, configuration, or exception policy used to approve itself.
The job rejects unsafe payloads before exporting the exact tree; contribution
archive attributes cannot hide or rewrite files.

The merge gate includes the static security screen, trusted catalogue-integrity
validation, and redacted Gitleaks scanning of introduced commit history, including
merge-resolution changes. Bandit and ShellCheck report additional advisory
findings. Actions are pinned by commit; downloaded binary scanners are pinned by
version and verified SHA-256. Bandit is version-pinned, not a fully hash-locked
transitive dependency set. Download/install failures fail closed. These tools
also have limitations: for example, inline ShellCheck suppression comments
cannot be overridden by its CLI.

After merge, `catalogue` runs the repository's trusted validators on `main`.
Repository protection should require the PR screen and code-owner review for
security-sensitive files. `CODEOWNERS` identifies those files; it does not enforce
review by itself. Dependabot proposes GitHub Action and Python-tool updates;
binary scanner pins require deliberate maintainer updates.

`security/exceptions.json` starts empty. Only maintainers may approve an
exception, and a contribution cannot authorize its own exception. Every entry
must specify an exact rule, exact relative path, full-file SHA-256, a specific
review reason, and an expiry date. Globs, stale hashes, malformed entries, expired
exceptions, and unused exceptions cannot silently weaken the gate. Review the
actual file and behavior before updating an exception; never generate a blanket
baseline from scanner output.

## Review and reporting

A maintainer reviews findings and executable changes before listing a submission.
Security-policy, hook, workflow, and scanner changes require particular care:
untrusted contribution code must not be allowed to supply the tools or policy
that approve that same contribution. Local hooks are opt-in safeguards and can
be bypassed; server-side checks and review are the merge boundary.

For a vulnerability, use this repository's **Security → Report a vulnerability**
private reporting form. Include the affected item/version, impact, and a minimal
reproduction without real credentials. Do not post secrets or a live exploit
against another user's system in a public issue. Report ordinary compatibility
bugs to the contributor through the item's documented upstream/contact.

If a credential was exposed, revoke or rotate it immediately. Deleting it from
the latest version does not remove it from Git history, logs, forks, or caches.
A maintainer may withdraw a listing while the contributor prepares a fix.
