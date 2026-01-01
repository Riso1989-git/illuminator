import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CasioView extends WatchUi.WatchFace {

    // globals
    var debug = false;
    var is_lowpower = false;
    var deviceSettings = false;

    // time
    var hour = null;
    var minute = null;
    var second = null;

    // layout
    var canvas_h = 0;
    var canvas_w = 0;
    var canvas_shape = 0;
    var canvas_rect = false;
    var canvas_circ = false;
    var canvas_semicirc = false;
    var canvas_tall = false;
    var vert_layout = false;
    var dw = null;
    var dh = null;
    var dw_half = null;
    var dh_half = null;

    // drawables
    var worldMapDrawable = null;
    var analogueDrawable = null;
    var dateFieldDrawable = null;
    var timeFieldDrawable = null;
    var upperGoalMeterDrawable = null;
    var lowerGoalMeterDrawable = null;
    var goalMeterDrawable = null;
    var moveBarDrawable = null;
    var datafieldsDrawable = null;
    var datafieldsMiddleDrawable = null;
    var datafieldsBottomDrawable = null;

    enum {
        SCREEN_SHAPE_CIRC = 0x000001,
        SCREEN_SHAPE_SEMICIRC = 0x000002,
        SCREEN_SHAPE_RECT = 0x000003
    }

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        // w,h of canvas
        canvas_w = dc.getWidth();
        canvas_h = dc.getHeight();

        // let's grab the canvas shape
        deviceSettings = System.getDeviceSettings();
        canvas_shape = deviceSettings.screenShape;

        // find out the type of screen on the device
        canvas_tall = (vert_layout && canvas_shape == SCREEN_SHAPE_RECT) ? true : false;
        canvas_rect = (canvas_shape == SCREEN_SHAPE_RECT && !vert_layout) ? true : false;
        canvas_circ = (canvas_shape == SCREEN_SHAPE_CIRC) ? true : false;
        canvas_semicirc = (canvas_shape == SCREEN_SHAPE_SEMICIRC) ? true : false;

        // set a few constants
        dw = canvas_w;
        dh = canvas_h;
        
        // Load the layout
        setLayout(Rez.Layouts.WatchFace(dc));
        worldMapDrawable = View.findDrawableById("WorldMapDisplay") as WorldMap;
        analogueDrawable = View.findDrawableById("AnalogueDisplay") as Analogue;
        dateFieldDrawable = View.findDrawableById("DateFieldDisplay") as DateField; 
        timeFieldDrawable = View.findDrawableById("TimeFieldDisplay") as TimeField; 
        goalMeterDrawable = View.findDrawableById("GoalMeterDisplay") as GoalMeter;  
        moveBarDrawable = View.findDrawableById("MoveBarDisplay") as MoveBar;
        datafieldsDrawable = View.findDrawableById("DataFieldsDisplay") as DataFields; 
        datafieldsMiddleDrawable = View.findDrawableById("DataFieldsMiddleDisplay") as DataFields; 
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // grab time objects
        var clockTime = System.getClockTime();

        // define time, day, month variables
        hour = clockTime.hour;
        minute = clockTime.min;
        second = clockTime.sec;

        // 12-hour support
        if (hour > 12 || hour == 0) {
            if (!deviceSettings.is24Hour) {
                if (hour == 0) {
                    hour = 12;
                } else {
                    hour = hour - 12;
                }
            }
        }

        // clear the screen with black background
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        // Draw the layout (includes WorldMap drawable defined in layout.xml)
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        is_lowpower = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        is_lowpower = true;
        WatchUi.requestUpdate();
    }

}
