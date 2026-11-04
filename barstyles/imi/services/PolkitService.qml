pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as HostServices

// Polkit authentication UI state, over the host's Polkit service: the daemon is
// the PolicyKit1 agent and runs the PAM conversation; this only reshapes its
// frames for the island and keeps a `flow` shim so the old call sites work.
Singleton {
    id: root

    readonly property bool active: HostServices.Polkit.active
    // A prompt is answerable while it is live and the submitted one is still out.
    readonly property bool interactionAvailable: HostServices.Polkit.active && !HostServices.Polkit.busy

    readonly property string cleanMessage: {
        const message = HostServices.Polkit.message;
        return message.endsWith(".") ? message.slice(0, -1) : message;
    }

    readonly property string cleanPrompt: {
        const inputPrompt = HostServices.Polkit.prompt.trim();
        const cleaned = inputPrompt.endsWith(":") ? inputPrompt.slice(0, -1) : inputPrompt;
        return cleaned.length > 0 ? cleaned : (root.flow.responseVisible ? Translation.tr("Input") : Translation.tr("Password"));
    }

    // Shim over the daemon frames: the fields the old flow object exposed, and
    // the two calls, mapped one-to-one onto the host service.
    readonly property QtObject flow: QtObject {
        readonly property string message: HostServices.Polkit.message
        readonly property string inputPrompt: HostServices.Polkit.prompt
        // Whether the answer may be shown as typed (PAM echo).
        readonly property bool responseVisible: HostServices.Polkit.echo

        function submit(secret) {
            root.submit(secret);
        }

        function cancelAuthenticationRequest() {
            root.cancel();
        }
    }

    function submit(secret) {
        HostServices.Polkit.submit(secret);
    }

    function cancel() {
        HostServices.Polkit.cancel();
    }
}
