# Illuminator: implementation tasks

This file turns the findings in [`ANALYSIS.md`](ANALYSIS.md) into tasks you can implement one at a time. Each task lists:

- **Priority:** P0 (do first) to P4 (nice to have)
- **Depends on:** tasks that should be finished first
- **Files** it touches
- **Steps** and code you can paste
- **Done when:** the acceptance criteria

The code is written against the current sources but has **not been compiled**, so expect to fix small typing or annotation issues when you build. Problem IDs such as `WM-1` and `AOD-2` refer to sections in `ANALYSIS.md`.

**Global definition of done for every task**
- The project builds for all 21 products in `manifest.xml` with no new warnings.
- The face runs in the simulator on one 416 device (venu2) and one 454 device (fr965), in both high-power and low-power mode.
- Setting IDs and values that already exist stay compatible, because published users have saved settings.

---

## 0. Decisions on the open questions

You answered the 11 open questions in `ANALYSIS.md` §6. The tasks below follow those answers.

| # | Question | Your answer | What changes in the tasks | Task |
|---|---|---|---|---|
| Q1 | What happens at the "crash"? | A store user reported that it crashes with always-on enabled. There are no more details. | **ERA is the main evidence source**, because the report came from a store install. The logging build is for reproducing it on your own watch. All four suspects are removed by T1.2, T2.1 and T3.1 regardless. | T0.2 |
| Q2 | What should AOD show? | **Time + date + analogue hands + dimmed map**, nothing else. | T2.1 extended. The estimate is ≈8.3 % lit pixels (time 5.1, map day land 2.1, date 0.6, hands 0.6), which is under 10 % but tight. T2.1 includes a fallback in case the heat map shows more. | T2.1 |
| Q3 | Night style | Keep the 50 % grey. Add a civil-twilight band if it works well; otherwise keep the hard edge. | T1.5 promoted to P2 as "try it". | T1.2, T1.5 |
| Q4 | "You are here" marker | No, it was for debugging only. | T1.4 dropped. | — |
| Q5 | Seconds | A setting should hide them. | T2.5 as planned (default: shown). Never drawn in AOD. | T2.5 |
| Q6 | Require Connect IQ 4.x | Yes. | `minApiLevel="4.0.0"`. BufferedBitmap (T1.3) can be relied on, and the `has` check stays as cheap insurance. | T4.1, T1.3 |
| Q7 | Data sources | Remove the thermometer. Compute sunrise/sunset in our own code. | T3.2 rewritten to **fix the own algorithm** (time zone offsets with :30/:45, polar cases, cache invalidation) instead of using `Weather.getSunrise`. T3.5 removes the thermometer field. | T3.2, T3.5 |
| Q8 | Second time zone | Works fine as is: no DST, it only shows time on the analogue clock. | T3.7 dropped. Only the per-frame property read in `Analogue` is cached (T2.4). | — |
| Q9 | Leftover properties | Remove them. | T4.2 as planned. | T4.2 |
| Q10 | 390×390 devices | Support them. | **New task T4.5**: add the 390 products and a real 390 layout. The current 390 layout is a copy of the 416 one and doesn't fit. | T4.5 |
| Q11 | Is the store build this working copy? | Yes. | ERA stack traces can be read directly against the current `main`, before any T1+ changes. | T0.2 |

---

## Phase 0: safety, diagnosis and baseline

### T0.1 Commit the untracked design work · P0 · 5 min
**Why:** `resources-round-454x454/` and `resources-round-390x390/` are not in git (HYG-1). The 454 design exists only on this laptop.

**Steps**
1. Add a `.gitignore` in the project root:
   ```gitignore
   bin/
   *.der
   *.prg
   *.iq
   ```
2. Commit and push:
   ```bash
   git add .gitignore resources-round-454x454 resources-round-390x390 docs
   git commit -m "Add 454/390 resources, docs, gitignore"
   git push
   ```

**Done when:** `git status` is clean apart from `bin/`, and GitHub shows the 454 folder.

> **Status (13 Oct 2026):** `.gitignore` written; it ignores `bin/`, `*.prg`, `*.iq`, `*.der`/`*.pem` and `source/*.code-workspace`. **Your step:** run the git commands above. I can't run git on your machine.

### T0.2 Collect crash evidence · P0 · 15 min + waiting · ⚠ needs you
**Why:** the AOD crash (AOD-2) can't be proven from code.

**Steps**
1. **Store build:** open the ERA (Exception Reporting App) viewer from the Connect IQ SDK and select Illuminator. Note the error type, for example `Out Of Memory Error`, `Watchdog Tripped Error` or `Unexpected Type Error`, plus the stack, device, firmware and app version.
2. **Sideloaded build:** connect the watch over USB and copy `GARMIN\APPS\LOGS\CIQ_LOG.YML` (or `.BAK`).
3. **Memory trend:** sideload a build with this temporary code in `IlluminatorView.onUpdate`, and create an empty `GARMIN\APPS\LOGS\<PRGNAME>.TXT` so `println` output is kept:
   ```monkeyc
   (:debug) var gLastMemLog = 0;
   ...
   var now = Time.now().value();
   if (now - gLastMemLog >= 3600) {
       gLastMemLog = now;
       var s = System.getSystemStats();
       System.println(now + " used=" + s.usedMemory + " free=" + s.freeMemory);
   }
   ```
   Run it in AOD for 2–3 days.
4. Write the result into `ANALYSIS.md` §2.2 (which hypothesis it was) and into Q1 above.

**Done when:** the error type is known, or 3 days of memory logs exist. A rising `used` floor confirms the heap-churn hypothesis.

