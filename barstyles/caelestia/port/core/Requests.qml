pragma Singleton

import QtQuick
import Quickshell

// HTTP GET for the weather location search; the callback gets the response text.
Singleton {
    function get(url: string, onSuccess: var, onError: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300)
                onSuccess?.(xhr.responseText);
            else
                onError?.(xhr.status);
        };
        xhr.open("GET", url);
        xhr.send();
    }
}
