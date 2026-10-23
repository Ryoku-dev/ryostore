pragma Singleton

import Quickshell
import Ryoku.Ui.Singletons
import shell.services

// Runs commands the Ryoku way: AppLaunch for desktop entries (it opens the user's
// terminal for Terminal=true ones), Spawn for plain commands. Both keep the shell's
// crash-recovery handle out of the child.
Singleton {
    function exec(command: list<string>): void {
        Spawn.run(command);
    }

    function launchEntry(entry: DesktopEntry): void {
        AppLaunch.run(entry);
    }
}