> **Status (13 Oct 2026):** the logging is implemented in `source/IlluminatorView.mc` as `logDiagnostics()`.
> - It is annotated `(:debug)`, with a `(:release)` no-op twin, so store builds don't contain it.
> - It logs one line at start-up (`START`) and one per hour (`HOUR`) with `used`, `free` and `total` memory, battery % and the low-power flag.
> - A `START` line that appears without you reinstalling or switching faces means the face was restarted, i.e. it crashed.
>
> **Q1/Q11:** the crash came from a store user and the store build equals this code, so **ERA is the first and most useful step**. Filter by Illuminator and look for entries on devices with AOD.
>
> **Your steps:**
> 1. Check ERA for the store build.
> 2. Build for your device (debug) and copy `bin\Casio.prg` to `GARMIN\APPS\`.
> 3. Create an empty `GARMIN\APPS\LOGS\CASIO.TXT`.
> 4. Wear the watch in AOD for 2–3 days.
> 5. Copy back `CASIO.TXT` and `CIQ_LOG.YML` (or `.BAK`).

### T0.3 Measure a baseline · P0 · 1 h + 24 h waiting
**Why:** without numbers you can't tell whether the fixes helped.

**Steps**
1. **Simulator (venu2), low-power mode with the screen heat map:** record the % of lit pixels. ANALYSIS.md estimated ≈19 %.
2. **Simulator memory viewer:** record peak memory in high power over 2 minutes.
3. **Watch:** charge to 100 %, enable AOD, keep brightness and settings fixed, and record battery % after 24 h. Repeat later with the fixed build.

**Done when:** the three numbers are written in a "Baseline" table at the bottom of this file.

> **Status (13 Oct 2026):** the T0.2 log also records battery % every hour, so the 24 h AOD drain can be read from `CASIO.TXT` without separate notes. **Your steps:** the simulator heat-map % and peak memory (steps 1–2) need the simulator on your machine; I can't run it from here.

---

## Phase 1: world map

### T1.1 Correct the map size in the layouts · P1 · 5 min
**Fixes:** WM-1, the Antarctica bug.

**Files:** `resources-round-416x416/layouts/layout.xml`, `resources-round-390x390/layouts/layout.xml`, `resources-round-454x454/layouts/layout.xml`

**Steps**
```xml
<!-- 416 and 390 -->
<param name="width">140</param>
<param name="height">70</param>   <!-- was 60 -->

