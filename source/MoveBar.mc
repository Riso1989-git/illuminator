using Toybox.WatchUi as Ui;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Graphics as Gfx;
using Toybox.Lang;

class MoveBar extends Ui.Drawable {

    private var x;
    private var y;
    private var width;
    private var height;
    private var separator;

    typedef Params as {
        :x         as Lang.Number,
        :y         as Lang.Number,
        :width     as Lang.Number,
        :height    as Lang.Number,
        :separator as Lang.Number
    };

    function initialize(params as Params) {
        Drawable.initialize(params);

        x         = params[:x];
        y         = params[:y];
        width     = params[:width];
        height    = params[:height];
        separator = params[:separator];
    }

    function draw(dc as Gfx.Dc) as Void {

        var info = ActivityMonitor.getInfo();
        var level = 3;

        var maxBars = ActivityMonitor.MOVE_BAR_LEVEL_MAX;
        if (level <= 0) {
            return;
        }

        // Compute bar width
        var totalSeparatorWidth = (maxBars - 1) * separator;
        var barWidth = (width - totalSeparatorWidth) / maxBars;

        var barX = x;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        for (var i = 1; i <= maxBars; i++) {

            // Draw outline for all bars
            dc.drawRectangle(barX, y, barWidth, height);

            // Fill only bars up to current level
            if (i <= level) {
                dc.fillRectangle(
                    barX + 1,
                    y + 1,
                    barWidth - 2,
                    height - 2
                );
            }

            barX += barWidth + separator;
        }
    }
}
