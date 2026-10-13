import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// T2.1: time (HH:MM, no seconds) and date for the always-on screen.
// The view adds the analogue hands and the dimmed map and passes one burn-in
// offset (dx, dy) to all of them so the whole AOD picture moves together.
class AodFace extends WatchUi.Drawable {

    private const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    private var mTimeX as Number;
    private var mTimeY as Number;
    private var mDateX as Number;
    private var mDateY as Number;

    typedef AodParams as {
        :timeX as Number,
        :timeY as Number,
        :dateX as Number,
        :dateY as Number
    };

    function initialize(params as AodParams) {
        Drawable.initialize({ :identifier => "AodFace" });
        mTimeX = params[:timeX] as Number;
        mTimeY = params[:timeY] as Number;
        mDateX = params[:dateX] as Number;
        mDateY = params[:dateY] as Number;
        Res.load();
    }

    // Not used by View.onUpdate (this drawable is never part of the main layout).
    function draw(dc as Graphics.Dc) as Void {
        drawShifted(dc, 0, 0);
    }

    function drawShifted(dc as Graphics.Dc, dx as Number, dy as Number) as Void {
        var t = System.getClockTime();
        var h = t.hour;
        if (Cache.settings != null && !Cache.settings.is24Hour) {
            h = (h % 12 == 0) ? 12 : h % 12;
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mTimeX + dx, mTimeY + dy, Res.bigFont,
                    h.format("%02d") + ":" + t.min.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);

        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mDateX + dx, mDateY + dy, Res.textFont,
                    DAYS[(g.day_of_week as Number) - 1] + " " + (g.day as Number).format("%02d")
                        + "-" + (g.month as Number).format("%02d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
    }
}
