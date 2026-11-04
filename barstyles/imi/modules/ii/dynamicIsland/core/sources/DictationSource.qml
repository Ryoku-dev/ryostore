pragma ComponentBehavior: Bound

import QtQuick
import "../../../../.."
import "../../../../common"
import "../../../../../services"

/** Speech is being transcribed. */
ContinuousSource {
    id: source

    activityId: "dictation"
    condition: DictationService.busy && (Config.options?.dictation?.showInIsland ?? true)
}
