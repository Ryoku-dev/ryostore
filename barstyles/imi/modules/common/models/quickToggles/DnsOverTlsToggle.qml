import QtQuick
import "../../../../services"
import "../.."

QuickToggleModel {
    id: root
    name: Translation.tr("Encrypted DNS")

    available: DnsOverTls.available
    toggled: DnsOverTls.active
    statusText: DnsOverTls.active ? DnsOverTls.presetLabel : Translation.tr("Off")
    tooltipText: !DnsOverTls.resolvedAvailable ? Translation.tr("systemd-resolved isn't running") : DnsOverTls.active ? Translation.tr("DNS over TLS: %1 (%2) | Right-click to change server").arg(DnsOverTls.presetLabel).arg(DnsOverTls.statusText) : Translation.tr("DNS over TLS is off | Right-click to change server")
    icon: DnsOverTls.busy ? "sync" : DnsOverTls.active ? "encrypted" : "no_encryption"
    hasMenu: true

    mainAction: () => {
        DnsOverTls.toggle();
    }
}
