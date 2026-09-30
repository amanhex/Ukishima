import QtQuick

/**
 * Vendored midnight-shell Anim (components/Anim.qml), verbatim logic against
 * MsTheme. NumberAnimation whose duration/easing follow the requested type;
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

    property int type: MsAnim.DefaultSpatial

    duration: {
        if (type < MsAnim.StandardSmall || type > MsAnim.SlowEffects)
            return MsTheme.durNormal;

        if (type === MsAnim.FastSpatial)
            return MsTheme.durFastSpatial;

        if (type === MsAnim.DefaultSpatial)
            return MsTheme.durDefaultSpatial;

        if (type === MsAnim.SlowSpatial)
            return MsTheme.durSlowSpatial;

        if (type === MsAnim.FastEffects)
            return MsTheme.durFastEffects;

        if (type === MsAnim.DefaultEffects)
            return MsTheme.durDefaultEffects;

        if (type === MsAnim.SlowEffects)
            return MsTheme.durSlowEffects;

        const types = ["small", "normal", "large", "extraLarge"];
        const idx = type % 4; // 0-7 are the 4 standard types
        return MsTheme["dur" + types[idx][0].toUpperCase() + types[idx].slice(1)];
    }
    easing: {
        if (type === MsAnim.FastSpatial)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveFastSpatial
        };

        if (type === MsAnim.DefaultSpatial)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveDefaultSpatial
        };

        if (type === MsAnim.SlowSpatial)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveSlowSpatial
        };

        if (type === MsAnim.FastEffects)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveFastEffects
        };

        if (type === MsAnim.DefaultEffects)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveDefaultEffects
        };

        if (type === MsAnim.SlowEffects)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveSlowEffects
        };

        if (type >= MsAnim.EmphasizedSmall && type <= MsAnim.EmphasizedExtraLarge)
            return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveEmphasized
        };

        return {
            "type": Easing.BezierSpline,
            "bezierCurve": MsTheme.curveStandard
        };
    }
}
