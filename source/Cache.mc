import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;

// T2.4: values that change at most once a minute, fetched once a minute instead of
// several times per frame. IlluminatorView.onUpdate() calls Cache.refresh() first.
//
// Drawables that cache their own strings remember the Cache.generation they built
// them for and rebuild when it differs, so a minute change is never missed
// (e.g. when the minute changed during AOD frames that skip those drawables).
module Cache {

    var generation as Number = 0;     // increments on every refresh
    var minuteKey as Number = -1;      // hour * 60 + min of the last refresh
    var settings = null;               // System.DeviceSettings
    var activity = null;               // ActivityMonitor.Info

    function refresh() as Void {
        var ct = System.getClockTime();
        var key = ct.hour * 60 + ct.min;
        if (key != minuteKey || settings == null) {
            minuteKey = key;
            settings = System.getDeviceSettings();
            activity = ActivityMonitor.getInfo();
            Loc.refresh(false);        // T3.1: does real work at most once an hour
            generation++;
        }
    }

    // Force a refresh on the next frame (settings changed, wake-up, ...).
    function invalidate() as Void {
        minuteKey = -1;
    }
}
