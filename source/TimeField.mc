using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

class TimeField extends Ui.Drawable {

    private var bigTextFont;
    private var smallTextFont;
    private var mediumTextFont;
    private var posX;
    private var posY;

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

        bigTextFont   = Ui.loadResource(Rez.Fonts.text_big);
        mediumTextFont   = Ui.loadResource(Rez.Fonts.text_medium);
        smallTextFont = Ui.loadResource(Rez.Fonts.text);
    }

    function draw(dc as Gfx.Dc) as Void {

        // Current local time
        var g = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        // Zero-padded components
        var HH = (g.hour < 10 ? "0" : "") + g.hour;
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
        var secY = posY + timeHeight/3 + 10; 

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
