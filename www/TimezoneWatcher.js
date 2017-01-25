var exec = require('cordova/exec');
var channel = require("cordova/channel");

var TIMEZONE_CHANGED = "timezone-changed-event";
var BACKGROUND_REFRESH_STATUS = {
    "AUTHORIZED": "authorized",
    "DENIED": "denied",
    "RESTRICTED": "restricted"
};

function start(title, body) {
    // Create native<->js channel for timezone-change events
    exec(function (timezone) {
        cordova.fireDocumentEvent(TIMEZONE_CHANGED, {
            "timezone": timezone
        });
    }, function () {

    }, "TimezoneWatcher", "deviceReady", [title, body]);
}

function getBackgroundRefreshStatus(success, fail)  {
    if(cordova.platformId === "android") {
        success("authorized");
    }
    if (success === undefined || fail === undefined) {
        throw new Error("No " + success === undefined ? "success" : "fail" + " callback was provided");
    }

    exec(success, fail, "TimezoneWatcher", "getBackgroundRefreshStatus", []);
}

function getLocationServiceStatus(success, fail) {
    if (cordova.platformId === "android") {
        fail("Not implemented.");
    }
    if (success === undefined || fail === undefined) {
        throw new Error("No " + success === undefined ? "success" : "fail" + " callback was provided");
    }

    exec(success, fail, "TimezoneWatcher", "getLocationServiceStatus", []);
}

module.exports = {
    "TIMEZONE_CHANGED": TIMEZONE_CHANGED,
    "BACKGROUND_REFRESH_STATUS": BACKGROUND_REFRESH_STATUS,
    "start": start,
    "getBackgroundRefreshStatus": getBackgroundRefreshStatus,
};
