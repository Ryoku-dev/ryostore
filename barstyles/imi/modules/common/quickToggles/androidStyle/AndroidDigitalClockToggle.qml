pragma ComponentBehavior: Bound

import QtQuick
import "../../../.."
import "../../../../services"
import "../.."
import "../../widgets"
import "."

/**
 * Digital clock tile: the background widget's DigitalClock, instantiated as-is.
 *
 * The `clock_digital` settings the desktop widget uses are the whole configuration:
 * typography (size, weight, width, roundness), the vertical line spacing and the
 * extras (date, quote, colon, seconds). Nothing is re-configured here, so the settings
 * page for the Digital Clock widget stays the only place to change the look.
 *
 * What the tile owns is the fit and the orientation:
 * - Free-form sizing: the configured design is laid out at its natural size and scaled
 *   as a whole into whatever footprint the grid gives it, so every size from 1x1 up
 *   works and the configured proportions survive.
 * - A tile taller than wide stacks the two lines (the vertical form); a wider tile runs
 *   the single-line form.
 *
 * Does not toggle anything on click; purely an information display tile.
 */
AndroidWidgetTileBase {
    id: root

    tooltipText: Translation.tr("Clock")

    /** Portrait tiles stack the lines, landscape tiles run the single-line form. */
    readonly property bool isVertical: root.surface.height > root.surface.width

    MaterialSymbol {
        anchors.centerIn: parent
        text: "schedule"
        iconSize: 32
        color: Appearance.colors.colOnSurfaceVariant
    }
}
