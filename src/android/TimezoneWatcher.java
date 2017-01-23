package cordova.outsystems.timezonewatcher;

import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.os.Bundle;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

import java.util.TimeZone;

/**
 * Created by <a href="mailto:joao.goncalves@outsystems.com">João Gonçalves</a> on 20/01/17.
 */
public class TimezoneWatcher extends CordovaPlugin {

    private static final String NOTIFICATION_TITLE_DEFAULT = "Timezone";
    private static final String NOTIFICATION_BODY_DEFAULT = "System timezone has changed.";

    public static final String OS_PREFS_NAME
            = "cordova.outsystems.timezonewatcher.preferences.PREFS_NAME";

    private static final String OS_PREFS_NOTIFICATION_TITLE
            = "cordova.outsystems.timezonewatcher.preferences.NOTIFICATION_TITLE";

    private static final String OS_PREFS_NOTIFICATION_BODY
            = "cordova.outsystems.timezonewatcher.preferences.NOTIFICATION_BODY";

    private String notificationTitle;
    private String notificationBody;
    private CallbackContext callbackContext;
    private boolean hasEventToDeliver = false;
    private boolean activityIsResumed = false;
    private boolean openedFromNotification = false;
    private IntentFilter timezoneWatcherIntentFilter;

    /**
     * Helper receiver that informs TWBoardcastReceiver if the application is running in foreground
     * Since this receiver is registered and unregistered on onResume/onPause, we can use it to
     * check for the state of application.
     */
    private BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Bundle result = getResultExtras(true);
            result.putBoolean(TWBroadcastReceiver.TW_BROADCAST_RESULT_APPLICATION_RUNNING, true);
            this.setResultExtras(result);

            TimezoneWatcher.this.hasEventToDeliver = true;
            if (callbackContext != null) {
                TimezoneWatcher.this.fireTimezoneChangeEvent(callbackContext);
            }
        }
    };

    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleLaunchIntent(intent);
    }

    private void handleLaunchIntent(Intent intent) {
        if (intent.hasExtra(TWBroadcastReceiver.TW_BROADCAST_EXTRA_KEY_TIMEZONE_CHANGED)) {
            this.openedFromNotification = true;
            if (activityIsResumed) {
                this.fireTimezoneChangeEvent(this.callbackContext);
            } else {
                this.hasEventToDeliver = true;
            }
        }
    }

    private void clearNotification(int notificationId) {
        NotificationManager notificationManager = (NotificationManager) this.cordova.getActivity()
                .getSystemService(Context.NOTIFICATION_SERVICE);

        notificationManager.cancel(notificationId);
    }

    @Override
    protected void pluginInitialize() {
        super.pluginInitialize();
        this.notificationTitle = getSavedNotificationTitle(this.cordova.getActivity());
        this.notificationBody = getSavedNotificationBody(this.cordova.getActivity());

        // Application was opened from notification
        Intent launchIntent = this.cordova.getActivity().getIntent();
        this.handleLaunchIntent(launchIntent);
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("deviceReady")) {
            this.deviceReady(args, callbackContext);
            return true;
        }
        return false;
    }

    private void deviceReady(JSONArray args, CallbackContext callbackContext) {
        this.callbackContext = callbackContext;

        String title;
        String body;
        try {
            title = args.getString(0);
            body = args.getString(1);
        } catch (JSONException e) {
            title = getSavedNotificationTitle(cordova.getActivity());
            body = getSavedNotificationBody(cordova.getActivity());
        }

        if (title.equals("null")) {
            title = getSavedNotificationTitle(cordova.getActivity());
        }
        if (body.equals("null")) {
            body = getSavedNotificationBody(cordova.getActivity());
        }

        setSavedNotificationTitle(cordova.getActivity(), title);
        setSavedNotificationBody(cordova.getActivity(), body);

        this.fireTimezoneChangeEvent(callbackContext);
    }

    @Override
    public void onResume(boolean multitasking) {
        super.onResume(multitasking);

        this.activityIsResumed = true;

        // Check application was launched from notification

        if (TWBroadcastReceiver.isDirty(cordova.getActivity())) {
            TWBroadcastReceiver.setDirtyTimezone(cordova.getActivity(), false);
            hasEventToDeliver = true;
        }

        clearNotification(TWBroadcastReceiver.TW_BROADCAST_EXTRA_NOTIFICATION_ID);

        // Register receiver
        if (this.timezoneWatcherIntentFilter == null) {
            timezoneWatcherIntentFilter = new IntentFilter(TWBroadcastReceiver.TW_ACTION_TIMEZONE_CHANGED);
        }
        this.cordova.getActivity().registerReceiver(mReceiver, this.timezoneWatcherIntentFilter);


        this.fireTimezoneChangeEvent(callbackContext);
    }

    @Override
    public void onPause(boolean multitasking) {
        this.activityIsResumed = false;
        // Unregister receiver
        this.cordova.getActivity().unregisterReceiver(this.mReceiver);
        super.onPause(multitasking);
    }

    private void fireTimezoneChangeEvent(CallbackContext callbackContext) {
        if (callbackContext == null) {
            return;
        }

        PluginResult result;

        if (this.hasEventToDeliver) {
            result = new PluginResult(PluginResult.Status.OK, TimeZone.getDefault().getID());
            this.hasEventToDeliver = false;
        } else {
            result = new PluginResult(PluginResult.Status.NO_RESULT);

        }
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);
    }

    public static String getSavedNotificationTitle(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(TimezoneWatcher.OS_PREFS_NAME, Context.MODE_PRIVATE);
        String title = prefs.getString(TimezoneWatcher.OS_PREFS_NOTIFICATION_TITLE, null);
        if (title == null) {
            title = NOTIFICATION_TITLE_DEFAULT;
        }
        return title;
    }

    public static String getSavedNotificationBody(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(TimezoneWatcher.OS_PREFS_NAME, Context.MODE_PRIVATE);
        String body = prefs.getString(TimezoneWatcher.OS_PREFS_NOTIFICATION_BODY, null);
        if (body == null) {
            body = NOTIFICATION_BODY_DEFAULT;
        }
        return body;
    }

    public static void setSavedNotificationTitle(Context ctx, String title) {
        SharedPreferences prefs = ctx.getSharedPreferences(TimezoneWatcher.OS_PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString(TimezoneWatcher.OS_PREFS_NOTIFICATION_BODY, title);
        editor.apply();
    }

    public static void setSavedNotificationBody(Context ctx, String body) {
        SharedPreferences prefs = ctx.getSharedPreferences(TimezoneWatcher.OS_PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString(TimezoneWatcher.OS_PREFS_NOTIFICATION_BODY, body);
        editor.apply();
    }

}
