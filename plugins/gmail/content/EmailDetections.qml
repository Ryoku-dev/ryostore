pragma Singleton
import QtQuick
import "EmailDetections.js" as JS

QtObject {
    function detectAll(bodyRaw) {
        return JS.detectAll(bodyRaw);
    }
}
