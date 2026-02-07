package com.lila.lila

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var reminderChannel: MethodChannel? = null
    private var pendingReminderTapId: String? = null
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reminderChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ReminderAlarmContract.CHANNEL_NAME,
        )
        reminderChannel?.setMethodCallHandler(::handleMethodCall)
        captureReminderTap(intent, notifyFlutter = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureReminderTap(intent, notifyFlutter = true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS_CODE) return
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        notificationPermissionResult?.success(granted)
        notificationPermissionResult = null
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleReminder" -> scheduleReminder(call, result)
            "cancelReminder" -> cancelReminder(call, result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
            "getInitialReminderTap" -> {
                result.success(pendingReminderTapId)
                pendingReminderTapId = null
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleReminder(call: MethodCall, result: MethodChannel.Result) {
        val reminderId = call.argument<String>("id")
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong()
        if (reminderId == null || title == null || body == null || triggerAtMillis == null) {
            result.error("invalid_args", "Missing required reminder scheduling args.", null)
            return
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(
            reminderId = reminderId,
            title = title,
            body = body,
            flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pendingIntent == null) {
            result.error("pending_intent_error", "Failed to create reminder pending intent.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        }
        result.success(true)
    }

    private fun cancelReminder(call: MethodCall, result: MethodChannel.Result) {
        val reminderId = call.argument<String>("id")
        if (reminderId.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(
            reminderId = reminderId,
            title = "",
            body = "",
            flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        result.success(true)
    }

    private fun reminderPendingIntent(
        reminderId: String,
        title: String,
        body: String,
        flags: Int,
    ): PendingIntent? {
        val intent = Intent(this, ReminderAlarmReceiver::class.java).apply {
            putExtra(ReminderAlarmContract.EXTRA_REMINDER_ID, reminderId)
            putExtra(ReminderAlarmContract.EXTRA_TITLE, title)
            putExtra(ReminderAlarmContract.EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(this, reminderId.hashCode(), intent, flags)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val current = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        )
        if (current == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        if (notificationPermissionResult != null) {
            result.error("pending_request", "Notification permission request already in progress.", null)
            return
        }
        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS_CODE,
        )
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun captureReminderTap(intent: Intent?, notifyFlutter: Boolean) {
        if (intent?.action != ReminderAlarmContract.ACTION_REMINDER_TAP) return
        val reminderId = intent.getStringExtra(ReminderAlarmContract.EXTRA_REMINDER_ID) ?: return
        pendingReminderTapId = reminderId

        if (!notifyFlutter) return
        reminderChannel?.invokeMethod("onReminderTapped", mapOf("id" to reminderId))
        pendingReminderTapId = null
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS_CODE = 5011
    }
}
