using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DateField extends Ui.Drawable {

    private var mX;
    private var mY;
    private var mFont;

    private const DAYS = [ "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" ];

    typedef Params as {
        :positionX as Lang.Number,
        :positionY as Lang.Number
    };

    function initialize(params as Params) {
        Drawable.initialize({ :identifier => "DateField" });

        mX = params[:positionX];
        mY = params[:positionY];
        mFont = Ui.loadResource(Rez.Fonts.text);
    }

    function draw(dc as Gfx.Dc) as Void {

        // Local time → Gregorian
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        // Day of week (1–7)
        var dayStr = DAYS[g.day_of_week - 1];

        // Manual zero-padding avoids format allocations
        var dd = (g.day   < 10 ? "0" : "") + g.day;
        var mm = (g.month < 10 ? "0" : "") + g.month;

        // Illuminator-style: MON 05-02
        var text = dayStr + " " + dd + "-" + mm;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(mX, mY, mFont, text, Gfx.TEXT_JUSTIFY_LEFT);
    }
}
