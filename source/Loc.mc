import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Weather;

// T3.1: last known location for sunrise/sunset, null-safe.
// Checked about once an hour (called from Cache.refresh() once a minute):
//   1. Garmin weather observation location (follows the phone)
//   2. Activity.getActivityInfo().currentLocation (after a GPS activity)
//   3. value stored on the watch from an earlier run
// Storage is written only when the location really changes (> ~5 km).
module Loc {

    var lat = null;                    // Float degrees
    var lng = null;
    var version as Number = 0;         // bumps on change -> DataFields drops its sun cache
    var lastCheck as Number = 0;

    function refresh(force as Boolean) as Void {
        var now = Time.now().value();
        if (!force && now - lastCheck < 3600) {
            return;
        }
        lastCheck = now;

        var pos = null;
        if (Toybox has :Weather) {
            var cc = Weather.getCurrentConditions();
            if (cc != null && cc.observationLocationPosition != null) {
                pos = cc.observationLocationPosition;
            }
        }
        if (pos == null) {
            var info = Activity.getActivityInfo();           // may be null
            if (info != null && info.currentLocation != null) {
                pos = info.currentLocation;
            }
        }

        if (pos != null) {
            var deg = pos.toDegrees();
            var nLat = deg[0].toFloat();
            var nLng = deg[1].toFloat();
            if (lat == null || lng == null
                    || (nLat - lat).abs() > 0.05 || (nLng - lng).abs() > 0.05) {
                lat = nLat;
                lng = nLng;
                version++;
                Storage.setValue("LastLocationLat", lat);
                Storage.setValue("LastLocationLng", lng);
            }
        } else if (lat == null) {
            var sLat = Storage.getValue("LastLocationLat");
            var sLng = Storage.getValue("LastLocationLng");
            if (sLat != null && sLng != null) {
                lat = sLat;
                lng = sLng;
                version++;
            }
        }
    }
}
