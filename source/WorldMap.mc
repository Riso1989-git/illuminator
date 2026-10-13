using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Time;

import Toybox.Lang;

// World map with a live day/night overlay.
//
// How it works (see docs/ANALYSIS.md, WM-1..WM-4, and docs/task.md T1.2/T1.3/T1.5):
//  * The sun position is computed from UTC epoch seconds (USNO "approximate solar
//    coordinates": declination + equation of time), every RECALC_SECONDS.
//  * For every map column the night part is exactly ONE contiguous latitude interval,
//    computed in closed form -> one span per column, no per-pixel loop, no allocation.
//  * Adjacent columns with the same span are merged into one rectangle when drawing.
//  * The composed map (tiles + overlay) is cached in a BufferedBitmap and only redrawn
//    when the spans change, so a high-power frame costs a single drawBitmap().
//
// The layout's width/height MUST equal the map artwork (140x70 on 390/416, 160x80 on 454),
// otherwise latitudes/longitudes are scaled wrongly (this was the Antarctica bug).
class WorldMap extends Ui.Drawable {

    // ---- tuning ---------------------------------------------------------------------------

    // sin(-0.833 deg): sun's upper limb on the horizon incl. refraction (sunrise/sunset)
    private const NIGHT_SIN_ALT = -0.01454;
    // sin(-6 deg): end of civil twilight
    private const TWILIGHT_SIN_ALT = -0.10453;

    // T1.5 (Q3): civil-twilight band. true = twilight 25 % dark, night 50 % dark.
    // false = hard edge, night 50 % dark (previous look). Flip to false if the band
    // doesn't look right on the watch.
    private const SHOW_TWILIGHT = true;

    // T1.3: cache the composed map in a BufferedBitmap. Flip to false if the overlay
    // doesn't render correctly inside the bitmap on some device.
    private const USE_BITMAP_CACHE = true;

    // The terminator moves ~1 px every 9-10 minutes on a 140-160 px wide map.
    private const RECALC_SECONDS = 300;

    // Packed tile format from tilemapper: char | x << 12 | y << 22
    private const TILE_CHAR_MASK = 0xFFF;
    private const TILE_POS_MASK  = 0x3FF;

    // ---- state ----------------------------------------------------------------------------

    private var mX as Number;
    private var mY as Number;
    private var mW as Number;
    private var mH as Number;
    private var mFont;
    private var mTiles as Array<Number>;

    // Per column: (top << 8) | bottom of the dark interval, -1 = no darkness in that column
    private var mNightSpans as Array<Number>;      // sun below -0.833 deg
    private var mDeepSpans as Array<Number>;       // sun below -6 deg (only with SHOW_TWILIGHT)
    private var mLastCalc as Number = 0;

    private var mUseAlpha as Boolean = false;
    private var mFillOuter = null;                 // drawn over mNightSpans
    private var mFillInner = null;                 // drawn over mDeepSpans

    private var mBufRef = null;                    // Graphics.BufferedBitmapReference
    private var mBufValid as Boolean = false;

    typedef WorldMapParams as {
        :positionX as Number,
        :positionY as Number,
        :width     as Number,
        :height    as Number
    };

    function initialize(params as WorldMapParams) {
        Drawable.initialize({ :identifier => "WorldMap" });

        mX = params[:positionX] as Number;
        mY = params[:positionY] as Number;
        mW = params[:width] as Number;
        mH = params[:height] as Number;

        mFont = Ui.loadResource(Rez.Fonts.worldMap);
        mTiles = (Ui.loadResource(Rez.JsonData.worldMapJson) as Array<Array<Number>>)[0];

        mNightSpans = new Array<Number>[mW];
        mDeepSpans = new Array<Number>[mW];
        for (var i = 0; i < mW; i++) {
            mNightSpans[i] = -1;
            mDeepSpans[i] = -1;
        }

        mUseAlpha = (Graphics has :createColor);
        if (mUseAlpha) {
            if (SHOW_TWILIGHT) {
                // two layers: 25 % over all darkness, +1/3 over deep night -> 50 % total
                mFillOuter = Graphics.createColor(64, 0, 0, 0);
                mFillInner = Graphics.createColor(85, 0, 0, 0);
            } else {
                mFillOuter = Graphics.createColor(128, 0, 0, 0);
            }
        }
    }