<!-- 454 -->
<param name="width">160</param>   <!-- was 150 -->
<param name="height">80</param>   <!-- was 70 -->
```
Add a comment above the drawable: `<!-- must equal the worldMap artwork size (tilemapper -r value x half) -->`. The `-r` value in `fonts/py` is the map width: 140 on 416, 160 on 454.

> Do T1.1 together with T1.2. On its own, T1.1 raises the night cells per frame to about 1,360/1,780 (WM-4).

**Done when:** in the simulator on 21 Jun, Antarctica is shaded. On 454, Fiji and NZ get shaded at their local night.

### T1.2 Rewrite `WorldMap.mc`: one night span per column · P1 · 2–3 h
**Depends on:** T1.1
**Fixes:** WM-2, WM-3 and WM-4, plus the main crash suspect (no allocations at runtime).

**Files:** `source/WorldMap.mc` (full replacement)

**Steps**
1. Replace the file with the code below.
2. Delete `GRID_STEP`, `TWILIGHT_THRESHOLD`, the `DAYS_IN_MONTH_*` tables and the lookup-table code. Nothing else uses them.

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class WorldMap extends WatchUi.Drawable {

    // sin(-0.833 deg): sun's upper limb on the horizon incl. refraction (sunrise/sunset)
    private const NIGHT_SIN_ALT = -0.01454;
    // terminator moves ~1 px per 9-10 min on a 140-160 px map
    private const RECALC_SECONDS = 300;

    private var mX as Number;
    private var mY as Number;
    private var mW as Number;
    private var mH as Number;
    private var mFont;
    private var mTiles as Array<Number>;
    private var mSpans as Array<Number>;     // per column: (top << 8) | bottom; -1 = no night
    private var mLastCalc as Number = 0;
    private var mUseAlpha as Boolean = false;
    private var mNightFill = null;

    function initialize(params as Dictionary) {
        Drawable.initialize({ :identifier => "WorldMap" });
        mX = params[:positionX] as Number;
        mY = params[:positionY] as Number;
        mW = params[:width] as Number;
        mH = params[:height] as Number;
        mFont = WatchUi.loadResource(Rez.Fonts.worldMap);
        mTiles = (WatchUi.loadResource(Rez.JsonData.worldMapJson) as Array<Array<Number>>)[0];
        mSpans = new Array<Number>[mW];
        for (var i = 0; i < mW; i++) { mSpans[i] = -1; }
        mUseAlpha = (Graphics has :createColor);
        if (mUseAlpha) { mNightFill = Graphics.createColor(128, 0, 0, 0); }
    }

    function draw(dc as Graphics.Dc) as Void {
        updateSpansIfNeeded();
        drawMap(dc, mX, mY);
    }

    // Public so the bitmap cache (T1.3) and AOD variants can reuse it.
    function updateSpansIfNeeded() as Boolean {
        var now = Time.now().value();
        if (now - mLastCalc >= RECALC_SECONDS || now < mLastCalc) {
            mLastCalc = now;
            computeSpans(now);
            return true;
        }
        return false;
    }

    function drawMap(dc as Graphics.Dc, ox as Number, oy as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawTiles(dc, ox, oy);

        if (mUseAlpha && (dc has :setFill)) {
            dc.setFill(mNightFill);
            var x = 0;
            while (x < mW) {                                // merge equal neighbouring columns
                var s = mSpans[x];
                var x2 = x + 1;
                while (x2 < mW && mSpans[x2] == s) { x2++; }
                if (s >= 0) {
                    var top = s >> 8;
                    dc.fillRectangle(ox + x, oy + top, x2 - x, (s & 0xFF) - top + 1);
                }
                x = x2;
            }
        } else {
            // No alpha: redraw land in dark grey, clipped to the night spans (ocean stays black).
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            var x = 0;
            while (x < mW) {
                var s = mSpans[x];
                var x2 = x + 1;
                while (x2 < mW && mSpans[x2] == s) { x2++; }
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

    private function drawTiles(dc as Graphics.Dc, ox as Number, oy as Number) as Void {
        for (var i = 0; i < mTiles.size(); i++) {
            var p = mTiles[i];
            dc.drawText(ox + ((p >> 12) & 0x3FF), oy + ((p >> 22) & 0x3FF),
                        mFont, (p & 0xFFF).toChar(), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Sun position: USNO "approximate solar coordinates". t = UTC epoch seconds.
    private function computeSpans(t as Number) as Void {
        var d = t / 86400.0d - 10957.5d;                           // days since J2000.0
        var g = Math.toRadians(wrap360(357.529d + 0.98560028d * d));
        var q = wrap360(280.459d + 0.98564736d * d);
        var lam = Math.toRadians(q + 1.915d * Math.sin(g) + 0.020d * Math.sin(2 * g));
        var eps = Math.toRadians(23.439d - 0.00000036d * d);
        var ra = Math.toDegrees(Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam)));
        var decl = Math.asin(Math.sin(eps) * Math.sin(lam));
        var eotMin = 4.0d * (wrap360(q - ra + 180.0d) - 180.0d);   // equation of time [min]
        var subLon = -15.0d * ((t % 86400) / 3600.0d - 12.0d + eotMin / 60.0d);

        var a = Math.sin(decl);
        var cd = Math.cos(decl);
        var halfPi = Math.PI / 2;
        for (var x = 0; x < mW; x++) {
            mSpans[x] = -1;
            var lon = (x + 0.5d) * 360.0d / mW - 180.0d;
            var b = cd * Math.cos(Math.toRadians(lon - subLon));
            var r = Math.sqrt(a * a + b * b);
            if (r < 0.000001d || NIGHT_SIN_ALT / r <= -1.0d) { continue; }
            var half = halfPi + Math.asin(NIGHT_SIN_ALT / r);
            var c = wrapPi(3 * halfPi - Math.atan2(b, a));        // latitude of darkest point
            var latLo = c - half;
            var latHi = c + half;
            if (latLo < -halfPi) { latLo = -halfPi; }
            if (latHi > halfPi) { latHi = halfPi; }
            if (latLo >= latHi) { continue; }
            var y0 = Math.ceil((halfPi - latHi) / Math.PI * mH - 0.5d).toNumber();
            var y1 = Math.floor((halfPi - latLo) / Math.PI * mH - 0.5d).toNumber();
            if (y0 < 0) { y0 = 0; }
            if (y1 > mH - 1) { y1 = mH - 1; }
            if (y0 <= y1) { mSpans[x] = (y0 << 8) | y1; }
        }
    }

    private function wrap360(v) { return v - 360.0d * Math.floor(v / 360.0d); }

    private function wrapPi(v) {                                    // -> [-PI, PI)
        var twoPi = 2 * Math.PI;
        return v - twoPi * Math.floor((v + Math.PI) / twoPi);
    }
}
```

**Notes**
- The algorithm was validated in Python against a per-pixel brute force: 278 M pixel checks over 2026, 0 mismatches (ANALYSIS.md Appendix A).
- If the type checker complains about `Math.floor`/`Math.ceil` return types, wrap the values in `.toDouble()` or `.toNumber()`.

**Done when**
- The simulator matches a reference day/night map (for example timeanddate.com) on the dates in T5.1, within 1–2 px.
- The memory viewer shows no growth over 30 simulated minutes.
- Draw calls for the map are 24–28 tiles plus at most about 90 rectangles.

### T1.3 Cache the composed map in a BufferedBitmap · P3 · 1–2 h
**Depends on:** T1.2
**Why:** the map changes every 5 min but is drawn every second in high power. With a cached bitmap the cost per frame is one bitmap draw.

**Files:** `source/WorldMap.mc`

```monkeyc
private var mBufRef = null;            // Graphics.BufferedBitmapReference
private var mBufValid as Boolean = false;

function draw(dc as Graphics.Dc) as Void {
    if (updateSpansIfNeeded()) { mBufValid = false; }

    if (Graphics has :createBufferedBitmap) {
        if (mBufRef == null) {
            mBufRef = Graphics.createBufferedBitmap({ :width => mW, :height => mH });
            mBufValid = false;
        }
        var bb = mBufRef.get();                 // may be null if the graphics pool purged it
        if (bb == null) {
            mBufRef = null;
            drawMap(dc, mX, mY);
            return;
        }
        if (!mBufValid) {
            var bdc = bb.getDc();
            bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bdc.clear();
            drawMap(bdc, 0, 0);
            mBufValid = true;
        }
        dc.drawBitmap(mX, mY, mBufRef);
    } else {
        drawMap(dc, mX, mY);
    }
}
```

**Check in the simulator:**
- alpha fills render inside the buffer on both resolutions
- the memory viewer shows the buffer coming from the graphics pool, not the app heap

If alpha doesn't work inside the buffer, force the clip branch of `drawMap` for the buffer by passing a flag.

**Done when:** the face looks identical to T1.2, the profiler shows the map's per-frame cost dropping to one `drawBitmap`, and memory is stable.

