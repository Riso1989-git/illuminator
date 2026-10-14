using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Lang;
using Toybox.Application.Properties;
using Toybox.Time.Gregorian;
using Toybox.Weather;
import Toybox.Math;
import Toybox.Time;

enum {
    FIELD_TYPE_HEART_RATE,
    FIELD_TYPE_BATTERY,
    FIELD_TYPE_NOTIFICATIONS,
    FIELD_TYPE_CALORIES,
    FIELD_TYPE_DISTANCE,
    FIELD_TYPE_ALARMS,
    FIELD_TYPE_ALTITUDE,
    FIELD_TYPE_TEMPERATURE,          // removed from settings (Q7); kept so values don't shift
    FIELD_TYPE_PRESSURE,
    FIELD_TYPE_HUMIDITY,
    FIELD_TYPE_SUNRISE,
    FIELD_TYPE_SUNSET,
    FIELD_TYPE_BATTERY_NO_ICON,
    FIELD_TYPE_GARMIN_TEMPERATURE
}

class DataFields extends Ui.Drawable {

    private var mLeft as Lang.Number;
    private var mRight as Lang.Number;
    private var mTop as Lang.Number;
    private var mBottom as Lang.Number;
    private var mfieldPosition as Lang.Symbol;

    private var mFieldCount as Lang.Number = 0;
    private var mMaxFieldLength as Lang.Number = 0;
    private var mFieldTypes as Lang.Array<Lang.Number> = [];

    // T2.4: field strings are rebuilt once per Cache.generation (once a minute);
    // only heart rate is refreshed every frame.
    private var mValues as Lang.Array<Lang.String> = [];
    private var mXs as Lang.Array<Lang.Number> = [];
    private var mValuesGen as Lang.Number = -1;

    // Icon per field type (index = FIELD_TYPE_*). Replaces a Dictionary that was
    // allocated for every field on every frame.
    private const ICONS = ["i", "Q", "H", "U", "{", "O", "Æ", "W", "o", "M", "n", "_", null, "W"];

    private var mCachedSunTimesToday as Lang.Array?;
    private var mCachedSunTimesTomorrow as Lang.Array?;
    private var mSunTimesCacheDay as Lang.Number = -1;      // day * 100000 + Loc.version

    typedef Params as {
        :left   as Lang.Number,
        :right  as Lang.Number,
        :top    as Lang.Number,
        :bottom as Lang.Number,
        :fieldPosition as Lang.Symbol
    };

    function initialize(params as Params) {
        Drawable.initialize(params);

        mLeft   = params[:left];
        mRight  = params[:right];
        mTop    = params[:top];
        mBottom = params[:bottom];
        mfieldPosition = params[:fieldPosition];

        Res.load();

        loadSettings();
    }

    function loadSettings() as Void {
        mFieldTypes = [];

        if (mfieldPosition == :upper) {
            var count = Properties.getValue("FieldCount");
            mFieldCount = (count != null) ? count as Lang.Number : 0;
            for (var i = 1; i <= mFieldCount; i++) {
                var field = Properties.getValue("Field" + i);
                if (field != null && field >= 0 && field != FIELD_TYPE_TEMPERATURE) {
                    mFieldTypes.add(field as Lang.Number);
                }
            }
        } else if (mfieldPosition == :middle) {
            var count = Properties.getValue("FieldMiddleCount");
            mFieldCount = (count != null) ? count as Lang.Number : 0;
            for (var i = 1; i <= mFieldCount; i++) {
                var field = Properties.getValue("FieldMiddle" + i);
                if (field != null && field >= 0 && field != FIELD_TYPE_TEMPERATURE) {
                    mFieldTypes.add(field as Lang.Number);
                }
            }
        } else if (mfieldPosition == :lower) {
            var count = Properties.getValue("FieldBottomCount");
            mFieldCount = (count != null) ? count as Lang.Number : 0;
            for (var i = 1; i <= mFieldCount; i++) {
                var field = Properties.getValue("FieldBottom" + i);
                if (field != null && field >= 0 && field != FIELD_TYPE_TEMPERATURE) {
                    mFieldTypes.add(field as Lang.Number);
                }
            }
        } else {
            mFieldCount = 0;
        }

        var lengthLookup = [0, 8, 6, 4, 3] as Lang.Array<Lang.Number>;
        mMaxFieldLength = (mFieldCount >= 0 && mFieldCount < lengthLookup.size())
            ? lengthLookup[mFieldCount]
            : 0;

        // x position of every field, computed once
        var count = mFieldTypes.size();
        mXs = [];
        for (var i = 0; i < count; i++) {
            var x;
            if (count == 1) {
                x = (mLeft + mRight) / 2;
            } else if (count == 2) {
                x = (i == 0)
                    ? mLeft + ((mRight - mLeft) * 0.25).toNumber()
                    : mLeft + ((mRight - mLeft) * 0.75).toNumber();
            } else {
                x = mLeft + ((mRight - mLeft) * i / (count - 1));
            }
            mXs.add(x);
        }
        mValuesGen = -1;            // rebuild strings on the next frame
    }

