import QtQuick

QtObject {
    id: root

    required property string path
    required property var entries
    required property var favouriteApps
    property var frequencies: ({})

    readonly property var apps: {
        const favourites = favouriteApps || [];
        const mapped = (entries || []).filter(entry => entry !== null && entry !== undefined).map(entry => ({
            entry,
            frequency: frequencies[entry.id] || 0,
            id: entry.id || "",
            name: entry.name || "",
            comment: entry.comment || "",
            execString: entry.execString || "",
            startupClass: entry.startupClass || "",
            genericName: entry.genericName || "",
            categories: (entry.categories || []).join(" "),
            keywords: (entry.keywords || []).join(" ")
        }));
        mapped.sort((a, b) => {
            const af = favourites.some(pattern => a.id === pattern);
            const bf = favourites.some(pattern => b.id === pattern);
            if (af !== bf)
                return af ? -1 : 1;
            if (a.frequency !== b.frequency)
                return b.frequency - a.frequency;
            return a.name.localeCompare(b.name);
        });
        return mapped;
    }

    function incrementFrequency(id: string): void {
        const next = Object.assign({}, frequencies);
        next[id] = (next[id] || 0) + 1;
        frequencies = next;
    }
}
