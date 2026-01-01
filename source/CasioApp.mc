using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage as Storage;
using Toybox.Application.Properties as Properties;

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Globals
var gLocationLat = null;
var gLocationLng = null;

// Property helper functions
(:properties_and_storage)
function getPropertyValue(key as PropertyKeyType) as PropertyValueType {
    return Properties.getValue(key);
}

(:properties_and_storage)
function setPropertyValue(key as PropertyKeyType, value as PropertyValueType) as Void {
    Properties.setValue(key, value);
}

(:properties_and_storage)
function getStorageValue(key as PropertyKeyType) as PropertyValueType {
    return Storage.getValue(key);
}

(:properties_and_storage)
function setStorageValue(key as PropertyKeyType, value as PropertyValueType) as Void {
    Storage.setValue(key, value);
}

class CasioApp extends Application.AppBase {

    var mView;
    var mTopFields as Array<Number> = [];
    var mMiddleFields as Array<Number> = [];
    var mBottomFields as Array<Number> = [];

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new CasioView();
        onSettingsChanged(); // After creating view
        return [mView];
    }

    function getView() {
        return mView;
    }

    // Helper function to get integer properties
    function getIntProperty(key, defaultValue) {
        var value = getPropertyValue(key);
        if (value == null) {
            value = defaultValue;
        } else if (!(value instanceof Number)) {
            value = value.toNumber();
        }
        return value;
    }

    // Load all field configurations
    function loadFields() as Void {
        // Load Top Fields
        var topCount = getIntProperty("FieldCount", 0);
        mTopFields = [];
        for (var i = 1; i <= topCount; i++) {
            mTopFields.add(getIntProperty("Field" + i, -1));
        }

        // Load Middle Fields
        var middleCount = getIntProperty("FieldMiddleCount", 0);
        mMiddleFields = [];
        for (var i = 1; i <= middleCount; i++) {
            mMiddleFields.add(getIntProperty("FieldMiddle" + i, -1));
        }

        // Load Bottom Fields
        var bottomCount = getIntProperty("FieldBottomCount", 0);
        mBottomFields = [];
        for (var i = 1; i <= bottomCount; i++) {
            mBottomFields.add(getIntProperty("FieldBottom" + i, -1));
        }
    }

    // Check if a specific field type exists in any field array
    function hasField(fieldType) {
        // Check all field arrays
        for (var i = 0; i < mTopFields.size(); i++) {
            if (mTopFields[i] == fieldType) {
                return true;
            }
        }
        for (var i = 0; i < mMiddleFields.size(); i++) {
            if (mMiddleFields[i] == fieldType) {
                return true;
            }
        }
        for (var i = 0; i < mBottomFields.size(); i++) {
            if (mBottomFields[i] == fieldType) {
                return true;
            }
        }
        return false;
    }

    function onSettingsChanged() as Void {
        // Load all field configurations
        loadFields();

        // Handle location (same as Crystal approach)
        var location = Activity.getActivityInfo().currentLocation;
        
        if (location != null) {
            location = location.toDegrees();
            gLocationLat = location[0].toFloat();
            gLocationLng = location[1].toFloat();

            setStorageValue("LastLocationLat", gLocationLat);
            setStorageValue("LastLocationLng", gLocationLng);

        } else {
            var lat = getStorageValue("LastLocationLat");
            if (lat != null) {
                gLocationLat = lat;
            }

            var lng = getStorageValue("LastLocationLng");
            if (lng != null) {
                gLocationLng = lng;
            }
        }

        // Notify view if it exists
        if (mView != null) {
            // not needed in current state of watch, settings can load on reset of app
            //mView.onSettingsChanged();
        }

        WatchUi.requestUpdate();
    }

    // Get field arrays for the view
    function getTopFields() {
        return mTopFields;
    }

    function getMiddleFields() {
        return mMiddleFields;
    }

    function getBottomFields() {
        return mBottomFields;
    }
}

// Global helper function (similar to Crystal)
function getApp() as CasioApp {
    return Application.getApp() as CasioApp;
}