    // ---- drawing --------------------------------------------------------------------------

    function draw(dc as Graphics.Dc) as Void {
        if (updateSpansIfNeeded()) {
            mBufValid = false;
        }

        if (USE_BITMAP_CACHE && (Graphics has :createBufferedBitmap)) {
            if (mBufRef == null) {
                mBufRef = Graphics.createBufferedBitmap({ :width => mW, :height => mH });
                mBufValid = false;
            }
            var bb = mBufRef.get();                // null if the graphics pool purged it
            if (bb != null) {
                if (!mBufValid) {
                    var bdc = bb.getDc();
                    bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                    bdc.clear();
                    drawMap(bdc, 0, 0);
                    mBufValid = true;
                }
                dc.drawBitmap(mX, mY, mBufRef);
                return;
            }
            mBufRef = null;                        // re-create on the next frame
        }

        drawMap(dc, mX, mY);
    }

    // Returns true when the spans were recomputed.
    function updateSpansIfNeeded() as Boolean {
        var now = Time.now().value();
        if (now - mLastCalc >= RECALC_SECONDS || now < mLastCalc) {
            mLastCalc = now;
            computeSpans(now);
            return true;
        }
        return false;
    }

    // Map tiles in white plus the night overlay, with the map's top-left at (ox, oy).
    function drawMap(dc as Graphics.Dc, ox as Number, oy as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawTiles(dc, ox, oy);

        if (mUseAlpha && (dc has :setFill)) {
            dc.setFill(mFillOuter);
            fillSpans(dc, mNightSpans, ox, oy);
            if (SHOW_TWILIGHT) {
                dc.setFill(mFillInner);
                fillSpans(dc, mDeepSpans, ox, oy);
            }
        } else {
            // No alpha: redraw the land in dark grey clipped to the night spans
            // (the ocean stays black).
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            var x = 0;
            while (x < mW) {
                var s = mNightSpans[x];
                var x2 = runEnd(mNightSpans, x);
                if (s >= 0) {
                    var top = s >> 8;
                    dc.setClip(ox + x, oy + top, x2 - x, (s & 0xFF) - top + 1);
                    drawTiles(dc, ox, oy);
                }
                x = x2;
            }
            dc.clearClip();
        }
    }

    // T2.1 always-on version: land in dark grey, night side erased to black, so only
    // the day land is lit (~2 % of the display). Drawn directly (no bitmap cache),
    // shifted by the burn-in offset (dx, dy).
    function drawDimmed(dc as Graphics.Dc, dx as Number, dy as Number) as Void {
        if (updateSpansIfNeeded()) {
            mBufValid = false;
        }
        var ox = mX + dx;
        var oy = mY + dy;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        drawTiles(dc, ox, oy);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        if (dc has :setFill) {
            dc.setFill(Graphics.COLOR_BLACK);      // in case an alpha fill is still set
        }
        fillSpans(dc, mNightSpans, ox, oy);
    }

    private function drawTiles(dc as Graphics.Dc, ox as Number, oy as Number) as Void {
        for (var i = 0; i < mTiles.size(); i++) {
            var p = mTiles[i];
            if (p == null) {
                continue;
            }
            dc.drawText(
                ox + ((p >> 12) & TILE_POS_MASK),
                oy + ((p >> 22) & TILE_POS_MASK),
                mFont,
                (p & TILE_CHAR_MASK).toChar(),
                Graphics.TEXT_JUSTIFY_LEFT
            );
        }
    }

