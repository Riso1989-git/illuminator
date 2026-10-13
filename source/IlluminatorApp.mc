using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage as Storage;
using Toybox.Application.Properties as Properties;

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

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

class IlluminatorApp extends Application.AppBase {

    var mView;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Loc.refresh(true);              // T3.1: weather / activity / stored location
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new IlluminatorView();
        return [mView];
    }

    function getView() {
        return mView;
    }

    // T3.6: apply changed settings immediately (no restart needed).
    // Each drawable reloads its own settings; field configuration lives only in DataFields.
    function onSettingsChanged() as Void {
        Cache.invalidate();
        if (mView != null) {
            (mView as IlluminatorView).onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }
}

// Global helper function (similar to Crystal)
function getApp() as IlluminatorApp {
    return Application.getApp() as IlluminatorApp;
}