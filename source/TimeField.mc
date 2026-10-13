using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

class TimeField extends Ui.Drawable {

    private var posX as Lang.Number;
    private var posY as Lang.Number;


    // T2.5: "Show seconds" setting (high power only; AOD never draws seconds)
    private var mShowSeconds as Lang.Boolean = true;

    // T2.4: HH:MM string and its size rebuilt once a minute, not every frame
    private var mTimeString as Lang.String = "";
    private var mSecX as Lang.Number = 0;
    private var mSecY as Lang.Number = 0;
    private var mGen as Lang.Number = -1;

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

        Res.load();
        loadSettings();
    }

    // Call again when settings change (T3.6).
    function loadSettings() as Void {
        var v = getPropertyValue("ShowSeconds");
        mShowSeconds = (v == null) ? true : (v as Lang.Boolean);
        mGen = -1;
    }

    function draw(dc as Gfx.Dc) as Void {
        var ct = Sys.getClockTime();

        if (mGen != Cache.generation) {
            mGen = Cache.generation;

            // Handle 12-hour format
            var hour = ct.hour;
            if (Cache.settings != null && !Cache.settings.is24Hour) {
                if (hour == 0) {
                    hour = 12;
                } else if (hour > 12) {
                    hour = hour - 12;
                }
            }
            mTimeString = hour.format("%02d") + ":" + ct.min.format("%02d");

            var dims = dc.getTextDimensions(mTimeString, Res.bigFont);
            mSecX = posX + dims[0];
            // Bottom-align the seconds with HH:MM: same baseline for both fonts.
            // (Works for every font size; the old "height / 3 + 10" only fitted 416/454.)
            mSecY = posY + Gfx.getFontAscent(Res.bigFont) - Gfx.getFontAscent(Res.mediumFont);
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        // Draw main time (HH:MM)
        dc.drawText(posX, posY, Res.bigFont, mTimeString, Gfx.TEXT_JUSTIFY_LEFT);

        // Draw seconds (SS) to the right of the main time
        if (mShowSeconds) {
            dc.drawText(mSecX, mSecY, Res.mediumFont, ct.sec.format("%02d"), Gfx.TEXT_JUSTIFY_LEFT);
        }
    }
}
