pragma Singleton

import QtQuick
import Quickshell
import shell.services

QtObject {
    signal aboutToSleep
    signal resumed
    signal lockRequested
    signal unlockRequested

    function logout(): void { SessionActions.run("logout"); }
    function suspend(): void { SessionActions.run("suspend"); }
    function poweroff(): void { SessionActions.run("shutdown"); }
    function reboot(): void { SessionActions.run("reboot"); }
    function lock(): void { SessionActions.run("lock"); }

    function hibernate(): void {
        Quickshell.execDetached(["notify-send", "Caelestia", "Hibernate is not available through the Ryoku session API"]);
    }

    function suspendThenHibernate(): void {
        hibernate();
    }

    function exec(command): bool {
        if (!command || !command.length)
            return false;
        const verb = String(command[0]).toLowerCase();
        if (verb === "logout")
            logout();
        else if (verb === "shutdown" || verb === "poweroff")
            poweroff();
        else if (verb === "reboot")
            reboot();
        else if (verb === "suspend" || verb === "sleep")
            suspend();
        else if (verb === "hibernate")
            hibernate();
        else if (verb === "lock")
            lock();
        else
            return false;
        return true;
    }
}
