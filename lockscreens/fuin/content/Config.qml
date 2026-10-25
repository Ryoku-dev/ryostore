pragma Singleton

import QtQuick

// The one bridge between Jurai's dotted config keys and this theme's
// theme.conf. In the shell, Config.get reads the shell's own store; here the
// values ride SDDM's injected `config` object (the theme.conf [General]
// section). Unmapped keys answer their fallback, exactly as an unset key
// does in the shell.
QtObject {
    function get(key, fallback) {
        const c = (typeof config !== "undefined") ? config : null;
        if (c) {
            if (key === "apsara.opacity") {
                const v = parseFloat(c.opacity);
                if (!isNaN(v))
                    return v;
            }
            if (key === "fonts.expressive" && c.fontExpressive)
                return String(c.fontExpressive);
            if (key === "fonts.technical" && c.fontTechnical)
                return String(c.fontTechnical);
            if (key === "appearance.radius") {
                const v = parseFloat(c.radiusPercent);
                if (!isNaN(v))
                    return v;
            }
        }
        return fallback;
    }
}
