import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
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

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        deviceSettings = System.getDeviceSettings();

        setLayout(Rez.Layouts.WatchFace(dc));
        worldMapDrawable = View.findDrawableById("WorldMapDisplay") as WorldMap;
        analogueDrawable = View.findDrawableById("AnalogueDisplay") as Analogue;
        dateFieldDrawable = View.findDrawableById("DateFieldDisplay") as DateField; 
        timeFieldDrawable = View.findDrawableById("TimeFieldDisplay") as TimeField; 
        goalMeterDrawable = View.findDrawableById("GoalMeterDisplay") as GoalMeter;  
        moveBarDrawable = View.findDrawableById("MoveBarDisplay") as MoveBar;
        datafieldsDrawable = View.findDrawableById("DataFieldsDisplay") as DataFields; 
        datafieldsMiddleDrawable = View.findDrawableById("DataFieldsMiddleDisplay") as DataFields;
        datafieldsBottomDrawable = View.findDrawableById("DataFieldsBottomDisplay") as DataFields;
    }

    // Called when this View is brought to the foreground.
    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        // clear the screen
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        // Draw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        is_lowpower = false;
    }

    function onEnterSleep() as Void {
        is_lowpower = true;
        WatchUi.requestUpdate();
    }

}
