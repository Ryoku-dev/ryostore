pragma Singleton
import shell.services as HostServices
import Quickshell
import "../../../services"
import ".."

Singleton {
    id: root

    function closeAllWindows() {
        HyprlandData.windowList.map(w => w.pid).forEach(pid => {
            Quickshell.execDetached(["kill", pid]);
        });
    }

    function changePassword() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.changePassword}`]);
    }

    function lock() {
        Quickshell.execDetached(["loginctl", "lock-session"]);
        if (Config.options.lock.useHyprlock) {
            Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"]);
        } else {
            GlobalStates.screenLocked = true;
        }
    }

    function suspend() {
        HostServices.SessionActions.run("suspend");
    }

    function logout() {
        closeAllWindows();
        Quickshell.execDetached(["pkill", "-i", "Hyprland"]);
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]);
    }

    function hibernate() {
        // Fails silently when the kernel refuses (Secure Boot lockdown, no disk swap) — surface it
        // The host session seam exposes no hibernate action.
        Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "system-suspend-hibernate", Translation.tr("Hibernate unavailable"), Translation.tr("This edition of the shell offers no hibernate action.")]);
    }

    function poweroff() {
        closeAllWindows();
        HostServices.SessionActions.run("shutdown");
    }

    function reboot() {
        closeAllWindows();
        HostServices.SessionActions.run("reboot");
    }

    function rebootToFirmware() {
        closeAllWindows();
        HostServices.SessionActions.run("reboot");
    }
}
