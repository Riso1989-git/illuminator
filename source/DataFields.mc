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

    private var mLeft;
    private var mRight;
    private var mTop;
    private var mBottom;
	private var mfieldPosition; // :upper or :lower

    private var mFieldCount;
    private var mMaxFieldLength;
    private var mFieldTypes = [];

	private var iconFont;
	private var textFont;

    private var mCachedSunTimesToday = null;
    private var mCachedSunTimesTomorrow = null;
    private var mSunTimesCacheDay = -1;

    typedef Params as {
        :left   as Lang.Number,
        :right  as Lang.Number,
        :top    as Lang.Number,
        :bottom as Lang.Number,
		:mfieldPosition as Lang.Symbol
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

    function loadSettings() {
		if (mfieldPosition == :upper) {
			mFieldCount = Properties.getValue("FieldCount");
			for (var i = 1; i <= mFieldCount; i++) {
				var field = Properties.getValue("Field" + i);
				if (field >= 0) {
					mFieldTypes.add(field);
				}
			}
		} else if (mfieldPosition == :middle) {
			mFieldCount = Properties.getValue("FieldMiddleCount");
			for (var i = 1; i <= mFieldCount; i++) {
				var field = Properties.getValue("FieldMiddle" + i);
				if (field >= 0) {
					mFieldTypes.add(field);
				}
			}
		} else {
			mFieldCount = Properties.getValue("FieldBottomCount");
			for (var i = 1; i <= mFieldCount; i++) {
				var field = Properties.getValue("FieldBottom" + i);
				if (field >= 0) {
					mFieldTypes.add(field);
				}
			}
		}
		mMaxFieldLength = [0, 8, 6, 4, 3][mFieldCount];
    }

    function draw(dc as Gfx.Dc) {

        var count = mFieldTypes.size();
        if (count == 0) {
            return;
        }

        for (var i = 0; i < count; i++) {

            var x;
            if (count == 1) {
                x = (mLeft + mRight) / 2;
            } else if (count == 2) {
                x = (i == 0)
                    ? mLeft + ((mRight - mLeft) * 0.25)
                    : mLeft + ((mRight - mLeft) * 0.75);
            } else {
                x = mLeft + ((mRight - mLeft) * i / (count - 1));
            }

            drawField(dc, mFieldTypes[i], x);
        }
    }

	private const ICON_TEXT_GAP = 4;

private function drawField(dc, fieldType, x) {

    var value = getValue(fieldType);

    // --- Base icon mapping ---
    var icon = {
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
		FIELD_TYPE_SUNRISE	         => "n",
		FIELD_TYPE_SUNSET	         => "_",
		FIELD_TYPE_BATTERY_NO_ICON	 => null,
		FIELD_TYPE_GARMIN_TEMPERATURE => "W"
    }[fieldType];

    // --- Heart-rate animation logic ---
    if (fieldType == FIELD_TYPE_HEART_RATE) {

        var hr = (value != null) ? value.toNumber() : 0;

        if (hr > 0) {
            var seconds = System.getClockTime().sec;
            icon = (seconds % 2 == 0)
                ? "i"   // empty heart
                : "j";  // full heart
        } else {
            icon = "i";
        }
    }

    dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

    // --- Measure glyphs ---
    var iconDims = (icon != null)
        ? dc.getTextDimensions(icon, iconFont)
        : [0, 0];

    var textDims = dc.getTextDimensions(value, textFont);

    var iconW = iconDims[0];
    var iconH = iconDims[1];
    var textH = textDims[1];

    var centerY = (mTop + mBottom) / 2;

    // Top-left positioning (no VCENTER)
    var iconY = centerY;
    var textY = centerY + (iconH - textH);

    // --- Draw icon ---
    if (icon != null) {
        dc.drawText(
            x,
            iconY,
            iconFont,
            icon,
            Gfx.TEXT_JUSTIFY_CENTER
        );
    }

    // --- Draw value ---
    var valueX = (icon != null)
        ? x + (iconW / 2) + ICON_TEXT_GAP
        : x;

    dc.drawText(
        valueX,
        textY,
        textFont,
        value,
        Gfx.TEXT_JUSTIFY_LEFT
    );
}

    private function getValue(type) as Lang.String {

		var settings = Sys.getDeviceSettings();
        var info;
        var sample;
        var value = "0";

        switch (type) {

            case FIELD_TYPE_HEART_RATE:
                info = Activity.getActivityInfo();
                if (info.currentHeartRate != null) {
                    value = info.currentHeartRate.format("%d");
                }
                break;

            case FIELD_TYPE_BATTERY:
                value = Math.floor(Sys.getSystemStats().battery).format("%d") + "%";
                break;
            case FIELD_TYPE_BATTERY_NO_ICON:
                value = Math.floor(Sys.getSystemStats().battery).format("%d") + "%";
                break;

            case FIELD_TYPE_NOTIFICATIONS:
                if (settings.notificationCount > 0) {
                    value = settings.notificationCount.format("%d");
                }
                break;

            case FIELD_TYPE_CALORIES:
                value = ActivityMonitor.getInfo().calories.format("%d");
                break;

            case FIELD_TYPE_DISTANCE:
                var dist = ActivityMonitor.getInfo().distance.toFloat() / 100000;
                if (settings.distanceUnits == Sys.UNIT_STATUTE) {
                    dist *= 0.621371;
                }
                value = dist.format("%.1f");
                break;

            case FIELD_TYPE_ALARMS:
                if (settings.alarmCount > 0) {
                    value = settings.alarmCount.format("%d");
                }
                break;

            case FIELD_TYPE_ALTITUDE:
                info = Activity.getActivityInfo();
                if (info.altitude != null) {
                    value = info.altitude.format("%d");
                }
                break;

            case FIELD_TYPE_TEMPERATURE:
 				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory)) {
					sample = SensorHistory.getTemperatureHistory(null).next();
					if ((sample != null) && (sample.data != null)) {
						var temperature = sample.data;

						if (settings.temperatureUnits == System.UNIT_STATUTE) {
							temperature = (temperature * (9.0 / 5)) + 32;
						}

						value = temperature.format("%d");
					}
				}

				break;
			
			case FIELD_TYPE_GARMIN_TEMPERATURE:
				var weather = Weather.getCurrentConditions();

				if (weather != null && weather.temperature != null) {

					var temp = weather.temperature;

						if (settings.temperatureUnits == System.UNIT_STATUTE) {
							temp = (temp * (9.0 / 5)) + 32;
						}

					value = temp.format("%d");

				} else {
					value = "--";
				}
				break;

            case FIELD_TYPE_PRESSURE:
                if ((Toybox has :SensorHistory) &&
                    (Toybox.SensorHistory has :getPressureHistory)) {

                    sample = SensorHistory.getPressureHistory(null).next();
                    if (sample != null && sample.data != null) {
                        value = (sample.data / 100).format("%.0f");
                    }
                }
                break;

            case FIELD_TYPE_HUMIDITY:
                if ((Toybox has :SensorHistory) &&
                    (Toybox.SensorHistory has :getHumidityHistory)) {

                    sample = SensorHistory.getHumidityHistory(null).next();
                    if (sample != null && sample.data != null) {
                        value = sample.data.format("%d") + "%";
                    }
                }
                break;
			case FIELD_TYPE_SUNRISE:
				value = getSunEventTime(true, settings.is24Hour);   // Sunrise
				break;
			case FIELD_TYPE_SUNSET:
				value = getSunEventTime(false, settings.is24Hour);   // Sunset
				break;
        }

        return (value.length() > mMaxFieldLength)
            ? value.substring(0, mMaxFieldLength)
            : value;
    }

	    private function getCachedSunTimes(isTomorrow as Lang.Boolean) as Lang.Array<Lang.Number?> {
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = nowInfo.day;

        // Invalidate cache if day changed
        if (mSunTimesCacheDay != today) {
            mSunTimesCacheDay = today;
            mCachedSunTimesToday = null;
            mCachedSunTimesTomorrow = null;
        }

        if (isTomorrow) {
            if (mCachedSunTimesTomorrow == null) {
                mCachedSunTimesTomorrow = getSunTimes(gLocationLat, gLocationLng, null, true);
            }
            return mCachedSunTimesTomorrow;
        } else {
            if (mCachedSunTimesToday == null) {
                mCachedSunTimesToday = getSunTimes(gLocationLat, gLocationLng, null, false);
            }
            return mCachedSunTimesToday;
        }
    }

    private function getSunEventTime(isSunrise as Lang.Boolean, is24Hour as Lang.Boolean) as Lang.String {
		gLocationLat = 48.7164f; gLocationLng = 21.2611f;

        if (gLocationLat == null || gLocationLng == null) {
            return "gps?";
        }

        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var now = nowInfo.hour + ((nowInfo.min + 1) / 60.0);

        var eventTime = null;

        // Use cached sun times instead of direct calls
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
            //var amPm = (h < 12) ? " AM" : " PM";
            var h12 = h % 12;
            if (h12 == 0) { h12 = 12; }
            return h12 + ":" + (m < 10 ? "0" : "") + m ; //+ amPm;
        }
    }


	/**
	* With thanks to ruiokada. Adapted, then translated to Monkey C, from:
	* https://gist.github.com/ruiokada/b28076d4911820ddcbbc
	*
	* Calculates sunrise and sunset in local time given latitude, longitude, and tz.
	*
	* Equations taken from:
	* https://en.wikipedia.org/wiki/Julian_day#Converting_Julian_or_Gregorian_calendar_date_to_Julian_Day_Number
	* https://en.wikipedia.org/wiki/Sunrise_equation#Complete_calculation_on_Earth
	*
	* @method getSunTimes
	* @param {Float} lat Latitude of location (South is negative)
	* @param {Float} lng Longitude of location (West is negative)
	* @param {Integer || null} tz Timezone hour offset. e.g. Pacific/Los Angeles is -8 (Specify null for system timezone)
	* @param {Boolean} tomorrow Calculate tomorrow's sunrise and sunset, instead of today's.
	* @return {Array} Returns array of length 2 with sunrise and sunset as floats.
	*                 Returns array with [null, -1] if the sun never rises, and [-1, null] if the sun never sets.
	*/
	private function getSunTimes(lat, lng, tz, tomorrow) as Lang.Array<Lang.Number?> {

		// Use double precision where possible, as floating point errors can affect result by minutes.
		lat = lat.toDouble();
		lng = lng.toDouble();

		var now = Time.now();
		if (tomorrow) {
			now = now.add(new Time.Duration(24 * 60 * 60));
		}
		var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
		var rad = Math.PI / 180.0d;
		var deg = 180.0d / Math.PI;
		
		// Calculate Julian date from Gregorian.
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

		// Number of days since Jan 1st, 2000 12:00.
		var n = jDate - 2451545.0d + 0.0008d;
		//Sys.println("n " + n);

		// Mean solar noon.
		var jStar = n - (lng / 360.0d);
		//Sys.println("jStar " + jStar);

		// Solar mean anomaly.
		var M = 357.5291d + (0.98560028d * jStar);
		var MFloor = Math.floor(M);
		var MFrac = M - MFloor;
		M = MFloor.toLong() % 360;
		M += MFrac;
		//Sys.println("M " + M);

		// Equation of the centre.
		var C = 1.9148d * Math.sin(M * rad)
			+ 0.02d * Math.sin(2 * M * rad)
			+ 0.0003d * Math.sin(3 * M * rad);
		//Sys.println("C " + C);

		// Ecliptic longitude.
		var lambda = (M + C + 180 + 102.9372d);
		var lambdaFloor = Math.floor(lambda);
		var lambdaFrac = lambda - lambdaFloor;
		lambda = lambdaFloor.toLong() % 360;
		lambda += lambdaFrac;
		//Sys.println("lambda " + lambda);

		// Solar transit.
		var jTransit = 2451545.5d + jStar
			+ 0.0053d * Math.sin(M * rad)
			- 0.0069d * Math.sin(2 * lambda * rad);
		//Sys.println("jTransit " + jTransit);

		// Declination of the sun.
		var delta = Math.asin(Math.sin(lambda * rad) * Math.sin(23.44d * rad));
		//Sys.println("delta " + delta);

		// Hour angle.
		var cosOmega = (Math.sin(-0.83d * rad) - Math.sin(lat * rad) * Math.sin(delta))
			/ (Math.cos(lat * rad) * Math.cos(delta));
		//Sys.println("cosOmega " + cosOmega);

		// Sun never rises.
		if (cosOmega > 1) {
			return [null, -1];
		}
		
		// Sun never sets.
		if (cosOmega < -1) {
			return [-1, null];
		}
		
		// Calculate times from omega.
		var omega = Math.acos(cosOmega) * deg;
		var jSet = jTransit + (omega / 360.0);
		var jRise = jTransit - (omega / 360.0);
		var deltaJSet = jSet - jDate;
		var deltaJRise = jRise - jDate;

		var tzOffset = (tz == null) ? (Sys.getClockTime().timeZoneOffset / 3600) : tz;
		return [
			/* localRise */ (deltaJRise * 24) + tzOffset,
			/* localSet */ (deltaJSet * 24) + tzOffset
		];
	}
}