### T1.4 ~~"You are here" marker~~ · dropped (Q4)
Not wanted; the marker was only for debugging.

### T1.5 Civil-twilight band (try it) · P2 · 30–60 min
**Depends on:** T1.2

**Steps**
1. Add a second span array computed with `sin(-6°) = -0.10453`, in a second loop of `computeSpans` with the threshold as a parameter.
2. Draw it before the night spans with alpha 64.
3. **Q3:** try it on both resolutions. Keep it only if the band reads as a clean, lighter strip at 1-px column resolution. If it looks noisy or muddy, drop it and keep the hard edge; no setting is needed either way.

**Done when:** a lighter band about 6° wide shows on the day side of the terminator.

---

## Phase 2: always-on mode and frame budget

### T2.1 Real low-power (AOD) rendering path · P1 · 2–3 h
**Fixes:** AOD-1, and the battery and burn-in items.
**Decision:** Q2. Show time + date + analogue hands + dimmed map, shifted every minute. Steps 1–3 build the time and date part; step 4 adds the hands and map.

**Files**
- `source/IlluminatorView.mc`
- new `source/AodFace.mc`
- the three round `layouts/layout.xml` files

**Step 1: add an AOD layout to each round `layout.xml`.** Positions are per resolution. Start with the TimeField and DateField positions and tune them in the simulator.
```xml
<layout id="AlwaysOn">
    <drawable id="AodDisplay" class="AodFace">
        <param name="timeX">25</param>   <!-- 454: 35 -->
        <param name="timeY">220</param>  <!-- 454: 240 -->
        <param name="dateX">195</param>  <!-- 454: 214 -->
        <param name="dateY">110</param>  <!-- 454: 130 -->
    </drawable>
</layout>
```

**Step 2: create `source/AodFace.mc`.**
```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class AodFace extends WatchUi.Drawable {
    private const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    private var mTimeX as Number;
    private var mTimeY as Number;
    private var mDateX as Number;
    private var mDateY as Number;

    function initialize(params as Dictionary) {
        Drawable.initialize({ :identifier => "AodFace" });
        mTimeX = params[:timeX] as Number;
        mTimeY = params[:timeY] as Number;
        mDateX = params[:dateX] as Number;
        mDateY = params[:dateY] as Number;
        Res.load();                                   // T2.3
    }

    function draw(dc as Graphics.Dc) as Void {
        var t = System.getClockTime();
        // burn-in: wander inside a 7x7 px box, new position every minute (49-min cycle)
        var dx = (t.min % 7) - 3;
        var dy = ((t.min / 7) % 7) - 3;

        var h = t.hour;
        if (!Cache.settings.is24Hour) { h = (h % 12 == 0) ? 12 : h % 12; }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mTimeX + dx, mTimeY + dy, Res.bigFont,
                    h.format("%02d") + ":" + t.min.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);

        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mDateX + dx, mDateY + dy, Res.textFont,
                    DAYS[g.day_of_week - 1] + " " + g.day.format("%02d") + "-" + g.month.format("%02d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
    }
}
```

**Step 3: update `IlluminatorView.mc`** (replace `is_lowpower` and the unused `deviceSettings`).
```monkeyc
private var mLowPower as Boolean = false;
private var mBurnIn as Boolean = false;
private var mAod as Array<WatchUi.Drawable>?;

function onLayout(dc as Dc) as Void {
    var ds = System.getDeviceSettings();
    mBurnIn = (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
    setLayout(Rez.Layouts.WatchFace(dc));
    mAod = Rez.Layouts.AlwaysOn(dc);
    // ... findDrawableById calls as today
}

function onUpdate(dc as Dc) as Void {
    Cache.refresh();                                  // T2.4
    dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
    dc.clear();
    if (mLowPower && mBurnIn && mAod != null) {
        for (var i = 0; i < mAod.size(); i++) { mAod[i].draw(dc); }
        return;
    }
    View.onUpdate(dc);
}

function onEnterSleep() as Void { mLowPower = true;  WatchUi.requestUpdate(); }
function onExitSleep()  as Void { mLowPower = false; WatchUi.requestUpdate(); }
```

**Done when**
- The simulator heat map in low-power mode shows **< 10 %** lit pixels (target ≈6 %) on both resolutions, with no stuck-pixel warnings over 24 simulated hours.
- On the watch, AOD shows the dimmed time and date, not a black screen, and the full face returns instantly on wrist raise.
- The T0.3 battery test, repeated, shows lower 24 h AOD drain. Record the number.

**Step 4 (Q2): add the analogue hands and a dimmed map to AOD.** Both use the same burn-in shift as the time.

Make the view compute the shift once and pass it to every AOD element:
```monkeyc
// IlluminatorView.onUpdate, low-power branch (replaces the loop over mAod)
if (mLowPower && mBurnIn) {
    var m = System.getClockTime().min;
    var dx = (m % 7) - 3;
    var dy = ((m / 7) % 7) - 3;
    if (worldMapDrawable != null) { worldMapDrawable.drawDimmed(dc, dx, dy); }
    if (analogueDrawable != null) { analogueDrawable.drawHandsOnly(dc, dx, dy); }
    if (mAodFace != null)         { mAodFace.drawShifted(dc, dx, dy); }   // time + date
    return;
}
```
`AodFace.draw()` becomes `drawShifted(dc, dx, dy)` and loses its own `dx`/`dy` calculation. Keep a typed reference instead of the array: `mAodFace = Rez.Layouts.AlwaysOn(dc)[0] as AodFace;`.

