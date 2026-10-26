import QtQuick
import Quickshell
import "../barstyles/43pr" as Product

// Run in a disposable Wayland session with Ryoku's QML import path.
ShellRoot {
    Product.Scene { id: scene; modelData: Quickshell.screens[0] }
    property int step: 0
    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            const positions = ["left", "top", "right", "bottom"];
            const styles = ["joined", "floating", "strip"];
            if (step < 12) {
                scene.config.position = positions[step % 4];
                scene.config.style = styles[Math.floor(step / 4)];
                console.log("LAYOUT", scene.config.position, scene.config.style);
            } else {
                if (scene.clockText(new Date(2026, 0, 1, 0, 5)) !== "00:05")
                    throw new Error("Midnight clock failed");
                scene.config.clock24 = false;
                if (scene.clockText(new Date(2026, 0, 1, 12, 5)) !== "12:05 PM")
                    throw new Error("Noon clock failed");
                scene.moveTo("stats", "start");
                if (scene.sectionOf("stats") !== "start")
                    throw new Error("Module move failed");
                console.log("43PR BAR CHECKS PASSED");
                Qt.quit();
            }
            step++;
        }
    }
}
