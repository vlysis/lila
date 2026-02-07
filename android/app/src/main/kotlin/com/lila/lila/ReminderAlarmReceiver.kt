package com.lila.lila

import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra(ReminderAlarmContract.EXTRA_REMINDER_ID) ?: return
        val title = intent.getStringExtra(ReminderAlarmContract.EXTRA_TITLE) ?: "Reminder"
        val body = intent.getStringExtra(ReminderAlarmContract.EXTRA_BODY) ?: ""

        ensureNotificationChannel(context)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            action = ReminderAlarmContract.ACTION_REMINDER_TAP
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(ReminderAlarmContract.EXTRA_REMINDER_ID, reminderId)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            reminderId.hashCode(),
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(
            context,
            ReminderAlarmContract.NOTIFICATION_CHANNEL_ID,
        )
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            .setVibrate(longArrayOf(0, 350, 220, 500))
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(reminderId.hashCode(), notification)
        } catch (_: SecurityException) {
            // Notifications disabled or permission not granted.
        }
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(ReminderAlarmContract.NOTIFICATION_CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            ReminderAlarmContract.NOTIFICATION_CHANNEL_ID,
            ReminderAlarmContract.NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = ReminderAlarmContract.NOTIFICATION_CHANNEL_DESCRIPTION
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 350, 220, 500)
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build(),
            )
        }
        manager.createNotificationChannel(channel)
    }
}