Add to `WorldMap.mc` (after T1.2). It draws the day land in dark grey and erases the night side, so only about half the land is lit:
```monkeyc
function drawDimmed(dc as Graphics.Dc, dx as Number, dy as Number) as Void {
    updateSpansIfNeeded();
    var ox = mX + dx;
    var oy = mY + dy;
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    drawTiles(dc, ox, oy);
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
    var x = 0;
    while (x < mW) {
        var s = mSpans[x];
        var x2 = x + 1;
        while (x2 < mW && mSpans[x2] == s) { x2++; }
        if (s >= 0) {
            var top = s >> 8;
            dc.fillRectangle(ox + x, oy + top, x2 - x, (s & 0xFF) - top + 1);   // night = black
        }
        x = x2;
    }
}
```

Add to `Analogue.mc`. Move the body of `drawHands` into a helper that takes an offset and a colour, so the normal face and AOD share it:
```monkeyc
private function drawHands(dc as Gfx.Dc) as Void {
    drawHandsAt(dc, posX, posY, Gfx.COLOR_WHITE);
}

function drawHandsOnly(dc as Gfx.Dc, dx as Lang.Number, dy as Lang.Number) as Void {
    drawHandsAt(dc, posX + dx, posY + dy, Gfx.COLOR_LT_GRAY);     // no dial in AOD
}

private function drawHandsAt(dc as Gfx.Dc, x as Lang.Number, y as Lang.Number, color) as Void {
    // = current drawHands() body, with posX/posY replaced by x/y
    // and dc.setColor(color, Gfx.COLOR_TRANSPARENT) instead of COLOR_WHITE
}
```

**Pixel budget for Q2** (416 render, 17:50, ANALYSIS.md method):

| Element | Lit pixels |
|---|---|
| Time HH:MM | 5.1 % |
| Map, day land only, dark grey | 2.1 % (varies with how much land is in daylight; up to ≈3 %) |
| Date | 0.6 % |
| Hands (no dial) | 0.6 % |
| **Total** | **≈8.3 %**, worst case ≈9–9.5 % |

**If the simulator heat map reports more than 10 %**, apply these in order until it fits:
1. Scanline the map: after `drawDimmed`, draw a black horizontal line on every other row (`dc.drawLine` 35–40 times). This halves the map's pixels.
2. Draw the date only in high power.
3. Use the medium font for the AOD time.

### T2.2 Reserved
Burn-in shifting is already part of T2.1. This ID is left free.

### T2.3 Load each resource once · P2 · 45 min
**Fixes:** fonts loaded 4× (§2.3).

**Files**
- new `source/Res.mc`
- `DataFields.mc`, `GoalMeter.mc`, `DateField.mc`, `TimeField.mc`

```monkeyc
// source/Res.mc
import Toybox.Lang;
import Toybox.WatchUi;

module Res {
    var textFont = null;
    var iconFont = null;
    var bigFont = null;
    var mediumFont = null;

    function load() as Void {
        if (textFont != null) { return; }
        textFont   = WatchUi.loadResource(Rez.Fonts.text);
        iconFont   = WatchUi.loadResource(Rez.Fonts.garmin_icons);
        bigFont    = WatchUi.loadResource(Rez.Fonts.text_big);
        mediumFont = WatchUi.loadResource(Rez.Fonts.text_medium);
    }
}
```
In each drawable's `initialize`, call `Res.load()` and replace its own `loadResource` calls with `Res.textFont`, `Res.iconFont` and so on.

**Done when:** a search for `loadResource(Rez.Fonts.text)` and `garmin_icons` finds exactly one occurrence each (in `Res.mc`), and peak memory is lower than the T0.3 baseline.

### T2.4 Per-minute caching, no allocations per frame · P2 · 2 h
**Fixes:** §2.3: the Dictionary per field, `getDeviceSettings()` ×7, property reads, SensorHistory iterators.

**Files**
- new `source/Cache.mc`
- `DataFields.mc`, `TimeField.mc`, `Analogue.mc`, `GoalMeter.mc`, `MoveBar.mc`

**Step 1: create `source/Cache.mc`.** It is refreshed once per frame from `onUpdate` (T2.1) but recomputes only when the minute changes.
```monkeyc
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;

module Cache {
    var minuteKey as Number = -1;
    var settings = null;          // System.DeviceSettings
    var activity = null;          // ActivityMonitor.Info
    var changed as Boolean = true;

    function refresh() as Void {
        var ct = System.getClockTime();
        var key = ct.hour * 60 + ct.min;
        changed = (key != minuteKey);
        if (changed) {
            minuteKey = key;
            settings = System.getDeviceSettings();
            activity = ActivityMonitor.getInfo();
        }
    }

    function invalidate() as Void { minuteKey = -1; }   // call from onSettingsChanged
}
```

**Step 2: change `DataFields.mc`.**
- Replace the per-call Dictionary with a constant array:
  ```monkeyc
  private const ICONS = ["i", "Q", "H", "U", "{", "O", "Æ", "W", "o", "M", "n", "_", null, "W"];
  ...
  var icon = (fieldType >= 0 && fieldType < ICONS.size()) ? ICONS[fieldType] : null;
  ```
- Keep `mValues as Array<String>` and the measured `mValueWidths`. Rebuild them only when `Cache.changed` is true. Refresh only the HR slot every frame:
  ```monkeyc
  function draw(dc as Gfx.Dc) as Void {
      var count = mFieldTypes.size();
      if (count == 0) { return; }
      if (Cache.changed || mValues.size() != count) { refreshValues(); }
      for (var i = 0; i < count; i++) {
          if (mFieldTypes[i] == FIELD_TYPE_HEART_RATE) { mValues[i] = getValue(FIELD_TYPE_HEART_RATE); }
          drawField(dc, i, mXs[i]);          // x positions precomputed in loadSettings()
      }
  }
  ```
