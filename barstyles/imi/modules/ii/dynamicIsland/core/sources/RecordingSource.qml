pragma ComponentBehavior: Bound

import QtQuick
import "../../../../common"

/** A screen recording is in progress. */
ContinuousSource {
    id: source

    activityId: "recording"
    condition: (Persistent.states.screenRecord && Persistent.states.screenRecord.active) || false
}
