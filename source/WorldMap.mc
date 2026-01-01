using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time.Gregorian;

import Toybox.Application;

class WorldMap extends Ui.Drawable {

    /* =======================
     * Configuration Constants
     * ======================= */

    const MAP_LAT_TOP    = 75.0;
    const MAP_LAT_BOTTOM = -60.0;

    // Packed tile bit masks
    const TILE_CHAR_MASK = 0x00000FFF;
    const TILE_X_MASK    = 0x003FF000;
    const TILE_Y_MASK    = 0xFFC00000;

    /* =======================
     * Instance State
     * ======================= */

    private var mPositionX;
    private var mPositionY;
    private var mMapFont;
    private var mMapData;

    // Projection dimensions
    private var mapWidth;
    private var mapPixelHeight;

    // Cached values
    private var mercatorTop;
    private var mercatorBottom;
    private var mLastNightCalcMinute = -1;
    private var mNightOverlayPoints = [];

    typedef WorldMapParams as {
        :positionX as Lang.Number,
        :positionY as Lang.Number,
        :width     as Lang.Number,
        :height    as Lang.Number
    };

    function initialize(params as WorldMapParams) {

        Drawable.initialize({
            :identifier => "WorldMap"
        });

        mPositionX      = params[:positionX];
        mPositionY      = params[:positionY];
        mapWidth        = params[:width];
        mapPixelHeight  = params[:height];

        // Load resources once
        mMapFont = Ui.loadResource(Rez.Fonts.worldMap);
        mMapData = Ui.loadResource(Rez.JsonData.worldMapJson);

        // Cache Mercator bounds (constant math)
        var topRad    = MAP_LAT_TOP * Math.PI / 180.0;
        var bottomRad = MAP_LAT_BOTTOM * Math.PI / 180.0;

        mercatorTop =
            Math.ln(Math.tan(Math.PI / 4.0 + topRad / 2.0));
        mercatorBottom =
            Math.ln(Math.tan(Math.PI / 4.0 + bottomRad / 2.0));
    }

    function draw(dc as Graphics.Dc) as Void {

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        // draw world map from font
        drawTiles(
            mMapData[0],
            mMapFont,
            dc,
            mPositionX,
            mPositionY
        );

        // Day / Night overlay
        drawDayNight(dc);
        
        if (gLocationLat != null) { //gps must be set to draw position
            // pixel location value of current GPS
            var pixelLocation = latLonToPixel(gLocationLat, gLocationLng);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(mPositionX + pixelLocation[0], mPositionY, mPositionX + pixelLocation[0], mPositionY + mapPixelHeight + 10);
            dc.drawLine(mPositionX, mPositionY + pixelLocation[1], mPositionX + mapWidth, mPositionY + pixelLocation[1]) ;
        }
    }

    private function drawTiles(
        tileData as Lang.Array,
        font,
        dc as Graphics.Dc,
        xoff as Lang.Number,
        yoff as Lang.Number
    ) as Void {

        if (tileData == null || tileData.size() == 0) {
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
                Graphics.TEXT_JUSTIFY_LEFT
            );
        }
    }

    function latLonToPixel(
        lat as Lang.Float,
        lon as Lang.Float
    ) as Lang.Array {

        // Clamp inputs
        if (lon < -180) { lon = -180; }
        if (lon > 180)  { lon = 180;  }

        if (lat > MAP_LAT_TOP)    { lat = MAP_LAT_TOP; }
        if (lat < MAP_LAT_BOTTOM) { lat = MAP_LAT_BOTTOM; }

        // Normalize longitude
        var xNorm = (lon + 180.0) / 360.0;

        // Mercator projection
        var latRad    = lat * Math.PI / 180.0;
        var mercY     =
            Math.ln(Math.tan(Math.PI / 4.0 + latRad / 2.0));

        var yNorm =
            (mercatorTop - mercY)
            / (mercatorTop - mercatorBottom);

        return [
            (xNorm * mapWidth).toNumber(),
            (yNorm * mapPixelHeight).toNumber()
        ];
    }

    private function drawDayNight(dc as Graphics.Dc) as Void {
        var now = Time.now();
        var g = Gregorian.info(now, Time.FORMAT_SHORT);
        
        // Only recalculate if minute has changed
        var currentMinute = g.hour * 60 + g.min;
        if (currentMinute != mLastNightCalcMinute) {
            mLastNightCalcMinute = currentMinute;
            calculateNightOverlay(g);
        }
        
        // Draw cached overlay
        dc.setFill(Graphics.createColor(128, 0, 0, 0));
        for (var i = 0; i < mNightOverlayPoints.size(); i++) {
            var point = mNightOverlayPoints[i];
            dc.fillRectangle(
                mPositionX + point[0],
                mPositionY + point[1],
                point[2],
                point[2]
            );
        }
    }

    private function calculateNightOverlay(g) as Void {
        mNightOverlayPoints = [];
        
        // --- Day of year ---
        var isLeapYear = (g.year % 4 == 0 && g.year % 100 != 0) || (g.year % 400 == 0);
        var daysInMonth = [0,31,59,90,120,151,181,212,243,273,304,334];
        if (isLeapYear && g.month > 2) {
            daysInMonth = [0,31,60,91,121,152,182,213,244,274,305,335];
        }
        var doy = g.day + daysInMonth[g.month - 1];
        
        // --- Solar declination ---
        var dayAngle = 2.0 * Math.PI * (doy - 80) / 365.0;
        var decl = 0.4093 * Math.sin(dayAngle);
        
        // --- Subsolar longitude ---
        var utcHours = g.hour + g.min / 60.0 + g.sec / 3600.0;
        var subLon = (12.0 - utcHours + 0.8) * 15.0;
        
        var step = 2;
        var sinDecl = Math.sin(decl);
        var cosDecl = Math.cos(decl);
        
        for (var x = 0; x < mapWidth; x += step) {
            for (var y = 0; y < mapPixelHeight; y += step) {
                
                var lon = (x.toFloat() / mapWidth) * 360.0 - 180.0;
                var lat = 90.0 - (y.toFloat() / mapPixelHeight) * 180.0;
                var latRad = lat * Math.PI / 180.0;
                
                var sinLat = Math.sin(latRad);
                var cosLat = Math.cos(latRad);
                
                var hourAngle = (lon - subLon) * Math.PI / 180.0;
                
                var solarElevation = sinLat * sinDecl + cosLat * cosDecl * Math.cos(hourAngle);
                
                if (solarElevation < 0.05) {
                    mNightOverlayPoints.add([x, y, step]);
                }
            }
        }
    }
}