- In `getValue`, use `Cache.settings` and `Cache.activity` instead of `Sys.getDeviceSettings()` and `ActivityMonitor.getInfo()`.
- In `GoalMeter` and `MoveBar`, use `Cache.activity`.
- In `TimeField`, use `Cache.settings.is24Hour`.
- In `Analogue`, read `AnalogueTimezoneOffset` into a member in `initialize` and in a new `loadSettings()`, and stop calling `getPropertyValue` in `draw`.

**Done when:**
- No `{ ... }` Dictionary literal or `getDeviceSettings()` call remains in any `draw` path.
- The simulator profiler shows lower per-frame time than the baseline.
- The face looks identical.

### T2.5 "Show seconds" setting · P2 · 30 min
**Decision:** Q5.

**Files:** `TimeField.mc`, `properties.xml` (`ShowSeconds`, boolean, default `true`), `settings.xml`, `strings.xml`

**Steps**
1. Cache the property in `TimeField.loadSettings()`.
2. In `draw`, skip the seconds when the setting is off.
3. Seconds are never drawn in AOD, because T2.1 uses its own drawable.

**Done when:** toggling the setting in the simulator's app-settings editor hides or shows the seconds without a restart (needs T3.6).

---

## Phase 3: data correctness

### T3.1 Location provider, null-safe · P1 · 1 h
**Fixes:** DATA-4 and DATA-5. DATA-5 is crash hypothesis 4.

**Files**
- new `source/Loc.mc`
- `IlluminatorApp.mc` (remove the location block in `onSettingsChanged` and the `gLocation*` globals)
- `DataFields.mc`

```monkeyc
// source/Loc.mc
import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Weather;

module Loc {
    var lat = null;               // Float degrees
    var lng = null;
    var version as Number = 0;    // bumps when location changes -> invalidates sun cache
    var lastCheck as Number = 0;

    function refresh(force as Boolean) as Void {
        var now = Time.now().value();
        if (!force && now - lastCheck < 3600) { return; }
        lastCheck = now;

        var pos = null;
        if (Toybox has :Weather) {
            var cc = Weather.getCurrentConditions();
            if (cc != null && cc.observationLocationPosition != null) {
                pos = cc.observationLocationPosition;
            }
        }
        if (pos == null) {
            var info = Activity.getActivityInfo();           // may be null
            if (info != null && info.currentLocation != null) { pos = info.currentLocation; }
        }

        if (pos != null) {
            var deg = pos.toDegrees();
            var nLat = deg[0].toFloat();
            var nLng = deg[1].toFloat();
            if (lat == null || (nLat - lat).abs() > 0.05 || (nLng - lng).abs() > 0.05) {
                lat = nLat;
                lng = nLng;
                version++;
                Storage.setValue("LastLocationLat", lat);   // write only on change
                Storage.setValue("LastLocationLng", lng);
            }
        } else if (lat == null) {
            lat = Storage.getValue("LastLocationLat");
            lng = Storage.getValue("LastLocationLng");
            if (lat != null) { version++; }
        }
    }
}
```
Call `Loc.refresh(false)` from `Cache.refresh()` when `changed` is true, so the hourly check is evaluated once a minute. Call `Loc.refresh(true)` in `IlluminatorApp.onStart`.

**Done when:**
- With no stored location and no GPS, the face shows `gps?` and doesn't crash.
- After a location appears (simulator: set position, or weather data), sunrise/sunset updates within an hour with no restart.
- No code calls `.currentLocation` without a null-checked `getActivityInfo()`.

### T3.2 Fix our own sunrise/sunset calculation · P2 · 1 h
**Depends on:** T3.1
**Decision:** Q7. Keep computing it ourselves, but fix the bugs.
**Fixes:** DATA-2 (:30/:45 time zones), DATA-3 (polar `0-1:00`), and the stale cache after a location change.

**Files:** `source/DataFields.mc`

**Step 1: use a fractional time zone offset** (`getSunTimes`, line 456):
```monkeyc
var tzOffset = (tz == null) ? (Sys.getClockTime().timeZoneOffset / 3600.0d) : tz;
```

**Step 2: replace the `-1.0` sentinels with explicit polar states.** The array returned by `getSunTimes` has a third element:
```monkeyc
// [rise, set, state]; state: 0 = normal, 1 = polar day (sun never sets), 2 = polar night
if (cosOmega > 1)  { return [null, null, 2]; }   // polar night
if (cosOmega < -1) { return [null, null, 1]; }   // polar day
...
return [rise, set, 0];
```

**Step 3: format the polar states in `getSunEventTime`.** Never format a negative value.
```monkeyc
var state = sunToday[2];
if (state == 1) { return isSunrise ? "--:--" : "24h"; }     // polar day: sun up all day
if (state == 2) { return isSunrise ? "24h" : "--:--"; }     // polar night
// normalise into 0..24 before formatting (events can fall on the previous/next local day)
var t = eventTime;
while (t < 0)   { t += 24; }
while (t >= 24) { t -= 24; }
var h = Math.floor(t).toNumber();
var m = Math.round((t - h) * 60).toNumber();
if (m == 60) { m = 0; h = (h + 1) % 24; }
```
Pick the polar labels you like; they have to fit `mMaxFieldLength`, which is 4 characters for 3 fields.

**Step 4: invalidate the cache on location change.** Key the cache by day **and** `Loc.version` (T3.1):
```monkeyc
var key = nowInfo.day * 1000 + Loc.version;
if (mSunTimesCacheKey != key) { mSunTimesCacheKey = key; mCachedSunTimesToday = null; mCachedSunTimesTomorrow = null; }
```
Also replace `gLocationLat`/`gLocationLng` with `Loc.lat`/`Loc.lng`.

