pragma Singleton
import QtQuick

QtObject {
    id: root

    function trimFileProtocol(str) {
        let s = str ? str.toString() : "";
        if (s.startsWith("file://")) {
            s = s.slice(7);
            if (s.startsWith("localhost/")) {
                s = s.slice(9);
            }
        } else if (s.startsWith("file:/")) {
            s = s.slice(5);
        } else if (s.startsWith("file:")) {
            s = s.slice(5);
        }
        return s;
    }

    function fileNameForPath(str) {
        if (!str) return "";
        const trimmed = trimFileProtocol(str);
        return trimmed.split(/[\\/]/).pop();
    }

    function folderNameForPath(str) {
        if (!str) return "";
        const trimmed = trimFileProtocol(str);
        const noTrailing = trimmed.endsWith("/") ? trimmed.slice(0, -1) : trimmed;
        if (!noTrailing) return "";
        return noTrailing.split(/[\\/]/).pop();
    }

    function trimFileExt(str) {
        if (!str) return "";
        const trimmed = trimFileProtocol(str);
        const lastDot = trimmed.lastIndexOf(".");
        if (lastDot > -1 && lastDot > trimmed.lastIndexOf("/")) {
            return trimmed.slice(0, lastDot);
        }
        return trimmed;
    }

    function parentDirectory(str) {
        if (!str) return "";
        const trimmed = trimFileProtocol(str);
        const parts = trimmed.split(/[\\/]/);
        if (parts.length <= 1) return "";
        parts.pop();
        return parts.join("/");
    }
}
