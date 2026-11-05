pragma Singleton
import Quickshell
import "EmailDetections.js" as JS

Singleton {
    function detectAll(bodyRaw) {
        return JS.detectAll(bodyRaw);
    }
}
