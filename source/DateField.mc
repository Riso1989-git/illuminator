using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DateField extends Ui.Drawable {

    private var mX as Lang.Number;
    private var mY as Lang.Number;

    private const DAYS = [ "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" ];

    // T2.4: text rebuilt once a minute
    private var mText as Lang.String = "";
    private var mGen as Lang.Number = -1;

    typedef Params as {
        :positionX as Lang.Number,
        :positionY as Lang.Number
    };

    function initialize(params as Params) {
        Drawable.initialize({ :identifier => "DateField" });

        mX = params[:positionX];
        mY = params[:positionY];
        Res.load();
    }

    function draw(dc as Gfx.Dc) as Void {

        if (mGen != Cache.generation) {
            mGen = Cache.generation;

            // Local time → Gregorian
            var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

            // Illuminator-style: MON 05-02
            mText = DAYS[(g.day_of_week as Lang.Number) - 1] + " " + (g.day as Lang.Number).format("%02d")
                + "-" + (g.month as Lang.Number).format("%02d");
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(mX, mY, Res.textFont, mText, Gfx.TEXT_JUSTIFY_LEFT);
    }
}