    function draw(dc as Gfx.Dc) as Void {
        var count = mFieldTypes.size();
        if (count == 0) {
            return;
        }

        if (mValuesGen != Cache.generation || mValues.size() != count) {
            mValuesGen = Cache.generation;
            mValues = [];
            for (var i = 0; i < count; i++) {
                mValues.add(getValue(mFieldTypes[i]));
            }
        }

        for (var i = 0; i < count; i++) {
            if (mFieldTypes[i] == FIELD_TYPE_HEART_RATE) {
                mValues[i] = getValue(FIELD_TYPE_HEART_RATE);
            }
            drawField(dc, mFieldTypes[i], mValues[i], mXs[i]);
        }
    }

    private const ICON_TEXT_GAP as Lang.Number = 4;

    private function drawField(dc as Gfx.Dc, fieldType as Lang.Number, value as Lang.String, x as Lang.Number) as Void {
        var icon = (fieldType >= 0 && fieldType < ICONS.size()) ? (ICONS[fieldType] as Lang.String?) : null;

        if (fieldType == FIELD_TYPE_HEART_RATE) {
            var hr = (value != null) ? value.toNumber() : 0;
            if (hr > 0) {
                var seconds = System.getClockTime().sec;
                icon = (seconds % 2 == 0) ? "i" : "j";
            } else {
                icon = "i";
            }
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        var iconDims = (icon != null)
            ? dc.getTextDimensions(icon, Res.iconFont)
            : [0, 0] as Lang.Array<Lang.Number>;

        var textDims = dc.getTextDimensions(value, Res.textFont);

        var iconW = iconDims[0] as Lang.Number;
        var iconH = iconDims[1] as Lang.Number;
        var textH = textDims[1] as Lang.Number;

        var centerY = (mTop + mBottom) / 2;
        var iconY = centerY;
        var textY = centerY + (iconH - textH);

        if (icon != null) {
            dc.drawText(x, iconY, Res.iconFont, icon, Gfx.TEXT_JUSTIFY_CENTER);
        }

        var valueX = (icon != null) ? x + (iconW / 2) + ICON_TEXT_GAP : x;
        dc.drawText(valueX, textY, Res.textFont, value, Gfx.TEXT_JUSTIFY_LEFT);
    }

    private function getValue(type as Lang.Number) as Lang.String {
        var settings = Cache.settings;          // T2.4: fetched once a minute
        var info;
        var sample;
        var value = "0";

        switch (type) {
            case FIELD_TYPE_HEART_RATE:
                info = Activity.getActivityInfo();
                if (info != null && info.currentHeartRate != null) {
                    value = info.currentHeartRate.format("%d");
                }
                break;

            case FIELD_TYPE_BATTERY:
                var stats = Sys.getSystemStats();
                if (stats != null) {
                    value = Math.floor(stats.battery).format("%d") + "%";
                }
                break;

            case FIELD_TYPE_BATTERY_NO_ICON:
                var statsNoIcon = Sys.getSystemStats();
                if (statsNoIcon != null) {
                    value = Math.floor(statsNoIcon.battery).format("%d") + "%";
                }
                break;

            case FIELD_TYPE_NOTIFICATIONS:
                if (settings != null && settings.notificationCount > 0) {
                    value = settings.notificationCount.format("%d");
                }
                break;

            case FIELD_TYPE_CALORIES:
                var actInfoCal = Cache.activity;
                if (actInfoCal != null && actInfoCal.calories != null) {
                    value = actInfoCal.calories.format("%d");
                }
                break;

            case FIELD_TYPE_DISTANCE:
                var actInfoDist = Cache.activity;
                if (actInfoDist != null && actInfoDist.distance != null) {
                    var dist = actInfoDist.distance.toFloat() / 100000;
                    if (settings != null && settings.distanceUnits == Sys.UNIT_STATUTE) {
                        dist *= 0.621371;
                    }
                    value = dist.format("%.1f");
                }
                break;

            case FIELD_TYPE_ALARMS:
                if (settings != null && settings.alarmCount > 0) {
                    value = settings.alarmCount.format("%d");
                }
                break;

            case FIELD_TYPE_ALTITUDE:
                info = Activity.getActivityInfo();
                if (info != null && info.altitude != null) {
                    var alt = info.altitude;
                    if (settings != null && settings.elevationUnits == Sys.UNIT_STATUTE) {
                        alt = alt * 3.28084;            // metres -> feet
                    }
                    value = alt.format("%d");
                }
                break;

            case FIELD_TYPE_GARMIN_TEMPERATURE:
                var weather = Weather.getCurrentConditions();
                if (weather != null && weather.temperature != null) {
                    var temp = weather.temperature;
                    if (settings != null && settings.temperatureUnits == System.UNIT_STATUTE) {
                        temp = (temp * (9.0 / 5)) + 32;
                    }
                    value = temp.format("%d");
                } else {
                    value = "--";
                }
                break;

            case FIELD_TYPE_PRESSURE:
                value = "--";                   // no barometer (e.g. vivoactive 5/6)
                if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory)) {
                    var pressHistory = SensorHistory.getPressureHistory({
                        :period => 1,
                        :order => SensorHistory.ORDER_NEWEST_FIRST
                    });
                    if (pressHistory != null) {
                        sample = pressHistory.next();
                        if (sample != null && sample.data != null) {
                            value = (sample.data / 100).format("%.0f");
                        }
                    }
                }
                break;

            case FIELD_TYPE_HUMIDITY:
                // watches have no humidity sensor; the value comes from Garmin weather
                var cc = Weather.getCurrentConditions();
                if (cc != null && cc.relativeHumidity != null) {
                    value = cc.relativeHumidity.format("%d") + "%";
                } else {
                    value = "--";
                }
                break;

            case FIELD_TYPE_SUNRISE:
                value = getSunEventTime(true, settings != null ? settings.is24Hour : true);
                break;

            case FIELD_TYPE_SUNSET:
                value = getSunEventTime(false, settings != null ? settings.is24Hour : true);
                break;
        }

