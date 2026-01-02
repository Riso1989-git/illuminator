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

    // Night overlay grid step (larger = faster but less precise)
    const GRID_STEP = 2;

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

    // Pre-computed lookup tables
    private var mGridSinLat;    // sin(lat) for each Y grid point
    private var mGridCosLat;    // cos(lat) for each Y grid point
    private var mGridLon;       // longitude for each X grid point (in radians for hour angle calc)
    private var mGridXCount;
    private var mGridYCount;

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

        // Build lookup tables
        buildLookupTables();
    }

    private function buildLookupTables() as Void {
        var degToRad = Math.PI / 180.0;

        mGridXCount = (mapWidth / GRID_STEP).toNumber();
        mGridYCount = (mapPixelHeight / GRID_STEP).toNumber();

        mGridSinLat = new [mGridYCount];
        mGridCosLat = new [mGridYCount];
        mGridLon = new [mGridXCount];

        // Pre-compute latitude trig values for each Y position
        for (var yi = 0; yi < mGridYCount; yi++) {
            var y = yi * GRID_STEP;
            var lat = 90.0 - (y.toFloat() / mapPixelHeight) * 180.0;
            var latRad = lat * degToRad;
            mGridSinLat[yi] = Math.sin(latRad);
            mGridCosLat[yi] = Math.cos(latRad);
        }

        // Pre-compute longitude (in degrees) for each X position
        for (var xi = 0; xi < mGridXCount; xi++) {
            var x = xi * GRID_STEP;
            mGridLon[xi] = (x.toFloat() / mapWidth) * 360.0 - 180.0;
        }
    }

    function draw(dc as Graphics.Dc) as Void {

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawTiles(
            mMapData[0],
            mMapFont,
            dc,
            mPositionX,
            mPositionY
        );

        drawDayNight(dc);
        
        if (gLocationLat != null) {
            var pixelLocation = latLonToPixel(gLocationLat, gLocationLng);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(mPositionX + pixelLocation[0], mPositionY, mPositionX + pixelLocation[0], mPositionY + mapPixelHeight);
            dc.drawLine(mPositionX, mPositionY + pixelLocation[1], mPositionX + mapWidth, mPositionY + pixelLocation[1]);
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

        if (lon < -180) { lon = -180; }
        if (lon > 180)  { lon = 180;  }

        if (lat > MAP_LAT_TOP)    { lat = MAP_LAT_TOP; }
        if (lat < MAP_LAT_BOTTOM) { lat = MAP_LAT_BOTTOM; }

        var xNorm = (lon + 180.0) / 360.0;

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
        
        var currentMinute = g.hour * 60 + g.min;
        if (currentMinute != mLastNightCalcMinute) {
            mLastNightCalcMinute = currentMinute;
            calculateNightOverlayOptimized(g);
        }
        
        dc.setFill(Graphics.createColor(128, 0, 0, 0));
        for (var i = 0; i < mNightOverlayPoints.size(); i++) {
            var point = mNightOverlayPoints[i];
            dc.fillRectangle(
                mPositionX + point[0],
                mPositionY + point[1],
                GRID_STEP,
                GRID_STEP
            );
        }
    }

    private function calculateNightOverlayOptimized(g) as Void {
        mNightOverlayPoints = [];
        
        // Day of year calculation
        var isLeapYear = (g.year % 4 == 0 && g.year % 100 != 0) || (g.year % 400 == 0);
        var daysInMonth = isLeapYear && g.month > 2
            ? [0,31,60,91,121,152,182,213,244,274,305,335]
            : [0,31,59,90,120,151,181,212,243,273,304,334];
        var doy = g.day + daysInMonth[g.month - 1];
        
        // Solar declination (only changes daily)
        var dayAngle = 2.0 * Math.PI * (doy - 80) / 365.0;
        var decl = 0.4093 * Math.sin(dayAngle);
        var sinDecl = Math.sin(decl);
        var cosDecl = Math.cos(decl);
        
        // Subsolar longitude (changes with time)
        var utcHours = g.hour + g.min / 60.0;
        var subLon = (12.0 - utcHours + 0.8) * 15.0;
        var degToRad = Math.PI / 180.0;

        // Pre-compute cosine of hour angle for each longitude
        var gridCosHourAngle = new [mGridXCount];
        for (var xi = 0; xi < mGridXCount; xi++) {
            var hourAngle = (mGridLon[xi] - subLon) * degToRad;
            gridCosHourAngle[xi] = Math.cos(hourAngle);
        }
        
        // Use lookup tables for fast iteration
        for (var xi = 0; xi < mGridXCount; xi++) {
            var x = xi * GRID_STEP;
            var cosHA = gridCosHourAngle[xi];
            
            for (var yi = 0; yi < mGridYCount; yi++) {
                var sinLat = mGridSinLat[yi];
                var cosLat = mGridCosLat[yi];
                
                var solarElevation = sinLat * sinDecl + cosLat * cosDecl * cosHA;
                
                if (solarElevation < 0.05) {
                    var y = yi * GRID_STEP;
                    mNightOverlayPoints.add([x, y]);
                }
            }
        }
    }
}
