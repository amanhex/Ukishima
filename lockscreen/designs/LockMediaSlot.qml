import QtQuick
import ".."

/**
 * Sizing wrapper for the lock's media card, so a design can scale it without
 * touching the card's internal pixel geometry. Hidden when the user's
 * `lockShowMedia` is off or no player has a title.
 */
Item {
    id: root

    property var host: null
    property real amount: 1
    //* Which lock design's card chrome to draw. "default" is the original
    //* glass pill, used by the default lock and as the safe fallback.
    property string variant: "default"

    implicitWidth: 382 * root.amount
    implicitHeight: 64 * root.amount

    LockMedia {
        id: media

        host: root.host
        variant: root.variant
        scale: root.amount
        transformOrigin: Item.TopLeft
    }
}