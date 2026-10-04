import QtQuick

/**
 * Vendored midnight-shell Anim (components/Anim.qml), verbatim logic against
 * PolTheme. NumberAnimation whose duration/easing follow the requested type;
 * an explicit duration at the use site still wins, exactly like upstream.
 */
NumberAnimation {

    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: PolAnim.DefaultSpatial

    duration: {
        if (type < PolAnim.StandardSmall || type > PolAnim.SlowEffects)
            return PolTheme.durNormal;

        if (type === PolAnim.FastSpatial)
            return PolTheme.durFastSpatial;

        if (type === PolAnim.DefaultSpatial)
            return PolTheme.durDefaultSpatial;

        if (type === PolAnim.SlowSpatial)
            return PolTheme.durSlowSpatial;

        if (type === PolAnim.FastEffects)
            return PolTheme.durFastEffects;

        if (type === PolAnim.DefaultEffects)
            return PolTheme.durDefaultEffects;

        if (type === PolAnim.SlowEffects)
            return PolTheme.durSlowEffects;

        const types = ["small", "normal", "large", "extraLarge"];
        const idx = type % 4; // 0-7 are the 4 standard types
        return PolTheme["dur" + types[idx][0].toUpperCase() + types[idx].slice(1)];
    }
    easing: {
        if (type === PolAnim.FastSpatial)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveFastSpatial
        };

        if (type === PolAnim.DefaultSpatial)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveDefaultSpatial
        };

        if (type === PolAnim.SlowSpatial)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveSlowSpatial
        };

        if (type === PolAnim.FastEffects)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveFastEffects
        };

        if (type === PolAnim.DefaultEffects)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveDefaultEffects
        };

        if (type === PolAnim.SlowEffects)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveSlowEffects
        };

        if (type >= PolAnim.EmphasizedSmall && type <= PolAnim.EmphasizedExtraLarge)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveEmphasized
        };

        return {
            "type": Easing.BezierSpline,
            "bezierCurve": PolTheme.curveStandard
        };
    }
}