    // One rectangle per run of equal neighbouring columns.
    private function fillSpans(dc as Graphics.Dc, spans as Array<Number>, ox as Number, oy as Number) as Void {
        var x = 0;
        while (x < mW) {
            var s = spans[x];
            var x2 = runEnd(spans, x);
            if (s >= 0) {
                var top = s >> 8;
                dc.fillRectangle(ox + x, oy + top, x2 - x, (s & 0xFF) - top + 1);
            }
            x = x2;
        }
    }

    private function runEnd(spans as Array<Number>, x as Number) as Number {
        var s = spans[x];
        var x2 = x + 1;
        while (x2 < mW && spans[x2] == s) {
            x2++;
        }
        return x2;
    }

    // ---- astronomy ------------------------------------------------------------------------

    // t = UTC epoch seconds (Time.now().value()).
    private function computeSpans(t as Number) as Void {
        var d = t / 86400.0d - 10957.5d;                                  // days since J2000.0
        var g = Math.toRadians(wrap360(357.529d + 0.98560028d * d));     // mean anomaly
        var q = wrap360(280.459d + 0.98564736d * d);                     // mean longitude [deg]
        var lam = Math.toRadians(q + 1.915d * Math.sin(g) + 0.020d * Math.sin(2 * g));
        var eps = Math.toRadians(23.439d - 0.00000036d * d);             // obliquity
        var ra = Math.toDegrees(Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam)));
        var decl = Math.asin(Math.sin(eps) * Math.sin(lam));
        var eotMin = 4.0d * (wrap360(q - ra + 180.0d) - 180.0d);         // equation of time [min]
        var subLon = -15.0d * ((t % 86400) / 3600.0d - 12.0d + eotMin / 60.0d);

        var sinDecl = Math.sin(decl);
        var cosDecl = Math.cos(decl);
        fillColumnSpans(mNightSpans, sinDecl, cosDecl, subLon, NIGHT_SIN_ALT);
        if (SHOW_TWILIGHT) {
            fillColumnSpans(mDeepSpans, sinDecl, cosDecl, subLon, TWILIGHT_SIN_ALT);
        }
    }

    // Sun elevation along a column: a*sin(lat) + b*cos(lat) = r*sin(lat + psi).
    // For sinAlt <= 0 the set {elevation < sinAlt} is one interval centred on the
    // darkest latitude (3*pi/2 - psi) with half-width pi/2 + asin(sinAlt / r).
    private function fillColumnSpans(out as Array<Number>, a, cosDecl, subLon, sinAlt) as Void {
        var halfPi = Math.PI / 2;
        for (var x = 0; x < mW; x++) {
            out[x] = -1;
            var lon = (x + 0.5d) * 360.0d / mW - 180.0d;
            var b = cosDecl * Math.cos(Math.toRadians(lon - subLon));
            var r = Math.sqrt(a * a + b * b);
            if (r < 0.000001d || sinAlt / r <= -1.0d) {
                continue;                                                 // never dark here
            }
            var half = halfPi + Math.asin(sinAlt / r);
            var c = wrapPi(3 * halfPi - Math.atan2(b, a));
            var latLo = c - half;
            var latHi = c + half;
            if (latLo < -halfPi) { latLo = -halfPi; }
            if (latHi > halfPi) { latHi = halfPi; }
            if (latLo >= latHi) {
                continue;
            }
            // row y covers latitude 90 - (y + 0.5) * 180 / H at its centre
            var y0 = Math.ceil((halfPi - latHi) / Math.PI * mH - 0.5d).toNumber();
            var y1 = Math.floor((halfPi - latLo) / Math.PI * mH - 0.5d).toNumber();
            if (y0 < 0) { y0 = 0; }
            if (y1 > mH - 1) { y1 = mH - 1; }
            if (y0 <= y1) {
                out[x] = (y0 << 8) | y1;
            }
        }
    }

    private function wrap360(v) {
        return v - 360.0d * Math.floor(v / 360.0d);
    }

    private function wrapPi(v) {                                          // -> [-PI, PI)
        var twoPi = 2 * Math.PI;
        return v - twoPi * Math.floor((v + Math.PI) / twoPi);
    }
}
