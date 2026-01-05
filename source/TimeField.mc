using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.System as Sys;

class TimeField extends Ui.Drawable {

    private var bigTextFont;
    private var mediumTextFont;
    private var posX as Lang.Number;
    private var posY as Lang.Number;

    // Constants
    private const SECONDS_Y_OFFSET = 10;

    typedef TimeParams as {
        :positionX as Lang.Number,
        :positionY as Lang.Number
    };

    function initialize(params as TimeParams) {

        Drawable.initialize({
            :identifier => "TimeField"
        });

        posX = params[:positionX];
        posY = params[:positionY];

        bigTextFont    = Ui.loadResource(Rez.Fonts.text_big);
        mediumTextFont = Ui.loadResource(Rez.Fonts.text_medium);
    }

    function draw(dc as Gfx.Dc) as Void {

        // Current local time
        var g = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var deviceSettings = Sys.getDeviceSettings();

        // Handle 12-hour format
        var hour = g.hour;
        if (!deviceSettings.is24Hour) {
            if (hour == 0) {
                hour = 12;
            } else if (hour > 12) {
                hour = hour - 12;
            }
        }

        // Zero-padded components
        var HH = (hour < 10 ? "0" : "") + hour;
        var MM = (g.min  < 10 ? "0" : "") + g.min;
        var SS = (g.sec  < 10 ? "0" : "") + g.sec;

        var timeString = HH + ":" + MM;
        var secString  = SS;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        // Draw main time (HH:MM)
        dc.drawText(
            posX,
            posY,
            bigTextFont,
            timeString,
            Gfx.TEXT_JUSTIFY_LEFT
        );

        // Measure dimensions of main time
        var dims = dc.getTextDimensions(timeString, bigTextFont);
        var timeWidth  = dims[0];
        var timeHeight = dims[1];

        // Position seconds BELOW the main time
        var secX = posX + timeWidth;
        var secY = posY + timeHeight / 3 + SECONDS_Y_OFFSET;

        // Draw seconds (SS)
        dc.drawText(
            secX,
            secY,
            mediumTextFont,
            secString,
            Gfx.TEXT_JUSTIFY_LEFT
        );
    }
}
