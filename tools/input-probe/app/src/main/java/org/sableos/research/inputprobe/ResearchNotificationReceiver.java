package org.sableos.research.inputprobe;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public final class ResearchNotificationReceiver extends BroadcastReceiver {
    public static final String ACTION_POST =
            "org.sableos.research.inputprobe.POST_TEST_NOTIFICATION";
    public static final String ACTION_CANCEL =
            "org.sableos.research.inputprobe.CANCEL_TEST_NOTIFICATION";

    private static final String TAG = "SableInputProbe";
    private static final String CHANNEL_ID = "sable_research";
    private static final String NOTIFICATION_TAG = "section_c_rear";
    private static final int NOTIFICATION_ID = 42001;

    @Override
    public void onReceive(Context context, Intent intent) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null || intent == null) {
            return;
        }

        String action = intent.getAction();
        if (ACTION_CANCEL.equals(action)) {
            manager.cancel(NOTIFICATION_TAG, NOTIFICATION_ID);
            Log.i(TAG, "RESEARCH_NOTIFICATION cancel");
            return;
        }

        if (!ACTION_POST.equals(action)) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Sable Research",
                NotificationManager.IMPORTANCE_DEFAULT);
        channel.setDescription("Local research notifications for Titan 2 SubScreen testing");
        manager.createNotificationChannel(channel);

        String phase = intent.getStringExtra("phase");
        if (phase == null || phase.isBlank()) {
            phase = "manual";
        }

        Intent launch = new Intent(context, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent contentIntent = PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification notification = new Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("SableSectionC")
                .setContentText("Input Probe rear notification test: " + phase)
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .build();

        manager.notify(NOTIFICATION_TAG, NOTIFICATION_ID, notification);
        Log.i(TAG, "RESEARCH_NOTIFICATION post phase=" + phase
                + " enabled=" + manager.areNotificationsEnabled());
    }
}
