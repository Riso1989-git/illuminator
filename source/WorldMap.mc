using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;

import Toybox.Application;

class WorldMap extends Ui.Drawable {

    // Packed tile bit masks
    const TILE_CHAR_MASK = 0x00000FFF;
    const TILE_X_MASK    = 0x003FF000;
    const TILE_Y_MASK    = 0xFFC00000;

    // Night overlay grid step (larger = faster but less precise)
    const GRID_STEP = 2;

    // Solar elevation threshold for civil twilight (sun ~6° below horizon)
    const TWILIGHT_THRESHOLD = 0.05;

    // Days in month lookup tables (avoid recreating arrays every frame)
    const DAYS_IN_MONTH_NORMAL = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    const DAYS_IN_MONTH_LEAP   = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335];

    private const DEG_TO_RAD = Math.PI / 180.0;

    /* =======================
     * Instance State
     * ======================= */

    private var mPositionX as Lang.Number;
    private var mPositionY as Lang.Number;
    private var mMapFont;
    private var mMapData as Lang.Array;

    // Projection dimensions
    private var mapWidth as Lang.Number;
    private var mapPixelHeight as Lang.Number;

    // Cached values
    private var mLastNightCalcMinute as Lang.Number = -1;
    private var mNightOverlayPoints as Lang.Array = [];  // Packed as (x << 16) | y

    // Pre-computed lookup tables
    private var mGridSinLat as Lang.Array = [];    // sin(lat) for each Y grid point
    private var mGridCosLat as Lang.Array = [];    // cos(lat) for each Y grid point
    private var mGridLon as Lang.Array = [];       // longitude for each X grid point
    private var mGridXCount as Lang.Number = 0;
    private var mGridYCount as Lang.Number = 0;

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

        // Build lookup tables
        buildLookupTables();
    }

    private function buildLookupTables() as Void {

        mGridXCount = (mapWidth / GRID_STEP).toNumber();
        mGridYCount = (mapPixelHeight / GRID_STEP).toNumber();

        mGridSinLat = new [mGridYCount];
        mGridCosLat = new [mGridYCount];
        mGridLon = new [mGridXCount];

        // Pre-compute latitude trig values for each Y position
        for (var yi = 0; yi < mGridYCount; yi++) {
            var y = yi * GRID_STEP;
            var lat = 90.0 - (y.toFloat() / mapPixelHeight) * 180.0;
            var latRad = lat * DEG_TO_RAD;
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

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawTiles(
            mMapData[0],
            mMapFont,
            dc,
            mPositionX,
            mPositionY
        );

        drawDayNight(dc);
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

    private function drawDayNight(dc as Graphics.Dc) as Void {
        var now = Time.now();
        var g = Gregorian.info(now, Time.FORMAT_SHORT);
        
        var currentMinute = g.hour * 60 + g.min;
        if (currentMinute != mLastNightCalcMinute) {
            mLastNightCalcMinute = currentMinute;
            calculateNightOverlayOptimized(g);
        }
        
        // check if device use alpha channel in drawing context
        var useAlpha = dc has :setFill;
        if (useAlpha) {
            dc.setFill(Graphics.createColor(128, 0, 0, 0));
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        }

        var step = useAlpha ? 1 : 2;
        
        for (var i = 0; i < mNightOverlayPoints.size(); i += step) {
            var packed = mNightOverlayPoints[i];
            var x = (packed >> 16) & 0xFFFF;
            var y = packed & 0xFFFF;
            dc.fillRectangle(
                mPositionX + x,
                mPositionY + y,
                GRID_STEP,
                GRID_STEP
            );
        }
    }

    /**
     * Calculate night overlay points using optimized lookup tables.
     * Uses solar position algorithm to determine which areas are in darkness.
     * @param g Gregorian time info (local time)
     */
    private function calculateNightOverlayOptimized(g as Gregorian.Info) as Void {
        mNightOverlayPoints = [];
        
        // Day of year calculation
        var isLeapYear = (g.year % 4 == 0 && g.year % 100 != 0) || (g.year % 400 == 0);
        var daysInMonth = isLeapYear ? DAYS_IN_MONTH_LEAP : DAYS_IN_MONTH_NORMAL;
        var doy = g.day + daysInMonth[g.month - 1];
        
        // Solar declination (only changes daily)
        var dayAngle = 2.0 * Math.PI * (doy - 80) / 365.0;
        var decl = 0.4093 * Math.sin(dayAngle);
        var sinDecl = Math.sin(decl);
        var cosDecl = Math.cos(decl);
        
        // Convert local time to UTC using device timezone offset
        var clockTime = System.getClockTime();
        var timezoneOffsetHours = clockTime.timeZoneOffset / 3600.0;
        var utcHours = g.hour + g.min / 60.0 - timezoneOffsetHours;

        // Subsolar longitude calculation
        // 12.0 = solar noon at 0° longitude
        // * 15.0 = degrees per hour (360° / 24h)
        var subLon = (12.0 - utcHours) * 15.0;

        // Pre-compute cosine of hour angle for each longitude
        var gridCosHourAngle = new [mGridXCount];
        for (var xi = 0; xi < mGridXCount; xi++) {
            var hourAngle = (mGridLon[xi] - subLon) * DEG_TO_RAD;
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
                
                if (solarElevation < TWILIGHT_THRESHOLD) {
                    var y = yi * GRID_STEP;
                    // Pack x and y into single integer to reduce memory allocations
                    mNightOverlayPoints.add((x << 16) | y);
                }
            }
        }
    }
}
