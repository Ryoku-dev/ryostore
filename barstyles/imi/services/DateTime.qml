pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common"

Singleton {
    id: root

    property var clock: SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    property string time: Qt.locale().toString(clock.date, Config.options?.time?.format || "hh:mm")
    property string shortDate: Qt.locale().toString(clock.date, Config.options?.time?.shortDateFormat || "dd/MM")
    property string date: Qt.locale().toString(clock.date, Config.options?.time?.dateWithYearFormat || "dd/MM/yyyy")
    property string longDate: Qt.locale().toString(clock.date, Config.options?.time?.dateFormat || "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dddd, MMMM dd")
    readonly property string currentTime: time
    readonly property string currentDate: longDate
    readonly property int hours: clock.date.getHours()
    readonly property int minutes: clock.date.getMinutes()
    readonly property int seconds: clock.date.getSeconds()
    readonly property string time12h: Qt.locale().toString(clock.date, "hh:mm ap")
    readonly property string hourStr: Qt.locale().toString(clock.date, "HH")
    readonly property string minuteStr: Qt.locale().toString(clock.date, "mm")
    readonly property string digitH0: hourStr.charAt(0)
    readonly property string digitH1: hourStr.charAt(1)
    readonly property string digitM0: minuteStr.charAt(0)
    readonly property string digitM1: minuteStr.charAt(1)
    property string uptime: "0h, 0m"

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            fileUptime.reload();
            const textUptime = fileUptime.text();
            const uptimeSeconds = Number(textUptime.split(" ")[0] ?? 0);
            const days = Math.floor(uptimeSeconds / 86400);
            const hours = Math.floor((uptimeSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeSeconds % 3600) / 60);
            let formatted = "";
            if (days > 0) formatted += `${days}d `;
            if (hours > 0) formatted += `${hours}h `;
            if (minutes > 0 || !formatted) formatted += `${minutes}m`;
            uptime = formatted.trim();
        }
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
    }
}
