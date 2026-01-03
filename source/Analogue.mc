using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.System as Sys;
using Toybox.Time;

class Analogue extends Ui.Drawable {

    /* =======================
     * Constants
     * ======================= */
    const TILE_CHAR_MASK = 0x00000FFF;
    const TILE_X_MASK    = 0x003FF000;
    const TILE_Y_MASK    = 0xFFC00000;

    /** Number of hour hand positions per hour (60 positions / 12 hours) */
    const HOUR_SEGMENTS_PER_ROTATION = 5;

    /* =======================
     * Resources
     * ======================= */
    private var dialFont;
    private var dialData;

    private var hourFont0_29;
    private var hourFont30_59;
    private var hourData0_29;
    private var hourData30_59;

    private var minFont0_29;
    private var minFont30_59;
    private var minData0_29;
    private var minData30_59;

    /* =======================
     * Position
     * ======================= */
    private var posX;
    private var posY;

    typedef AnalogueParams as {
        :positionX as Lang.Number,
        :positionY as Lang.Number
    };

    /* =======================
     * Lifecycle
     * ======================= */
    function initialize(params as AnalogueParams) {

        Drawable.initialize({
            :identifier => "Analogue"
        });

        posX = params[:positionX];
        posY = params[:positionY];

        dialFont = Ui.loadResource(Rez.Fonts.dial);
        dialData = Ui.loadResource(Rez.JsonData.dialJson);

        hourFont0_29 = Ui.loadResource(Rez.Fonts.hour_0_29);
        hourFont30_59 = Ui.loadResource(Rez.Fonts.hour_30_59);
        hourData0_29 = Ui.loadResource(Rez.JsonData.hour_0_29Json);
        hourData30_59 = Ui.loadResource(Rez.JsonData.hour_30_59Json);

        minFont0_29 = Ui.loadResource(Rez.Fonts.minute_0_29);
        minFont30_59 = Ui.loadResource(Rez.Fonts.minute_30_59);
        minData0_29 = Ui.loadResource(Rez.JsonData.minute_0_29Json);
        minData30_59 = Ui.loadResource(Rez.JsonData.minute_30_59Json);
    }

    /* =======================
     * Render
     * ======================= */
    function draw(dc as Gfx.Dc) as Void {

        drawDial(dc);
        drawHands(dc);
    }

    /* =======================
     * Dial
     * ======================= */
    private function drawDial(dc as Gfx.Dc) {

        if (dialData == null || dialData.size() == 0) {
            return;
        }

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        drawTiles(dialData[0], dialFont, dc, posX, posY);

        if (dialData.size() > 1) {
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            drawTiles(dialData[1], dialFont, dc, posX, posY);
        }

        if (dialData.size() > 2) {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            drawTiles(dialData[2], dialFont, dc, posX, posY);
        }
    }


    /* =======================
     * Hands
     * ======================= */
    private function drawHands(dc as Gfx.Dc) {

        var now = Sys.getClockTime();
        var timeValues = applyTimezoneOffset(now.hour, now.min, now.timeZoneOffset);
        var hour = timeValues[0] % 12;
        var minute = timeValues[1];

        /* ---- Hour hand ---- */
        var hourIndex =
            ((hour + (minute / 60.0)) * HOUR_SEGMENTS_PER_ROTATION).toNumber() % 60;

        var hFont;
        var hData;
        var hIdx;

        if (hourIndex >= 30) {
            hFont = hourFont30_59;
            hData = hourData30_59;
            hIdx  = hourIndex - 30;
        } else {
            hFont = hourFont0_29;
            hData = hourData0_29;
            hIdx  = hourIndex;
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if (hData != null && hIdx >= 0 && hIdx < hData.size()) {
            drawTiles(hData[hIdx], hFont, dc, posX, posY);
        }

        /* ---- Minute hand ---- */
        var mFont;
        var mData;
        var mIdx;

        if (minute >= 30) {
            mFont = minFont30_59;
            mData = minData30_59;
            mIdx  = minute - 30;
        } else {
            mFont = minFont0_29;
            mData = minData0_29;
            mIdx  = minute;
        }

        if (mData != null && mIdx >= 0 && mIdx < mData.size()) {
            drawTiles(mData[mIdx], mFont, dc, posX, posY);
        }
    }

    /* =======================
     * Timezone Helper
     * ======================= */
    /**
     * Applies timezone offset to the given hour and minute.
     * @param hour Current hour (0-23)
     * @param minute Current minute (0-59)
     * @param localTimeZoneOffset Device's timezone offset in seconds
     * @return Array with [adjustedHour, adjustedMinute]
     */
    private function applyTimezoneOffset(hour as Lang.Number, minute as Lang.Number, localTimeZoneOffset as Lang.Number) as Lang.Array<Lang.Number> {
        var tzOffset = getPropertyValue("AnalogueTimezoneOffset");

        if (tzOffset == null || tzOffset == 0) {
            return [hour, minute];
        }

        var localOffsetMinutes = localTimeZoneOffset / 60;
        var totalMinutes;

        if (tzOffset == 1) {
            // UTC+0: subtract local timezone offset
            totalMinutes = hour * 60 + minute - localOffsetMinutes;
        } else {
            // Custom timezone: convert to UTC first, then apply target timezone
            // tzOffset format: hours * 100 + minutes (e.g., 530 = +5:30, -800 -> -8 hours 0 min)
            var targetHours = tzOffset / 100;
            var targetMinutes = (tzOffset % 100).abs();
            if (tzOffset < 0) {
                targetMinutes = -targetMinutes;
            }
            var targetOffsetMinutes = targetHours * 60 + targetMinutes;

            // Calculate: local time -> UTC -> target timezone
            totalMinutes = hour * 60 + minute - localOffsetMinutes + targetOffsetMinutes;
        }

        // Normalize to valid ranges (0-23 hours, 0-59 minutes)
        var adjustedHour = ((totalMinutes / 60) % 24 + 24) % 24;
        var adjustedMinute = ((totalMinutes % 60) + 60) % 60;

        return [adjustedHour, adjustedMinute];
    }

    /* =======================
     * Tile renderer
     * ======================= */
    private function drawTiles(
        tileData as Lang.Array,
        font,
        dc as Gfx.Dc,
        xoff as Lang.Number,
        yoff as Lang.Number
    ) as Void {

        if (tileData == null) {
            return;
        }

        for (var i = 0; i < tileData.size(); i++) {

            var packed = tileData[i];
            if (packed == null) {
                continue;
            }

            var char = packed & TILE_CHAR_MASK;
            var xpos = (packed & TILE_X_MASK) >> 12;
            var ypos = (packed & TILE_Y_MASK) >> 22;

            dc.drawText(
                xoff + xpos,
                yoff + ypos,
                font,
                (char.toNumber()).toChar(),
                Gfx.TEXT_JUSTIFY_LEFT
            );
        }
    }
}
