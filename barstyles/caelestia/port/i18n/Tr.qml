pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property var locale: Qt.locale()

    function mark(text, args = []): string {
        return applyArgs(text, args);
    }

    function markCtx(text, context, args = []): string {
        return applyArgs(text, args);
    }

    function tr(text: string): string {
        return text;
    }

    function trCtx(text: string, context: string): string {
        return text;
    }

    function trN(text: string, plural: string, n: int): string {
        return pluralForm(text, plural, n).replace("%n", String(n));
    }

    function trCtxN(text: string, plural: string, n: int, context: string): string {
        return trN(text, plural, n);
    }

    function trMarked(text: string): string {
        return text;
    }

    function formatDateTime(value: date, format): string {
        return value.toLocaleString(locale, format);
    }

    function pluralForm(one: string, many: string, n: int): string {
        return Math.abs(n) === 1 ? one : many;
    }

    function applyArgs(text, args): string {
        let out = String(text);
        for (let i = 0; i < args.length; i++)
            out = out.replace(`%${i + 1}`, String(args[i]));
        return out;
    }
}
