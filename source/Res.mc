import Toybox.Lang;
import Toybox.WatchUi;

// T2.3: fonts shared by several drawables are loaded exactly once.
// Every drawable calls Res.load() in initialize() and then uses Res.textFont etc.
module Res {

    var textFont = null;        // Rez.Fonts.text         (DateField, DataFields, AOD date)
    var iconFont = null;        // Rez.Fonts.garmin_icons (DataFields, GoalMeter)
    var bigFont = null;         // Rez.Fonts.text_big     (TimeField, AOD time)
    var mediumFont = null;      // Rez.Fonts.text_medium  (TimeField seconds)

    function load() as Void {
        if (textFont != null) {
            return;
        }
        textFont   = WatchUi.loadResource(Rez.Fonts.text);
        iconFont   = WatchUi.loadResource(Rez.Fonts.garmin_icons);
        bigFont    = WatchUi.loadResource(Rez.Fonts.text_big);
        mediumFont = WatchUi.loadResource(Rez.Fonts.text_medium);
    }
}
