import QtQuick

// The island's glass: GlassControl wired to Settings -> Appearance.
GlassControl {
    flat: !Theme.glass
    strength: Theme.glassStrength
}
