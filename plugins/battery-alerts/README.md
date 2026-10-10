# Battery Alerts

Low-battery desktop notifications for Ryoku. The existing battery indicator stays in place; the battery-alert bar mark opens alert status and a test button.

Warnings default to **25%** and critical alerts to **10%**. Change both with the **− / + controls directly in the bar panel**, or in **QS Bar Settings → Community → Battery Alerts**. Critical is constrained below the warning threshold. Pause/resume and send a test from the bar panel.

Alerts fire once per level per discharge session, including when enabled or loaded below a threshold. Plugging into AC rearms them. A jump directly below critical emits only the critical alert. Small percentage fluctuations do not repeat alerts. One shared monitor prevents duplicates on multiple displays in the same shell. Restarting the shell starts a new monitoring session.

Notifications use the desktop notification service and remain in its history. **Ryoku Do Not Disturb suppresses popups, including critical ones**; turn it off to see warnings. Use **Test notification** to confirm delivery. A warning cannot guarantee protection from an abrupt power loss or an inaccurate battery gauge. This plugin never shuts down or suspends the machine.

## Permissions

Reads laptop battery presence, percentage, discharge state, and AC status through Quickshell's UPower API. Runs only `notify-send` with an argument array. No network, elevated privileges, scripts, or disk writes. Settings are saved by the host through the public plugin API. No polling subprocesses: event-driven battery updates with a 30-second notification retry timer while discharging.

## Development and validation

`node tests/policy.test.cjs` exercises the exact alert policy loaded by the live service. Validate with `ryoku plugin validate .`, install through `ryoku plugin add . --bar --yes`, then open the panel and test a notification. The preview is a real live capture.

MIT licensed. Community maintained by rayyan; issues/contact: https://github.com/Sipper1236. Ryoku does not maintain this plugin.
