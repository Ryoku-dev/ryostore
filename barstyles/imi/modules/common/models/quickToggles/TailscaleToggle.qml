import QtQuick
import "../../../../services"
import "../.."

QuickToggleModel {
    id: root
    name: Translation.tr("Tailscale")

    available: (Config.options?.tailscale?.enabled ?? true) && TailscaleService.available
    toggled: (Config.options?.tailscale?.enabled ?? true) && TailscaleService.active
    tooltipText: (Config.options?.tailscale?.enabled ?? true)
        ? Translation.tr("Tailscale Mesh: %1 | Right-click for network peers & exit nodes").arg(statusText)
        : Translation.tr("Tailscale is disabled in Privacy settings")
    icon: TailscaleService.active ? "hub" : (TailscaleService.backendState === "NeedsLogin" ? "key" : "vpn_lock")
    hasMenu: true

    mainAction: () => {
        if (Config.options?.tailscale?.enabled ?? true)
            TailscaleService.toggleTailscale()
    }
}