**Step 5: refresh the "next event" choice once a minute** in `refreshValues()` (T2.4), not every frame.

**Done when** (simulator position and time, compared with timeanddate.com):
- Mumbai (+5:30), Kathmandu (+5:45) and Prague are within ±2 min.
- Longyearbyen in January shows polar night, and in June shows polar day, with no negative or garbled times.
- Changing the simulator position updates the times within an hour, with no restart.

### T3.3 Humidity from weather · P2 · 15 min
**Fixes:** DATA-1.

**Files:** `DataFields.mc`

```monkeyc
case FIELD_TYPE_HUMIDITY:
    var cc = Weather.getCurrentConditions();
    value = (cc != null && cc.relativeHumidity != null) ? cc.relativeHumidity.format("%d") + "%" : "--";
    break;
```

**Done when:** the field shows the same humidity as Garmin's weather widget.

### T3.4 Altitude in the user's units · P3 · 10 min
**Fixes:** DATA-7.

```monkeyc
var alt = info.altitude;
if (Cache.settings.elevationUnits == System.UNIT_STATUTE) { alt = alt * 3.28084; }
value = alt.format("%d");
```

**Done when:** with statute elevation units, the altitude is shown in feet.

### T3.5 SensorHistory: read one sample; remove the thermometer · P3 · 20 min
In the temperature and pressure cases, replace `get…History(null)` with:
```monkeyc
SensorHistory.getTemperatureHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST })
```
These values now refresh once a minute (T2.4).

**Remove the thermometer field (Q7).** It is only used by pressure now, so apply the `{:period => 1}` change there.
1. Delete the `<listEntry value="7">@Strings.Temperature</listEntry>` lines from all six field settings in `settings.xml`, and the `Temperature` string.
2. In `DataFields.mc`, delete the `FIELD_TYPE_TEMPERATURE` case. **Keep the enum entry** so the numeric values of the other types don't shift, because users have them saved.
3. In `loadSettings()`, skip saved fields with value `7`, so users who had it selected lose that one field instead of seeing a broken one:
   ```monkeyc
   if (field != null && field >= 0 && field != FIELD_TYPE_TEMPERATURE) { mFieldTypes.add(field); }
   ```

**Done when:** the values are unchanged and the code path is cheaper.

### T3.6 Apply settings live · P2 · 45 min
**Fixes:** DATA-6.

**Files:** `IlluminatorApp.mc`, `IlluminatorView.mc`, `DataFields.mc`, `Analogue.mc`, `TimeField.mc`, `WorldMap.mc` (if T1.4/T1.5 add settings)

**Step 1: in `IlluminatorApp.mc`.**
```monkeyc
function onSettingsChanged() as Void {
    Cache.invalidate();
    if (mView != null) { (mView as IlluminatorView).onSettingsChanged(); }
    WatchUi.requestUpdate();
}
```
Delete `loadFields`, `hasField`, `getIntProperty`, `get*Fields` and the `m*Fields` members. Nothing reads them.

**Step 2: in `IlluminatorView.mc`.**
```monkeyc
function onSettingsChanged() as Void {
    if (datafieldsDrawable != null)       { datafieldsDrawable.loadSettings(); }
    if (datafieldsMiddleDrawable != null) { datafieldsMiddleDrawable.loadSettings(); }
    if (datafieldsBottomDrawable != null) { datafieldsBottomDrawable.loadSettings(); }
    if (analogueDrawable != null)         { analogueDrawable.loadSettings(); }
    if (timeFieldDrawable != null)        { timeFieldDrawable.loadSettings(); }
}
```

**Step 3:** `DataFields.loadSettings()` must also reset `mValues` and precompute `mXs` (T2.4).

**Done when:** changing field 1 from HR to Battery in the simulator settings editor updates the face within 1 s, with no restart.

### T3.7 ~~Complete the second time zone list~~ · dropped (Q8)
The second time zone works as intended: a fixed offset, no DST, shown only on the analogue clock. The only related change is caching the property read in `Analogue` (T2.4).

---

## Phase 4: housekeeping

### T4.1 Manifest: API level and permissions · P2 · 20 min
**Decision:** Q6.

**Files:** `manifest.xml`

1. Set `minApiLevel="4.0.0"` (Q6).
2. Remove the permissions that no code uses: `Ant`, `Background`, `ComplicationSubscriber`, `PushNotification`, `UserProfile`.
3. Keep `SensorHistory` (pressure), `Sensor` and `Notifications`. `Positioning` is no longer needed, because sunrise/sunset is computed from plain lat/lon (Q7). Remove it too, and re-add it only if T3.1's location sources stop working without it.
4. After the build, test every field once. If any field stops working, re-add only the permission it needs.

**Done when:** the build succeeds, all 13 remaining field types show values in the simulator, and the store listing shows fewer permissions.

### T4.2 Remove dead code and resources · P3 · 30 min
**Decision:** Q9.

Delete:
- `source/IlluminatorBackground.mc`. It clears to white and is not used.
- In `resources/layouts/layout.xml`: the `Background` drawable and `TimeLabel`. Leave an empty `WatchFace` layout, or copy the 416 layout, so non-round fallbacks still build.
- In `properties.xml`: `BackgroundColor`, `ForegroundColor`, `UseMilitaryFormat`, `Field4`.
- In `strings.xml`: `BackgroundColorTitle`, `ForegroundColorTitle`, `MilitaryFormatTitle`, `Color*`, `SunriseSunset`, `Weather`.
- In `resources-round-*/resources.xml`: the duplicate `worldMap`/`worldMapJson`, since `fonts/resources.xml` already defines them. Delete the whole file if nothing else is in it.
- In `WorldMap.mc`: the leftovers removed by T1.2.
- `source/crystal-face.code-workspace`: move it out of the repo.

