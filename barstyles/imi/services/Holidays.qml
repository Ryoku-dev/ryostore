pragma Singleton

import QtQuick
import Quickshell
import shell.services as HostServices

// Holiday data for the calendar, straight off the host's Holidays service: the
// daemon subscribes to its calendar topic and indexes the days by date.
Singleton {
    id: root

    readonly property string status: HostServices.Holidays.status
    readonly property string region: HostServices.Holidays.region
    readonly property string errorText: HostServices.Holidays.errorText
    readonly property var days: HostServices.Holidays.days
    readonly property var byDate: HostServices.Holidays.byDate
    // The settings page shows the resolved region; resolution is the
    // daemon's business and surfaces through region.
    readonly property string countryCode: root.region || ""
    readonly property string browseUrl: ""

    function forDate(key) {
        return root.byDate[key] || [];
    }

    function hasDate(key) {
        return root.forDate(key).length > 0;
    }
}
