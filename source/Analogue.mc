using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

class Analogue extends Ui.Drawable {

    /* =======================
     * Tile bit masks
     * ======================= */
    const TILE_CHAR_MASK = 0x00000FFF;
    const TILE_X_MASK    = 0x003FF000;
    const TILE_Y_MASK    = 0xFFC00000;

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
        minData0_29 = Ui.loadResource(Rez.JsonData.worldMaminute_0_29Json);
        minData30_59 = Ui.loadResource(Rez.JsonData.worldMaminute_30_59Json);
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
        var hour   = now.hour % 12;
        var minute = now.min;

        /* ---- Hour hand ---- */
        var hourIndex =
            ((hour + (minute / 60.0)) * 5).toNumber() % 60;

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
        drawTiles(hData[hIdx], hFont, dc, posX, posY);

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

        drawTiles(mData[mIdx], mFont, dc, posX, posY);
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
