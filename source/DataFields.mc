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
    FIELD_TYPE_TEMPERATURE,
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

    private var iconFont as Gfx.FontResource;
    private var textFont as Gfx.FontResource;

    private var mCachedSunTimesToday as Lang.Array<Lang.Number?>?;
    private var mCachedSunTimesTomorrow as Lang.Array<Lang.Number?>?;
    private var mSunTimesCacheDay as Lang.Number = -1;

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

        iconFont = Ui.loadResource(Rez.Fonts.garmin_icons);
        textFont = Ui.loadResource(Rez.Fonts.text);

        loadSettings();
    }

    function loadSettings() as Void {
        mFieldTypes = [];

        if (mfieldPosition == :upper) {
            var count = Properties.getValue("FieldCount");
            mFieldCount = (count != null) ? count as Lang.Number : 0;
            for (var i = 1; i <= mFieldCount; i++) {
                var field = Properties.getValue("Field" + i);
                if (field != null && field >= 0) {
                    mFieldTypes.add(field as Lang.Number);
                }
            }
        } else if (mfieldPosition == :middle) {
            var count = Properties.getValue("FieldMiddleCount");
            mFieldCount = (count != null) ? count as Lang.Number : 0;
            for (var i = 1; i <= mFieldCount; i++) {
                var field = Properties.getValue("FieldMiddle" + i);
                if (field != null && field >= 0) {
                    mFieldTypes.add(field as Lang.Number);
                }
            }
        } else if (mfieldPosition == :lower) {
            var count = Properties.getValue("FieldBottomCount");
            mFieldCount = (count != null) ? count as Lang.Number : 0;
            for (var i = 1; i <= mFieldCount; i++) {
                var field = Properties.getValue("FieldBottom" + i);
                if (field != null && field >= 0) {
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
    }

    function draw(dc as Gfx.Dc) as Void {
        var count = mFieldTypes.size();
        if (count == 0) {
            return;
        }

        for (var i = 0; i < count; i++) {
            var x as Lang.Number;
            if (count == 1) {
                x = (mLeft + mRight) / 2;
            } else if (count == 2) {
                x = (i == 0)
                    ? mLeft + ((mRight - mLeft) * 0.25).toNumber()
                    : mLeft + ((mRight - mLeft) * 0.75).toNumber();
            } else {
                x = mLeft + ((mRight - mLeft) * i / (count - 1));
            }

            drawField(dc, mFieldTypes[i], x);
        }
    }

    private const ICON_TEXT_GAP as Lang.Number = 4;

    private function drawField(dc as Gfx.Dc, fieldType as Lang.Number, x as Lang.Number) as Void {
        var value = getValue(fieldType);

        var icon as Lang.String? = {
            FIELD_TYPE_HEART_RATE        => "i",
            FIELD_TYPE_BATTERY           => "Q",
            FIELD_TYPE_NOTIFICATIONS     => "H",
            FIELD_TYPE_CALORIES          => "U",
            FIELD_TYPE_DISTANCE          => "{",
            FIELD_TYPE_ALARMS            => "O",
            FIELD_TYPE_ALTITUDE          => "Æ",
            FIELD_TYPE_TEMPERATURE       => "W",
            FIELD_TYPE_PRESSURE          => "o",
            FIELD_TYPE_HUMIDITY          => "M",
            FIELD_TYPE_SUNRISE           => "n",
            FIELD_TYPE_SUNSET            => "_",
            FIELD_TYPE_BATTERY_NO_ICON   => null,
            FIELD_TYPE_GARMIN_TEMPERATURE => "W"
        }[fieldType] as Lang.String?;

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
            ? dc.getTextDimensions(icon, iconFont)
            : [0, 0] as Lang.Array<Lang.Number>;

        var textDims = dc.getTextDimensions(value, textFont);

        var iconW = iconDims[0] as Lang.Number;
        var iconH = iconDims[1] as Lang.Number;
        var textH = textDims[1] as Lang.Number;

        var centerY = (mTop + mBottom) / 2;
        var iconY = centerY;
        var textY = centerY + (iconH - textH);

        if (icon != null) {
            dc.drawText(x, iconY, iconFont, icon, Gfx.TEXT_JUSTIFY_CENTER);
        }

        var valueX = (icon != null) ? x + (iconW / 2) + ICON_TEXT_GAP : x;
        dc.drawText(valueX, textY, textFont, value, Gfx.TEXT_JUSTIFY_LEFT);
    }

    private function getValue(type as Lang.Number) as Lang.String {
        var settings = Sys.getDeviceSettings();
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
                var actInfoCal = ActivityMonitor.getInfo();
                if (actInfoCal != null && actInfoCal.calories != null) {
                    value = actInfoCal.calories.format("%d");
                }
                break;

            case FIELD_TYPE_DISTANCE:
                var actInfoDist = ActivityMonitor.getInfo();
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
                    value = info.altitude.format("%d");
                }
                break;

            case FIELD_TYPE_TEMPERATURE:
                if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory)) {
                    var tempHistory = SensorHistory.getTemperatureHistory(null);
                    if (tempHistory != null) {
                        sample = tempHistory.next();
                        if ((sample != null) && (sample.data != null)) {
                            var temperature = sample.data;
                            if (settings != null && settings.temperatureUnits == System.UNIT_STATUTE) {
                                temperature = (temperature * (9.0 / 5)) + 32;
                            }
                            value = temperature.format("%d");
                        }
                    }
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
                if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory)) {
                    var pressHistory = SensorHistory.getPressureHistory(null);
                    if (pressHistory != null) {
                        sample = pressHistory.next();
                        if (sample != null && sample.data != null) {
                            value = (sample.data / 100).format("%.0f");
                        }
                    }
                }
                break;

            case FIELD_TYPE_HUMIDITY:
                if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getHumidityHistory)) {
                    var humidHistory = SensorHistory.getHumidityHistory(null);
                    if (humidHistory != null) {
                        sample = humidHistory.next();
                        if (sample != null && sample.data != null) {
                            value = sample.data.format("%d") + "%";
                        }
                    }
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

    private function getCachedSunTimes(isTomorrow as Lang.Boolean) as Lang.Array<Lang.Number?> {
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = nowInfo.day;

        if (mSunTimesCacheDay != today) {
            mSunTimesCacheDay = today;
            mCachedSunTimesToday = null;
            mCachedSunTimesTomorrow = null;
        }

        if (isTomorrow) {
            if (mCachedSunTimesTomorrow == null) {
                mCachedSunTimesTomorrow = getSunTimes(gLocationLat, gLocationLng, null, true);
            }
            return mCachedSunTimesTomorrow as Lang.Array<Lang.Number?>;
        } else {
            if (mCachedSunTimesToday == null) {
                mCachedSunTimesToday = getSunTimes(gLocationLat, gLocationLng, null, false);
            }
            return mCachedSunTimesToday as Lang.Array<Lang.Number?>;
        }
    }

    private function getSunEventTime(isSunrise as Lang.Boolean, is24Hour as Lang.Boolean) as Lang.String {
        if (gLocationLat == null || gLocationLng == null) {
            return "gps?";
        }

        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var now = nowInfo.hour + ((nowInfo.min + 1) / 60.0);

        var eventTime as Lang.Number? = null;

        var sunToday = getCachedSunTimes(false);
        var todayEvent = isSunrise ? sunToday[0] : sunToday[1];

        if (todayEvent != null && now < todayEvent) {
            eventTime = todayEvent;
        } else {
            var sunTomorrow = getCachedSunTimes(true);
            eventTime = isSunrise ? sunTomorrow[0] : sunTomorrow[1];
        }

        if (eventTime == null) {
            return "---";
        }

        var h = Math.floor(eventTime).toLong() % 24;
        var m = Math.floor((eventTime - Math.floor(eventTime)) * 60).toLong();

        if (m < 0)  { m = 0; }
        if (m > 59) { m = 59; }

        if (is24Hour) {
            return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
        } else {
            var h12 = h % 12;
            if (h12 == 0) { h12 = 12; }
            return h12 + ":" + (m < 10 ? "0" : "") + m;
        }
    }

    private function getSunTimes(lat as Lang.Double?, lng as Lang.Double?, tz as Lang.Number?, tomorrow as Lang.Boolean) as Lang.Array<Lang.Number?> {
        if (lat == null || lng == null) {
            return [null, null] as Lang.Array<Lang.Number?>;
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
            return [null, -1] as Lang.Array<Lang.Number?>;
        }

        if (cosOmega < -1) {
            return [-1, null] as Lang.Array<Lang.Number?>;
        }

        var omega = Math.acos(cosOmega) * deg;
        var jSet = jTransit + (omega / 360.0);
        var jRise = jTransit - (omega / 360.0);
        var deltaJSet = jSet - jDate;
        var deltaJRise = jRise - jDate;

        var tzOffset = (tz == null) ? (Sys.getClockTime().timeZoneOffset / 3600) : tz;
        return [
            ((deltaJRise * 24) + tzOffset) as Lang.Number,
            ((deltaJSet * 24) + tzOffset) as Lang.Number
        ] as Lang.Array<Lang.Number?>;
    }
}
