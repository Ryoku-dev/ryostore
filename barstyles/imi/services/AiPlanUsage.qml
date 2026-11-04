pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../modules/common"
import shell.services as HostServices

/**
 * Normalized plan quotas for the AI clients the host tracks (Claude, Codex,
 * OpenCode). The host AiUsage service reads each tool's cache file and parses
 * its rate-limit windows; this singleton reshapes those into the provider/item
 * model the bar's quota widgets consume and keeps the presentation helpers.
 */
Singleton {
    id: root

    property var providers: root._buildProviders()
    property bool available: HostServices.AiUsage.available
    property bool refreshing: HostServices.AiUsage.refreshing
    property string errorMessage: root.available ? "" : Translation.tr("No AI plan usage is available.")
    property real lastUpdated: 0
    // Ephemeral by design: clicking the bar cycles the visible quota target
    // without turning that momentary choice into a persisted preference.
    property string activeTargetId: ""

    // The host has no sign-in flow to drive.
    property bool claudeSignInPending: false

    readonly property var _cfg: Config.options?.bar?.aiPlanUsage ?? null
    readonly property bool enabled: root._cfg?.enabled ?? true

    readonly property var displayProviders: {
        const result = [];
        for (const provider of root.providers) {
            const providerId = String(provider.id ?? "");
            result.push(Object.assign({}, provider, {
                providerId: providerId,
                targetId: providerId
            }));
        }
        return result;
    }

    readonly property var cycleProviderIds: {
        const enabledIds = root.enabledProviderIds();
        const enabledTargets = root.displayProviders.filter(provider => {
            return enabledIds.indexOf(String(provider.providerId ?? provider.id ?? "")) >= 0;
        });
        const ready = enabledTargets.filter(provider => provider.available === true);
        const targets = ready.length > 0 ? ready : enabledTargets;
        return targets.map(provider => String(provider.targetId ?? provider.id ?? ""));
    }

    readonly property string displayedProviderId: {
        const providerIds = root.cycleProviderIds;
        if (providerIds.length === 0)
            return "";
        return providerIds.indexOf(root.activeTargetId) >= 0
            ? root.activeTargetId
            : String(providerIds[0]);
    }

    readonly property var selectedItems: {
        const provider = root.displayProviderById(root.displayedProviderId);
        const selected = [];
        const seen = {};
        if (!provider)
            return selected;

        const providerItems = Array.from(provider.items ?? []);
        const kindOrder = ["balance", "short", "weekly", "daily", "monthly"];
        for (const kind of kindOrder) {
            let best = null;
            for (const item of providerItems) {
                if (String(item.windowKind ?? "") !== kind)
                    continue;
                if (!best || Number(item.remainingPercent) < Number(best.remainingPercent))
                    best = item;
            }
            if (best && !seen[String(best.id)]) {
                selected.push(Object.assign({available: true}, best));
                seen[String(best.id)] = true;
            }
            if (selected.length >= 2)
                break;
        }
        if (selected.length === 0) {
            selected.push(root.windowPlaceholder(provider, "short"));
            selected.push(root.windowPlaceholder(provider, "weekly"));
        }
        return selected.slice(0, 2);
    }

    // Host window epochs are seconds; the widgets compare against Date.now().
    function _resetAtMs(resetTs) {
        const ts = Number(resetTs) || 0;
        return ts > 0 && ts < 100000000000 ? ts * 1000 : ts;
    }

    function _buildProviders() {
        const result = [];
        for (const toolId of HostServices.AiUsage.toolIds) {
            const tool = HostServices.AiUsage.tool(toolId);
            const items = [];
            for (const window of (tool.windows ?? [])) {
                const minutes = Number(window.minutes) || 0;
                const pct = Math.max(0, Math.min(100, Number(window.pct) || 0));
                items.push({
                    id: toolId + ":" + (window.label ?? String(minutes)),
                    providerId: toolId,
                    providerName: root.providerName(toolId),
                    providerIcon: root.providerIcon(toolId),
                    groupId: "",
                    groupName: "",
                    windowKind: minutes === 10080 ? "weekly"
                        : minutes === 1440 ? "daily"
                        : minutes === 43200 ? "monthly"
                        : "short",
                    windowLabel: String(window.label ?? root.windowKindLabel(minutes)),
                    windowMinutes: minutes,
                    usedPercent: pct,
                    remainingPercent: 100 - pct,
                    resetsAt: root._resetAtMs(window.resetTs),
                    available: true,
                    metricKind: "quota"
                });
            }
            result.push({
                id: toolId,
                name: root.providerName(toolId),
                available: tool.has === true && items.length > 0,
                needsSignIn: false,
                error: "",
                items: items
            });
        }
        return result;
    }

    function windowKindLabel(minutes) {
        if (minutes === 10080) return Translation.tr("Weekly");
        if (minutes === 1440) return Translation.tr("Daily");
        if (minutes === 43200) return Translation.tr("Monthly");
        return Translation.tr("Short window");
    }

    // The config names providers by their old ids; translate to the host's tools.
    function enabledProviderIds(): var {
        const configured = Array.from(root._cfg?.enabledProviders ?? ["chatgpt", "claude", "antigravity"]);
        const ids = [];
        for (const id of configured) {
            const toolId = id === "chatgpt" ? "codex" : id;
            if (HostServices.AiUsage.toolIds.indexOf(toolId) >= 0 && ids.indexOf(toolId) < 0)
                ids.push(toolId);
        }
        return ids;
    }

    function displayProviderById(targetId: string): var {
        for (const provider of root.displayProviders) {
            if (String(provider.targetId ?? provider.id ?? "") === targetId)
                return provider;
        }
        return null;
    }

    function providerName(providerId: string): string {
        switch (providerId) {
        case "claude": return "Claude";
        case "codex": return "Codex";
        case "opencode": return "OpenCode";
        case "chatgpt": return "ChatGPT";
        case "antigravity": return "Antigravity";
        case "zai": return "Z.AI GLM";
        case "kimi": return "Kimi Code";
        case "openrouter": return "OpenRouter";
        default: return Translation.tr("AI service");
        }
    }

    function providerIcon(providerId: string): string {
        switch (providerId) {
        case "chatgpt": return "openai-symbolic.svg";
        case "claude": return "bootstrap_claude.svg";
        case "codex": return "openai-symbolic.svg";
        case "opencode": return "opencode-logo-light.svg";
        case "antigravity": return "material-symbols_antigravity.svg";
        case "zai": return "Zai.png";
        case "kimi": return "MoonshotAI.png";
        case "openrouter": return "openrouter-symbolic.svg";
        default: return "material-symbols_antigravity.svg";
        }
    }

    function cycleProvider(): void {
        const providerIds = root.cycleProviderIds;
        if (providerIds.length <= 1)
            return;
        const currentIndex = Math.max(0, providerIds.indexOf(root.displayedProviderId));
        root.activeTargetId = String(providerIds[(currentIndex + 1) % providerIds.length]);
    }

    function windowPlaceholder(provider, kind: string): var {
        if (!provider)
            return null;
        if (["short", "daily", "weekly", "monthly"].indexOf(kind) < 0)
            kind = "short";
        const providerId = String(provider.providerId ?? provider.id ?? "");
        const targetId = String(provider.targetId ?? provider.id ?? providerId);
        return {
            id: targetId + ":" + kind,
            providerId: providerId,
            providerName: String(provider.name ?? root.providerName(providerId)),
            providerIcon: root.providerIcon(providerId),
            groupId: "",
            groupName: "",
            windowKind: kind,
            windowLabel: kind === "weekly" ? Translation.tr("Weekly")
                : kind === "daily" ? Translation.tr("Daily")
                : kind === "monthly" ? Translation.tr("Monthly")
                : Translation.tr("Short window"),
            windowMinutes: 0,
            usedPercent: 0,
            remainingPercent: 0,
            resetsAt: 0,
            available: false
        };
    }

    function displayPercent(item): real {
        if (!item || item.available === false)
            return 0;
        const showUsed = String(item.metricKind ?? "quota") !== "credits"
            && (root._cfg?.percentMode ?? "remaining") === "used";
        return Math.max(0, Math.min(100,
            Number(showUsed ? item.usedPercent : item.remainingPercent) || 0));
    }

    function displayFraction(item): real {
        return root.displayPercent(item) / 100;
    }

    function percentText(item): string {
        if (!item || item.available === false)
            return "-";
        if (String(item.metricKind ?? "quota") === "credits")
            return root.creditAmountText(item, true);
        return String(Math.round(root.displayPercent(item))) + "%";
    }

    function creditAmountText(item, compact = false): string {
        const amount = Math.max(0, Number(item?.remainingAmount) || 0);
        const currency = String(item?.currency ?? "USD").toUpperCase();
        const prefix = currency === "USD" ? "$" : currency + " ";
        if (compact && amount >= 1000)
            return prefix + (amount / 1000).toFixed(amount >= 10000 ? 0 : 1) + "k";
        const decimals = compact ? (amount >= 100 ? 0 : amount >= 10 ? 1 : 2) : 2;
        return prefix + amount.toFixed(decimals);
    }

    function isLow(item): bool {
        if (!item || item.available === false)
            return false;
        const threshold = Math.max(0, Math.min(100, root._cfg?.lowRemainingThreshold ?? 20));
        return Number(item.remainingPercent) <= threshold;
    }

    function metricLabel(item = null): string {
        if (String(item?.metricKind ?? "quota") === "credits")
            return Translation.tr("remaining");
        return (root._cfg?.percentMode ?? "remaining") === "used"
            ? Translation.tr("used")
            : Translation.tr("remaining");
    }

    function formatReset(resetsAt): string {
        const timestamp = Number(resetsAt) || 0;
        if (timestamp <= 0)
            return Translation.tr("Reset time unavailable");
        const seconds = Math.max(0, Math.round((timestamp - Date.now()) / 1000));
        if (seconds <= 0)
            return Translation.tr("Reset due");
        const minutes = Math.ceil(seconds / 60);
        if (minutes < 60)
            return Translation.tr("Resets in %1 min").arg(String(minutes));
        const hours = Math.floor(minutes / 60);
        const remainingMinutes = minutes % 60;
        if (hours < 24)
            return Translation.tr("Resets in %1 h %2 min").arg(String(hours)).arg(String(remainingMinutes));
        const days = Math.floor(hours / 24);
        const remainingHours = hours % 24;
        return Translation.tr("Resets in %1 d %2 h").arg(String(days)).arg(String(remainingHours));
    }

    function refresh(force = false): void {
        HostServices.AiUsage.refresh();
    }

    // The host has no sign-in flow; a "refresh sign-in" tap just re-collects.
    function refreshClaudeSignIn(): void {
        root.refresh(true);
    }

    onEnabledChanged: {
        if (root.enabled)
            root.refresh(false);
    }

    Connections {
        target: HostServices.AiUsage
        function onToolsChanged() {
            root.providers = root._buildProviders();
            root.lastUpdated = Date.now();
        }
    }
}
