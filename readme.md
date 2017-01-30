# TimeZoneWatcher cordova plugin

Adds the ability to watch for the system timezone changes on all application states: foreground, background and even closed.

## Supported Platforms

- Android
- iOS

## Installation

```shell
cordova plugin add https://github.com/OutSystemsExperts/cordova-outsystems-timezonewatcher.git
```

## API Reference

Once installed, `cordova.plugins.TimezoneWatcher` is globally available and exposes the following API:

| Method                      | Description |
|-----------------------------|-------------|
| start(title, body)          | Sets a default title and body for local notifications shown when timezone changes. Additionally, checks if any timezone change have occurred and delivers through a document event named `timezone-changed-event` |
| getBackgroundRefreshStatus(success, fail)  | *iOS Only* retrieves the systems Refresh Status. Possible values are: <br/> `authorized` - Background updates are available for the app. <br/> `denied` - The user explicitly disabled background behavior for this app or for the whole system. <br/> `restricted` - Background updates are unavailable and the user cannot enable them again. For example, this status can occur when parental controls are in effect for the current user.|

## Usage

```javascript

document.addEventListener("deviceready", onDeviceReady, false);
function onDeviceReady() {
    
    // ...
    
    cordova.plugins.TimezoneWatcher.start("Timezone Info", "The timezone has changed.");
    
    // ...
    cordova.plugins.TimezoneWatcher.getBackgroundRefreshStatus(function(status){
      console.log(status);
    }, function(error){
      console.log(error);
    })

    // ...

}

```

## How it works

### iOS

This plugin leverages two main features of the iOS system:

- [UIApplicationSignificantTimeChangeNotification](https://developer.apple.com/reference/uikit/uiapplicationsignificanttimechangenotification) and  [NSSystemTimeZoneDidChangeNotification](https://developer.apple.com/reference/foundation/nssystemtimezonedidchangenotification) are responsible to delivering events to the application while in foreground informing that a timezone change has occurred.
- [Background Fetch](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/BackgroundExecution/BackgroundExecution.html) in order to periodically check for timezone changes while the application is closed. For this reason, the frequency on which this happens is out of the users and developer control.

### Android

A BroadcastReceiver registered to receive `android.intent.action.TIMEZONE_CHANGED` intent is responsible for delivering timezone change events to the application both in background and foreground states.

---

## Support

This plugin is not officially supported by OutSystems. You may use the [discussion forums](https://www.outsystems.com/forums/) to leave suggestions or obtain best-effort support from the community, including from OutSystems Experts who created this component.
Additionally, feel free to use the issue tracker.

### Contributors

- OutSystems - Mobility Experts
  - João Gonçalves, <joao.goncalves@outsystems.com>
  - Vitor Oliveira, <vitor.oliveira@outsystems.com>

---

LICENSE
=======


[The MIT License (MIT)](http://www.opensource.org/licenses/mit-license.html)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
