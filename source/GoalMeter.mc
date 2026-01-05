using Toybox.WatchUi as Ui;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Graphics as Gfx;
using Toybox.Lang;

class GoalMeter extends Ui.Drawable {

    private var posX as Lang.Number;
    private var posY as Lang.Number;
    private var width as Lang.Number;
    private var height as Lang.Number;
    private var gap as Lang.Number;
    private var separator as Lang.Number;

    private var iconFont;

    // Constants
    private const ICON_SIZE = 20;
    private const ICON_GAP  = 8;
    private const MAX_BARS  = 9;
    private const STEPS_ICON_Y_OFFSET  = -25;
    private const FLOORS_ICON_Y_OFFSET = -5;

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
        steps = 4000;
        var stepsGoal = info.stepGoal == null ? 10000 : info.stepGoal;

        var floors = info.floorsClimbed == null ? 0 : info.floorsClimbed;
        floors = 6;
        var floorsGoal = info.floorsClimbedGoal == null ? 10 : info.floorsClimbedGoal;

        // Prevent division by zero
        if (stepsGoal <= 0) { stepsGoal = 1; }
        if (floorsGoal <= 0) { floorsGoal = 1; }

        // Compute ratios
        var stepsRatio  = steps.toFloat()  / stepsGoal;
        var floorsRatio = floors.toFloat() / floorsGoal;

        if (stepsRatio  > 1) { stepsRatio  = 1; }
        if (floorsRatio > 1) { floorsRatio = 1; }

        // Bar width excluding icon
        var barX     = posX + ICON_SIZE + ICON_GAP;
        var barWidth = width - ICON_SIZE - ICON_GAP;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        // ------------------
        // STEPS BAR (top)
        // ------------------

        // Draw icon
        dc.drawText(
            posX,
            posY + STEPS_ICON_Y_OFFSET,
            iconFont,
            STEPS_ICON,
            Gfx.TEXT_JUSTIFY_LEFT
        );

        var stepsBars = Math.round(MAX_BARS * stepsRatio);
        var barSegmentWidth = (barWidth - (MAX_BARS - 1) * separator) / MAX_BARS;

        var barPosX = barX;
        for (var i = 1; i <= MAX_BARS; i++) {
            dc.drawRectangle(barPosX, posY, barSegmentWidth, height);
            if (i <= stepsBars) {
                dc.fillRectangle(barPosX + 1, posY + 1, barSegmentWidth - 2, height - 2);
            }
            barPosX += barSegmentWidth + separator;
        }

        // ------------------
        // FLOORS BAR (bottom)
        // ------------------

        var floorsY = posY + height + gap;

        // Draw icon
        dc.drawText(
            posX,
            floorsY + FLOORS_ICON_Y_OFFSET,
            iconFont,
            FLOORS_ICON,
            Gfx.TEXT_JUSTIFY_LEFT
        );

        var floorsBars = Math.round(MAX_BARS * floorsRatio);
        barPosX = barX;
        for (var i = 1; i <= MAX_BARS; i++) {
            dc.drawRectangle(barPosX, floorsY, barSegmentWidth, height);
            if (i <= floorsBars) {
                dc.fillRectangle(barPosX + 1, floorsY + 1, barSegmentWidth - 2, height - 2);
            }
            barPosX += barSegmentWidth + separator;
        }
    }
}
