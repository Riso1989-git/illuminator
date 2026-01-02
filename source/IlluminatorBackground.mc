import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class IlluminatorBackground extends WatchUi.Drawable {

    function initialize() {
        var dictionary = {
            :identifier => "Background"
        };

        Drawable.initialize(dictionary);
    }

    function draw(dc as Dc) as Void {
        // Set the background color to white
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_WHITE);
        dc.clear();
    }

}