**Done when:** the build has no unused-resource warnings and the face is identical.

### T4.3 Update the README · P3 · 20 min
Fix the following:
- Targets: 21 AMOLED devices at 416/454.
- Requirements: Connect IQ 3.3+.
- Permissions: the list after T4.1, and drop "Background processing".
- Humidity source: weather.
- AOD behaviour, the new settings, and the `docs/` folder.
- The build command (`bin/Casio.prg` vs `Illuminator.prg`).

**Done when:** the README matches the code.

### T4.4 Verify the four products not mapped in `monkey.jungle` · P3 · 20 min
Run approachs7047mm, d2mach2, descentmk351mm and venu445mm in the simulator and confirm each picks up the right round resources.

If one of them falls back to `resources/`, add an explicit line in `monkey.jungle`, for example:
```
venu445mm.resourcePath = $(venu445mm.resourcePath);resources-round-454x454
```
Use the device's real resolution.

**Done when:** all four look like their resolution group.

---

### T4.5 Support 390×390 devices · P3 · 3–4 h
**Decision:** Q10.
**Why:** `resources-round-390x390/` exists, but no 390 product is in the manifest. Its `layout.xml` is a byte-for-byte copy of the 416 layout, so on a 390 screen elements run off the edge. For example, GoalMeter starts at x=5 with width 395, ending at x=400.

**Steps**
1. **Pick the products.** In the SDK Manager device list, filter round 390×390 AMOLED devices with CIQ ≥ 4.0. Likely candidates are fr165, fr165m, venu3s, vivoactive5 and vivoactive6; confirm each one's resolution there. Add them to `manifest.xml`.
2. **Map them in `monkey.jungle`** (uncomment or fix the existing commented lines). Some of those lines wrongly point 390 devices at the 416 folder:
   ```
   fr165.resourcePath = $(fr165.resourcePath);resources-round-390x390
   ```
3. **Scale the art.** Regenerate the tile fonts for 390 with tilemapper at a smaller `-r`. For example, map width 130 → map 130×65 at scale 390/416 ≈ 0.94; dial and hands similarly. Update `resources-round-390x390/fonts/py` with the commands used.
4. **Write a real 390 layout.** Scale every position and size by ≈0.94 from the 416 layout, then fix visually. Set the map size to the new art (for example `130`/`65`, see T1.1), and add the `AlwaysOn` layout from T2.1.
5. **Delete the duplicate `resources-round-390x390/resources.xml`** (T4.2).

**Done when:** every 390 product builds and nothing is clipped in high power, AOD (< 10 % lit) or the map test dates in T5.1.

---

## Phase 5: verification

### T5.1 Test matrix · P1 (after each phase) · 1–2 h
| Area | Case | Expected |
|---|---|---|
| Map | 21 Jun 12:00 UTC | Antarctica fully dark, Arctic lit |
| Map | 21 Dec 12:00 UTC | Antarctica lit, Arctic dark |
| Map | 20 Mar / 23 Sep | Near-vertical terminator, both poles on the edge |
| Map | 13 Oct 15:50 UTC | Part of the Antarctic coast shaded, as in `worldmap-daynight-current-vs-fixed.png` |
| Map | Across 00:00 UTC, local midnight, EU DST change 25 Oct | No jump in the terminator |
| Map (454) | Local night in NZ/Fiji | Last 10 columns (157.5°E–180°) shaded |
| AOD | Simulator low power + heat map, 24 h | < 10 % lit, no stuck pixels |
| AOD | Watch, wrist down/up | Dimmed face → full face, no black screen |
| Stability | 72 h simulated low power | No crash; memory flat |
| Stability | Watch, 3 days AOD with T0.2 logging build | `usedMemory` flat, no ERA entries |
| Battery | 24 h AOD drain vs T0.3 baseline | Lower; record the number |
| Data | Mumbai, Kathmandu, Longyearbyen, Prague sun times | ±2 min; clean polar-day / polar-night labels |
| Data | Humidity, altitude in feet; thermometer gone from settings | Real values |
| AOD | Time + date + hands + dimmed map (Q2) | All four visible, shifted together, < 10 % lit |
| Settings | Change a field / seconds / second time zone | Applied without restart |
| Devices | All products build (21 + 390 group); one run per resolution group | OK |

**Done when:** every row passes and the results are recorded below.

---

## Suggested order and rough effort
| Order | Tasks | Effort | Outcome |
|---|---|---|---|
| 1 | T0.1, T0.2 (start the logging), T0.3 | ~1.5 h + waiting | Work is safe; baseline and evidence collected |
| 2 | T1.1 + T1.2 | ~3 h | Antarctica fixed, correct terminator, no allocation churn |
| 3 | T2.1, T3.1 | ~4 h | AOD compliant; both remaining crash suspects removed |
| 4 | T2.3, T2.4, T2.5, T3.6 | ~4 h | Lower CPU per frame; settings applied live |
| 5 | T3.2–T3.5 | ~2.5 h | Data fields correct, thermometer removed |
| 6 | T4.1–T4.4, T1.5 | ~2.5 h | Clean manifest, repo and README; twilight band tried |
| 7 | T1.3, T4.5 | ~5 h | Bitmap cache; 390 devices supported |
| 8 | T5.1 after each step, release | — | Verified release |

## Baseline and results
| Metric | Baseline (T0.3) | After phase 1 | After phase 2 | After phase 3 |
|---|---|---|---|---|
| AOD lit pixels (sim heat map) | | | | |
| Peak memory (sim) | | | | |
| 24 h AOD battery drain (watch) | | | | |
| Crash / ERA entries in 3 days | | | | |
