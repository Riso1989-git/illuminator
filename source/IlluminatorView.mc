import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class IlluminatorView extends WatchUi.WatchFace {

    // globals
    var is_lowpower as Lang.Boolean = false;
    var deviceSettings as System.DeviceSettings?;

    // drawables
    var worldMapDrawable as WorldMap?;
    var analogueDrawable as Analogue?;
    var dateFieldDrawable as DateField?;
    var timeFieldDrawable as TimeField?;
    var goalMeterDrawable as GoalMeter?;
    var moveBarDrawable as MoveBar?;
    var datafieldsDrawable as DataFields?;
    var datafieldsMiddleDrawable as DataFields?;
    var datafieldsBottomDrawable as DataFields?;

    // T2.1: always-on (low-power) rendering
    private var mBurnIn as Lang.Boolean = false;     // AMOLED: true
    private var mAodFace as AodFace?;

    // T0.2 / T0.3 diagnostics: time of the last hourly log line
    private var mLastDiagLog as Lang.Number = 0;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        deviceSettings = System.getDeviceSettings();
        mBurnIn = (deviceSettings has :requiresBurnInProtection) && deviceSettings.requiresBurnInProtection;

        setLayout(Rez.Layouts.WatchFace(dc));
        mAodFace = Rez.Layouts.AlwaysOn(dc)[0] as AodFace;
        worldMapDrawable = View.findDrawableById("WorldMapDisplay") as WorldMap;
        analogueDrawable = View.findDrawableById("AnalogueDisplay") as Analogue;
        dateFieldDrawable = View.findDrawableById("DateFieldDisplay") as DateField; 
        timeFieldDrawable = View.findDrawableById("TimeFieldDisplay") as TimeField; 
        goalMeterDrawable = View.findDrawableById("GoalMeterDisplay") as GoalMeter;  
        moveBarDrawable = View.findDrawableById("MoveBarDisplay") as MoveBar;
        datafieldsDrawable = View.findDrawableById("DataFieldsDisplay") as DataFields; 
        datafieldsMiddleDrawable = View.findDrawableById("DataFieldsMiddleDisplay") as DataFields;
        datafieldsBottomDrawable = View.findDrawableById("DataFieldsBottomDisplay") as DataFields;

        // A START line after a gap in the hourly lines means the face was restarted (crash or reload)
        logDiagnostics("START", true);
    }

    // T3.6: called by IlluminatorApp.onSettingsChanged().
    function onSettingsChanged() as Void {
        if (datafieldsDrawable != null)       { datafieldsDrawable.loadSettings(); }
        if (datafieldsMiddleDrawable != null) { datafieldsMiddleDrawable.loadSettings(); }
        if (datafieldsBottomDrawable != null) { datafieldsBottomDrawable.loadSettings(); }
        if (analogueDrawable != null)         { analogueDrawable.loadSettings(); }
        if (timeFieldDrawable != null)        { timeFieldDrawable.loadSettings(); }
    }

    // Called when this View is brought to the foreground.
    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        logDiagnostics("HOUR", false);
        Cache.refresh();

        // clear the screen
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        if (is_lowpower && mBurnIn) {
            drawAlwaysOn(dc);
            return;
        }

        // Draw the layout
        View.onUpdate(dc);
    }

    // T2.1 / Q2: time + date + analogue hands + dimmed map, nothing else.
    // Everything moves together inside a 7x7 px box, one step per minute
    // (49-minute cycle), so no pixel stays lit in the same place (burn-in).
    // Budget: ~8 % of pixels lit (limit 10 %) - verify with the simulator heat map.
    private function drawAlwaysOn(dc as Dc) as Void {
        var m = System.getClockTime().min;
        var dx = (m % 7) - 3;
        var dy = ((m / 7) % 7) - 3;

        if (worldMapDrawable != null) {
            worldMapDrawable.drawDimmed(dc, dx, dy);
        }
        if (analogueDrawable != null) {
            analogueDrawable.drawHandsOnly(dc, dx, dy);
        }
        if (mAodFace != null) {
            mAodFace.drawShifted(dc, dx, dy);
        }
    }

    // Called when this View is removed from the screen.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        is_lowpower = false;
        Cache.invalidate();
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        is_lowpower = true;
        WatchUi.requestUpdate();
    }

    /* ==========================================================================
     * T0.2 / T0.3 diagnostics - DEBUG BUILDS ONLY (release builds use the no-op)
     *
     * Writes one line per hour (plus one at start-up) with memory and battery:
     *   2026-10-13 18:00 HOUR used=61234 free=40210 total=101444 batt=87.5 lowpower=true
     * On a sideloaded watch System.println goes to GARMIN\APPS\LOGS\<PRG NAME>.TXT,
     * which must already exist (create an empty file, e.g. CASIO.TXT for CASIO.PRG).
     * In the simulator the lines appear in the debug console.
     * Remove after T0 is finished (or keep: it costs nothing in release builds).
     * ========================================================================== */
    (:debug)
    private function logDiagnostics(tag as Lang.String, force as Lang.Boolean) as Void {
        var now = Time.now().value();
        if (!force && now - mLastDiagLog < 3600) {
            return;
        }
        mLastDiagLog = now;

        var s = System.getSystemStats();
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        System.println(
            g.year + "-" + g.month.format("%02d") + "-" + g.day.format("%02d") + " " +
            g.hour.format("%02d") + ":" + g.min.format("%02d") + " " + tag +
            " used=" + s.usedMemory + " free=" + s.freeMemory + " total=" + s.totalMemory +
            " batt=" + s.battery.format("%.1f") + " lowpower=" + is_lowpower
        );
    }

    (:release)
    private function logDiagnostics(tag as Lang.String, force as Lang.Boolean) as Void {
    }

}