        return (value.length() > mMaxFieldLength)
            ? value.substring(0, mMaxFieldLength) as Lang.String
            : value;
    }

    // ---- sunrise / sunset (T3.2) ----------------------------------------------------
    // getSunTimes() returns [rise, set, state] in local decimal hours (may lie outside
    // 0..24 for far-east/far-west longitudes); state: SUN_NORMAL / SUN_POLAR_DAY / SUN_POLAR_NIGHT.

    private const SUN_NORMAL = 0;
    private const SUN_POLAR_DAY = 1;
    private const SUN_POLAR_NIGHT = 2;

    private function getCachedSunTimes(isTomorrow as Lang.Boolean) as Lang.Array {
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        // recompute on a new day or when the location changed (Loc.version)
        var key = (nowInfo.day as Lang.Number) * 100000 + Loc.version;

        if (mSunTimesCacheDay != key) {
            mSunTimesCacheDay = key;
            mCachedSunTimesToday = null;
            mCachedSunTimesTomorrow = null;
        }

        if (isTomorrow) {
            if (mCachedSunTimesTomorrow == null) {
                mCachedSunTimesTomorrow = getSunTimes(Loc.lat, Loc.lng, true);
            }
            return mCachedSunTimesTomorrow as Lang.Array;
        } else {
            if (mCachedSunTimesToday == null) {
                mCachedSunTimesToday = getSunTimes(Loc.lat, Loc.lng, false);
            }
            return mCachedSunTimesToday as Lang.Array;
        }
    }

    // Next sunrise/sunset as text. Polar day shows "24h" (sun up all day),
    // polar night "0h" (sun never rises) - both fit the 4-character field limit.
    private function getSunEventTime(isSunrise as Lang.Boolean, is24Hour as Lang.Boolean) as Lang.String {
        if (Loc.lat == null || Loc.lng == null) {
            return "gps?";
        }

        var ct = Sys.getClockTime();
        var now = ct.hour + ((ct.min + 1) / 60.0);

        var sun = getCachedSunTimes(false);
        var state = sun[2];
        var eventTime = (state == SUN_NORMAL) ? (isSunrise ? sun[0] : sun[1]) : null;

        if (state == SUN_NORMAL && (eventTime == null || now >= eventTime)) {
            // today's event has passed -> tomorrow's
            sun = getCachedSunTimes(true);
            state = sun[2];
            eventTime = (state == SUN_NORMAL) ? (isSunrise ? sun[0] : sun[1]) : null;
        }

        if (state == SUN_POLAR_DAY) {
            return "24h";
        }
        if (state == SUN_POLAR_NIGHT || eventTime == null) {
            return "0h";
        }

        // normalise into 0..24, round to the nearest minute
        var totalMin = Math.round(eventTime * 60.0).toNumber();
        totalMin = ((totalMin % 1440) + 1440) % 1440;
        var h = totalMin / 60;
        var m = totalMin % 60;

        if (!is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
            return h + ":" + m.format("%02d");
        }
        return h.format("%02d") + ":" + m.format("%02d");
    }

    private function getSunTimes(lat, lng, tomorrow as Lang.Boolean) as Lang.Array {
        if (lat == null || lng == null) {
            return [null, null, SUN_NORMAL];
        }

        var latD = lat.toDouble();
        var lngD = lng.toDouble();
        var now = Time.now();

        if (tomorrow) {
            now = now.add(new Time.Duration(24 * 60 * 60));
        }

        var d = Gregorian.info(now, Time.FORMAT_SHORT);
        var rad = Math.PI / 180.0d;
        var deg = 180.0d / Math.PI;

        var a = Math.floor((14 - d.month) / 12);
        var y = d.year + 4800 - a;
        var m = d.month + (12 * a) - 3;
        var jDate = d.day
            + Math.floor(((153 * m) + 2) / 5)
            + (365 * y)
            + Math.floor(y / 4)
            - Math.floor(y / 100)
            + Math.floor(y / 400)
            - 32045;

        var n = jDate - 2451545.0d + 0.0008d;
        var jStar = n - (lngD / 360.0d);

        var M = 357.5291d + (0.98560028d * jStar);
        var MFloor = Math.floor(M);
        var MFrac = M - MFloor;
        M = MFloor.toLong() % 360;
        M += MFrac;

        var C = 1.9148d * Math.sin(M * rad)
            + 0.02d * Math.sin(2 * M * rad)
            + 0.0003d * Math.sin(3 * M * rad);

        var lambda = (M + C + 180 + 102.9372d);
        var lambdaFloor = Math.floor(lambda);
        var lambdaFrac = lambda - lambdaFloor;
        lambda = lambdaFloor.toLong() % 360;
        lambda += lambdaFrac;

        var jTransit = 2451545.5d + jStar
            + 0.0053d * Math.sin(M * rad)
            - 0.0069d * Math.sin(2 * lambda * rad);

        var delta = Math.asin(Math.sin(lambda * rad) * Math.sin(23.44d * rad));

        var cosOmega = (Math.sin(-0.83d * rad) - Math.sin(latD * rad) * Math.sin(delta))
            / (Math.cos(latD * rad) * Math.cos(delta));

        if (cosOmega > 1) {
            return [null, null, SUN_POLAR_NIGHT];
        }
        if (cosOmega < -1) {
            return [null, null, SUN_POLAR_DAY];
        }

        var omega = Math.acos(cosOmega) * deg;
        var jSet = jTransit + (omega / 360.0);
        var jRise = jTransit - (omega / 360.0);
        var deltaJSet = jSet - jDate;
        var deltaJRise = jRise - jDate;

        // fractional hours: +5:30 India, +5:45 Nepal etc. (was integer division)
        var tzOffset = Sys.getClockTime().timeZoneOffset / 3600.0d;
        return [
            (deltaJRise * 24) + tzOffset,
            (deltaJSet * 24) + tzOffset,
            SUN_NORMAL
        ];
    }
}
