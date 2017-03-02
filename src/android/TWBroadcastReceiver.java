package cordova.outsystems.timezonewatcher;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.support.v4.app.NotificationCompat;

/**
 * Created by <a href="mailto:joao.goncalves@outsystems.com">João Gonçalves</a> on 20/01/17.
 *
 * @description Receives timezone changes from the SO and, if the application
 * is running, informs the plugin about that change, otherwise, schedules a
 * local notification informing the user about the change.
 */
public class TWBroadcastReceiver extends BroadcastReceiver {

    public static final String TW_ACTION_TIMEZONE_CHANGED
            = "cordova.outsystems.timezonewatcher.actions.TW_ACTION_TIMEZONE_CHANGED";

    public static final String TW_BROADCAST_RESULT_APPLICATION_RUNNING
            = "cordova.outsystems.timezonewatcher.result.key.TW_APPLICATION_RUNNING";

    public static final String TW_BROADCAST_EXTRA_KEY_TIMEZONE_CHANGED
            = "cordova.outsystems.timezonewatcher.result.key.TW_BROADCAST_EXTRA_KEY_TIMEZONE_CHANGED";

    public static final String TW_BROADCAST_EXTRA_KEY_NOTIFICATION_ID
            = "cordova.outsystems.timezonewatcher.result.key.TW_BROADCAST_EXTRA_KEY_NOTIFICATION_ID";

    public static final String TW_BROADCAST_PREFS_KEY_DIRTY_TIMEZONE
            = "cordova.outsystems.timezonewatcher.result.key.TW_BROADCAST_PREFS_KEY_DIRTY_TIMEZONE";

    public static final int TW_BROADCAST_EXTRA_NOTIFICATION_ID = 1337;

    @Override
    public void onReceive(Context context, Intent intent) {
        Intent outIntent = new Intent(TW_ACTION_TIMEZONE_CHANGED);
        context.sendOrderedBroadcast(outIntent, null, new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {

                Bundle result = getResultExtras(false);
                boolean appRunning = false;
                if (result != null) {
                    appRunning = result.getBoolean(TW_BROADCAST_RESULT_APPLICATION_RUNNING, false);
                }
                if (!appRunning) {
                    setDirtyTimezone(context, true);

                    NotificationCompat.Builder builder = new NotificationCompat.Builder(context);
                    builder.setDefaults(Notification.DEFAULT_ALL);
                    builder.setWhen(System.currentTimeMillis());
                    builder.setSmallIcon(context.getApplicationInfo().icon);
                    Bitmap largeIcon = BitmapFactory.decodeResource(context.getResources(), context.getApplicationInfo().icon);
                    builder.setLargeIcon(largeIcon);
                    builder.setContentTitle(TimezoneWatcher.getSavedNotificationTitle(context));
                    builder.setContentText(TimezoneWatcher.getSavedNotificationBody(context));
                    builder.setAutoCancel(true);

                    PackageManager packageManager = context.getPackageManager();
                    Intent resultIntent = packageManager.getLaunchIntentForPackage(context.getPackageName());
                    resultIntent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            .putExtra(TW_BROADCAST_EXTRA_KEY_TIMEZONE_CHANGED, true)
                            .putExtra(TW_BROADCAST_EXTRA_KEY_NOTIFICATION_ID, TW_BROADCAST_EXTRA_NOTIFICATION_ID);

                    PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, resultIntent, PendingIntent.FLAG_UPDATE_CURRENT);

                    builder.setContentIntent(pendingIntent);
                    NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
                    notificationManager.notify(TW_BROADCAST_EXTRA_NOTIFICATION_ID, builder.build());
                }
            }
        }, null, Activity.RESULT_OK, null, null);
    }

    public static void setDirtyTimezone(Context ctx, boolean dirty) {
        SharedPreferences prefs = ctx.getSharedPreferences(TimezoneWatcher.OS_PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putBoolean(TW_BROADCAST_PREFS_KEY_DIRTY_TIMEZONE, dirty);
        editor.apply();
    }

    public static boolean isDirty(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(TimezoneWatcher.OS_PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean(TW_BROADCAST_PREFS_KEY_DIRTY_TIMEZONE, false);
    }
}
