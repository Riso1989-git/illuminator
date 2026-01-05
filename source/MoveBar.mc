using Toybox.WatchUi as Ui;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Graphics as Gfx;
using Toybox.Lang;

class MoveBar extends Ui.Drawable {

    private var posX as Lang.Number;
    private var posY as Lang.Number;
    private var width as Lang.Number;
    private var height as Lang.Number;
    private var separator as Lang.Number;

    typedef Params as {
        :posX      as Lang.Number,
        :posY      as Lang.Number,
        :width     as Lang.Number,
        :height    as Lang.Number,
        :separator as Lang.Number
    };

    function initialize(params as Params) {
        Drawable.initialize({ :identifier => "MoveBar" });

        posX      = params[:posX];
        posY      = params[:posY];
        width     = params[:width];
        height    = params[:height];
        separator = params[:separator];
    }

    function draw(dc as Gfx.Dc) as Void {

        var info = ActivityMonitor.getInfo();
        var level = info.moveBarLevel == null ? 0 : info.moveBarLevel;

        var maxBars = ActivityMonitor.MOVE_BAR_LEVEL_MAX;

        // Compute bar width
        var totalSeparatorWidth = (maxBars - 1) * separator;
        var barWidth = (width - totalSeparatorWidth) / maxBars;

        var barX = posX;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        for (var i = 1; i <= maxBars; i++) {

            // Draw outline for all bars
            dc.drawRectangle(barX, posY, barWidth, height);

            // Fill only bars up to current level
            if (i <= level) {
                dc.fillRectangle(
                    barX + 1,
                    posY + 1,
                    barWidth - 2,
                    height - 2
                );
            }

            barX += barWidth + separator;
        }
    }
}
