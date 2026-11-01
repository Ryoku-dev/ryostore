pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string result: ""
    property string rawResult: ""
    property bool busy: false
    property string pending: ""

    function evalAsync(expression: string): void {
        pending = expression.trim();
        result = "";
        rawResult = "";
        if (!pending)
            return;
        busy = true;
        process.command = ["qalc", "-t", "--", pending];
        process.running = true;
    }

    function evaluate(expression: string, printExpression = true): string {
        evalAsync(expression);
        return "";
    }

    Process {
        id: process
        stdout: StdioCollector {
            id: output
            onStreamFinished: {
                root.rawResult = text.trim();
                root.result = root.rawResult;
                root.busy = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!output.text.trim()) {
                    root.result = "";
                    root.rawResult = "";
                    root.busy = false;
                }
            }
        }
    }
}
