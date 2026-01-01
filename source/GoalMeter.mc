using Toybox.WatchUi as Ui;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Graphics as Gfx;
using Toybox.Lang;

class GoalMeter extends Ui.Drawable {

    private var posX;
    private var posY;
    private var width;
    private var height;
    private var gap;
    private var separator;

    private var iconFont;
    private const ICON_SIZE = 20;
    private const ICON_GAP  = 8;

    // Icons (from garmin_icons font)
    private const STEPS_ICON  = "N";
    private const FLOORS_ICON = "b";

    typedef Params as {
        :positionX as Lang.Number,
        :positionY as Lang.Number,
        :width     as Lang.Number,
        :height    as Lang.Number,
        :gap       as Lang.Number,
        :separator as Lang.Number
    };

    function initialize(params as Params) {
        Drawable.initialize({ :identifier => "GoalMeter" });

        posX      = params[:positionX];
        posY      = params[:positionY];
        width     = params[:width];
        height    = params[:height];
        gap       = params[:gap];
        separator = params[:separator];

        iconFont = Ui.loadResource(Rez.Fonts.garmin_icons);
    }

    function draw(dc as Gfx.Dc) as Void {

        var info   = ActivityMonitor.getInfo();
        var steps  = info.steps == null ? 0 : info.steps;
        var stesGoal = info.stepGoal == null ? 10000 : info.stepGoal;

        var floors = info.floorsClimbed == null ? 0 : info.floorsClimbed;
        var floorsGoal = info.floorsClimbedGoal  == null ? 10 : info.floorsClimbedGoal;

        // Compute ratios
        var stepsRatio  = steps.toFloat()  / stesGoal;
        var floorsRatio = floors.toFloat() / floorsGoal;

        if (stepsRatio  > 1) { stepsRatio  = 1; }
        if (floorsRatio > 1) { floorsRatio = 1; }

        // Bar width excluding icon
        var barX     = posX + ICON_SIZE + ICON_GAP;
        var barWidth = width - ICON_SIZE - ICON_GAP;

        var maxBars = 9;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        // ------------------
        // STEPS BAR (top)
        // ------------------

        // Draw icon
        dc.drawText(
            posX,
            posY - 25,
            iconFont,
            STEPS_ICON,
            Gfx.TEXT_JUSTIFY_LEFT
        );

        var stepsBars = Math.round(maxBars * stepsRatio);
        var stepBarWidth = (barWidth - (maxBars - 1) * separator) / maxBars;

        var barPosX = barX;
        for (var i = 1; i <= maxBars; i++) {
            dc.drawRectangle(barPosX, posY, stepBarWidth, height);
            if (i <= stepsBars) {
                dc.fillRectangle(barPosX + 1, posY + 1, stepBarWidth - 2, height - 2);
            }
            barPosX += stepBarWidth + separator;
        }

        // ------------------
        // FLOORS BAR (bottom)
        // ------------------

        var floorsY = posY + height + gap;

        // Draw icon
        dc.drawText(
            posX,
            floorsY - 5,
            iconFont,
            FLOORS_ICON,
            Gfx.TEXT_JUSTIFY_LEFT
        );

        var floorsBars = Math.round(maxBars * floorsRatio);
        barPosX = barX;
        for (var i = 1; i <= maxBars; i++) {
            dc.drawRectangle(barPosX, floorsY, stepBarWidth, height);
            if (i <= floorsBars) {
                dc.fillRectangle(barPosX + 1, floorsY + 1, stepBarWidth - 2, height - 2);
            }
            barPosX += stepBarWidth + separator;
        }
    }
}
