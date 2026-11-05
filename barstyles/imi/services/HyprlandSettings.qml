pragma Singleton

import QtQuick
import Quickshell

// Hyprland config writes are gone: the Ryoku host owns the compositor and has
// no surface for launch-animation overrides. The entry computation stays
// because WindowAnimationSurface replays the same curves in Q.
Singleton {
    id: root

    readonly property var appLaunchStyles: ["scale", "slide"]
    readonly property var slideDirections: ["left", "right", "top", "bottom"]

    // Accepted and dropped: there is nothing to push the animation to.
    function updateAppLaunchAnimation(anim) {}

    /**
     * Beziers only, on purpose. Hyprland 0.56 has spring curves, but when a window's goal
     * changes mid-animation - which dwindle does while a new tile settles - hyprutils only
     * rescales the spring's velocity for plain numbers. Position and size are vectors, so they
     * keep the old velocity and swing sideways. A bezier restarts cleanly from where it is.
     */
    function appLaunchEntries(anim) {
        if (!anim || typeof anim !== "object")
            return [];
        const isEnabled = anim.enable !== false;
        const style = root.appLaunchStyles.includes(anim.style) ? anim.style : "scale";
        const percent = Math.max(5, Math.min(95, Math.round(Number(anim.startPercent) || 20)));
        // Hyprland's speed is the duration in tenths of a second.
        const speed = Math.max(1, Math.min(10, Number(anim.speed) || 4));
        const direction = root.slideDirections.includes(anim.slideDirection) ? anim.slideDirection : "";

        const entries = [
            root.curveEntry("iiAppOpen", 0.22, 1, 0.36, 1),
            root.curveEntry("iiAppSlide", 0.3, 0.7, 0.1, 1),
            root.curveEntry("iiAppClose", 0.32, 0.72, 0, 1),
            root.curveEntry("iiAppFade", 0.2, 0.6, 0.35, 1)
        ];

        const openCurve = style === "slide" ? "iiAppSlide" : "iiAppOpen";
        // The slide needs a moment longer to cover its distance.
        const openSpeed = style === "slide" ? speed * 1.12 : speed;
        // Slides fade in quicker, so the travel is seen rather than hidden behind transparency.
        const fadeInSpeed = style === "slide" ? speed * 0.5 : speed * 0.7;
        const openStyle = style === "slide" ? ("slide " + direction).trim() : ("popin " + percent + "%");
        const outPercent = Math.min(90, Math.round(percent + (100 - percent) * 0.5));
        const closeStyle = style === "slide" ? ("slide " + direction).trim() : ("popin " + outPercent + "%");

        if (isEnabled) {
            entries.push(root.animationEntry("windowsIn", true, openSpeed, openCurve, openStyle));
            entries.push(root.animationEntry("fadeIn", true, fadeInSpeed, "iiAppFade", ""));
            entries.push(root.animationEntry("windowsOut", true, speed * 0.65, "iiAppClose", closeStyle));
            entries.push(root.animationEntry("fadeOut", true, speed * 0.65, "iiAppClose", ""));
            entries.push(root.animationEntry("windowsMove", true, speed, "iiAppOpen", "slide"));
        } else {
            entries.push(root.animationEntry("windowsIn", false, speed, "iiAppOpen", "popin 100%"));
            entries.push(root.animationEntry("fadeIn", false, speed, "iiAppOpen", ""));
            entries.push(root.animationEntry("windowsOut", false, speed, "iiAppOpen", "popin 100%"));
            entries.push(root.animationEntry("fadeOut", false, speed, "iiAppOpen", ""));
            entries.push(root.animationEntry("windowsMove", true, 3, "emphasizedDecel", "slide"));
        }
        return entries;
    }

    function curveEntry(name, x0, y0, x1, y1) {
        return { kind: "curve", id: name, name: name,
            spec: { type: "bezier", points: [[x0, y0], [x1, y1]] } };
    }

    function animationEntry(leaf, enabled, speed, curve, style) {
        const spec = { leaf: leaf, enabled: enabled, speed: Number(speed.toFixed(2)), bezier: curve };
        if (style) spec.style = style;
        return { kind: "animation", id: leaf, spec: spec };
    }
}
