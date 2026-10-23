.pragma library

// The panels settings as rows, copied from the Ryoku Hub's Caelestia pages
// (hub/quickshell/schema/CaelestiaPanelsPage.js), less the launcher, which this style leaves out.

var rows = [
    {
        "tab": "Dashboard",
        "group": "GENERAL",
        "key": "caelestia.dashboard.enabled",
        "label": "Enabled",
        "desc": "",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": true
    },
    {
        "tab": "Dashboard",
        "group": "GENERAL",
        "key": "caelestia.dashboard.showOnHover",
        "label": "Show on hover",
        "desc": "Reveal when the cursor reaches the screen edge",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": true
    },
    {
        "tab": "Dashboard",
        "group": "GENERAL",
        "key": "caelestia.dashboard.profilePicShape",
        "label": "Dashboard profile picture shape",
        "desc": "Choose the shape of the profile picture on the dashboard",
        "src": "caelestia.json",
        "ctl": "chips",
        "opts": [
            0,
            1,
            8,
            9,
            10,
            11,
            12,
            13,
            16,
            17,
            18,
            19,
            20
        ],
        "optLabels": {
            "0": "Circle",
            "1": "Square",
            "8": "Pill",
            "10": "Diamond",
            "11": "Clam Shell",
            "12": "Pentagon",
            "13": "Gem",
            "16": "Cookie 4-Sided",
            "17": "Cookie 6-Sided",
            "18": "Cookie 7-Sided",
            "19": "Cookie 9-Sided",
            "20": "Cookie 12-Sided",
            "9": "Triangle"
        },
        "def": 9
    },
    {
        "tab": "Dashboard",
        "group": "GENERAL",
        "key": "caelestia.dashboard.showClockSeconds",
        "label": "Show clock seconds",
        "desc": "Display seconds below the clock in the dashboard",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": false
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.showDashboard",
        "label": "Dashboard",
        "desc": "",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": true
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.showMedia",
        "label": "Media",
        "desc": "",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": true
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.showPerformance",
        "label": "Performance",
        "desc": "",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": true
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.showNotes",
        "label": "Notes",
        "desc": "",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": false
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.showTerminal",
        "label": "Terminal",
        "desc": "",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": false
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.colorizeMediaGif",
        "label": "Recolor media GIF",
        "desc": "Apply system theme colors to the media GIF",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": true
    },
    {
        "tab": "Dashboard",
        "group": "TABS",
        "key": "caelestia.dashboard.useMediaShapes",
        "label": "Use material shapes",
        "desc": "Replace the media GIF with audio-reactive material shapes",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": false
    },
    {
        "tab": "Dashboard",
        "group": "BEHAVIOR",
        "key": "caelestia.dashboard.hoverThickness",
        "label": "Hover trigger depth",
        "desc": "Distance in from the screen edge that opens the dashboard",
        "src": "caelestia.json",
        "ctl": "step",
        "lo": 1.0,
        "hi": 100.0,
        "from": 1.0,
        "to": 100.0,
        "def": 10
    },
    {
        "tab": "Dashboard",
        "group": "BEHAVIOR",
        "key": "caelestia.dashboard.hoverWidth",
        "label": "Hover trigger width",
        "desc": "How much of the top edge opens the dashboard, as a percentage of its width",
        "src": "caelestia.json",
        "ctl": "step",
        "lo": 10.0,
        "hi": 100.0,
        "from": 10.0,
        "to": 100.0,
        "def": 50
    },
    {
        "tab": "Dashboard",
        "group": "BEHAVIOR",
        "key": "caelestia.dashboard.dragThreshold",
        "label": "Drag threshold",
        "desc": "Pixels dragged before the dashboard opens",
        "src": "caelestia.json",
        "ctl": "step",
        "lo": 0.0,
        "hi": 200.0,
        "from": 0.0,
        "to": 200.0,
        "def": 50
    },
    {
        "tab": "On-screen sliders",
        "group": "SLIDERS",
        "key": "caelestia.osd.enabled",
        "label": "Enabled",
        "desc": "Show the on-screen sliders",
        "src": "caelestia.json",
        "ctl": "sw",
        "def": false
    },
    {
        "tab": "On-screen sliders",
        "group": "EDGE TRIGGER",
        "key": "caelestia.osd.hoverThickness",
        "label": "Depth",
        "desc": "Distance from the screen edge",
        "src": "caelestia.json",
        "ctl": "step",
        "lo": 1.0,
        "hi": 100.0,
        "from": 1.0,
        "to": 100.0,
        "def": 10
    },
    {
        "tab": "On-screen sliders",
        "group": "EDGE TRIGGER",
        "key": "caelestia.osd.hoverWidth",
        "label": "Height",
        "desc": "Portion of the edge that responds",
        "src": "caelestia.json",
        "ctl": "step",
        "lo": 10.0,
        "hi": 100.0,
        "from": 10.0,
        "to": 100.0,
        "def": 50
    },
    {
        "tab": "On-screen sliders",
        "group": "BEHAVIOR",
        "key": "caelestia.osd.hideDelay",
        "label": "Hide delay",
        "desc": "Seconds before the slider hides",
        "src": "caelestia.json",
        "ctl": "step",
        "lo": 1.0,
        "hi": 10.0,
        "from": 1.0,
        "to": 10.0,
        "def": 2000
    }
];
