import QtQuick
import QtQuick.Shapes

/**
 * One annotation stroke in local coords (global points minus ox/oy). Pen,
 * rect and arrow draw as vector Shapes; text as a Text item. Used both for
 * the live overlay and inside the export composite, so the PNG matches the
 * screen exactly.
 */
Item {
    id: root

    required property var s
    required property real ox
    required property real oy
    required property string font

    function lp(p) {
        return Qt.point(p[0] - ox, p[1] - oy);
    }

    function arrowWings(p0, p1, w) {
        var a = Math.atan2(p1[1] - p0[1], p1[0] - p0[0]);
        var len = 8 + w * 3, spread = 0.42;
        return [[p1[0] - len * Math.cos(a - spread), p1[1] - len * Math.sin(a - spread)], [p1[0] - len * Math.cos(a + spread), p1[1] - len * Math.sin(a + spread)]];
    }

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        visible: s && s.type !== "text"
        antialiasing: true

        ShapePath {
            strokeColor: s ? s.color : "#000000"
            strokeWidth: s ? s.w : 1
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: {
                    if (!s || !s.pts || !s.pts.length)
                        return [];

                    if (s.type === "pen")
                        return s.pts.map(lp);

                    var a = s.pts[0], b = s.pts.length > 1 ? s.pts[1] : s.pts[0];
                    if (s.type === "rect")
                        return [lp(a), lp([b[0], a[1]]), lp(b), lp([a[0], b[1]]), lp(a)];

                    if (s.type === "arrow") {
                        var w = arrowWings(a, b, s.w);
                        return [lp(a), lp(b)];
                    }
                    return [];
                }
            }

        }

        ShapePath {
            strokeColor: s ? s.color : "#000000"
            strokeWidth: s ? s.w : 1
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: {
                    if (!s || s.type !== "arrow" || !s.pts || s.pts.length < 2)
                        return [];

                    var a = s.pts[0], b = s.pts[1];
                    var w = arrowWings(a, b, s.w);
                    return [lp(w[0]), lp(b), lp(w[1])];
                }
            }

        }

    }

    Text {
        visible: s && s.type === "text"
        x: s && s.pts && s.pts.length ? s.pts[0][0] - ox : 0
        y: s && s.pts && s.pts.length ? s.pts[0][1] - oy : 0
        text: s ? (s.text || "") : ""
        color: s ? s.color : "#000000"
        font.family: root.font
        font.pixelSize: s ? (s.size || 18) : 18
    }

}
