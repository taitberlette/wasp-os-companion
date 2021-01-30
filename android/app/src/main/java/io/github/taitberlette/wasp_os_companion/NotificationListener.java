package io.github.taitberlette.wasp_os_companion;

import android.content.Intent;
import android.os.IBinder;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import android.app.Notification;

import androidx.annotation.Nullable;

public class NotificationListener extends NotificationListenerService {

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        try {
            if (getApplicationInfo().packageName.equals(sbn.getPackageName())) {
                return;
            }
            final Intent intent = new Intent("io.github.taitberlette.wasp_os_companion.notificationEvent");
            intent.putExtra("id", sbn.getId());
            intent.putExtra("app", sbn.getPackageName());
            intent.putExtra("title", sbn.getNotification().extras.getCharSequence(Notification.EXTRA_TITLE).toString());
            intent.putExtra("body", sbn.getNotification().extras.getCharSequence(Notification.EXTRA_TEXT).toString());
            intent.putExtra("command", "post");
            sendBroadcast(intent);
        } catch(Exception e) {}
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        try {
            if (getApplicationInfo().packageName.equals(sbn.getPackageName())) {
                return;
            }
            final Intent intent = new Intent("io.github.taitberlette.wasp_os_companion.notificationEvent");
            intent.putExtra("id", sbn.getId());
            intent.putExtra("app", sbn.getPackageName());
            intent.putExtra("title", sbn.getNotification().extras.getCharSequence(Notification.EXTRA_TITLE).toString());
            intent.putExtra("body", sbn.getNotification().extras.getCharSequence(Notification.EXTRA_TEXT).toString());
            intent.putExtra("command", "remove");
            sendBroadcast(intent);
        } catch(Exception e) {}

    }

    @Nullable@Override
    public IBinder onBind(Intent intent) {
        return super.onBind(intent);
    }
}