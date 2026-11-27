package com.example.menu_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alertAction = "com.example.menu_app.OPEN_ALERT"
    private var ordersChannel: MethodChannel? = null
    private val serviceChannel = "incoming_orders"
    private val waiterChannel = "waiter_calls"
    private val billChannel = "bills_requested"
    private val paymentChannel = "payments_confirmed"
    private val serviceVibration = longArrayOf(0, 180, 90, 220)
    private val paymentVibration = longArrayOf(0, 100, 75, 100, 75, 260)
    private val paymentSound get() = Uri.parse("android.resource://$packageName/raw/payment_confirmed")
    private val billSound get() = Uri.parse("android.resource://$packageName/raw/bill_requested")
    private val orderSound get() = Uri.parse("android.resource://$packageName/raw/new_order")
    private val waiterSound get() = Uri.parse("android.resource://$packageName/raw/waiter_bell")
    private val notificationManager get() = getSystemService(NotificationManager::class.java)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ordersChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "menuapp/orders")
        ordersChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeOpenedAlert" -> {
                    val target = intent.takeIf { it.action == alertAction }?.data
                    if (target != null) setIntent(Intent(this, MainActivity::class.java))
                    result.success(target?.let { mapOf("type" to it.host, "id" to it.lastPathSegment) })
                }
                "prepare" -> {
                    if (Build.VERSION.SDK_INT >= 26) {
                        createChannel(serviceChannel, "Pedidos nuevos", orderSound, serviceVibration)
                        createChannel(waiterChannel, "Llamadas al mesero", waiterSound, serviceVibration)
                        createChannel(billChannel, "Solicitudes de pago", billSound, serviceVibration)
                        createChannel(paymentChannel, "Pagos confirmados", paymentSound, paymentVibration)
                    }
                    val preferences = getPreferences(MODE_PRIVATE)
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                        !preferences.getBoolean("requested_order_notifications", false)) {
                        preferences.edit().putBoolean("requested_order_notifications", true).apply()
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 102)
                    }
                    result.success(null)
                }
                "show" -> {
                    val type = call.argument<String>("type")
                    val id = call.argument<Any>("id")?.toString()
                    val table = call.argument<String>("table")
                    if (type != null && id != null && table != null) showAlert(type, id, table)
                    result.success(null)
                }
                "clear" -> {
                    notificationManager.cancelAll()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == alertAction) ordersChannel?.invokeMethod("alertOpened", null)
    }

    private fun createChannel(id: String, name: String, sound: Uri, vibration: LongArray) {
        val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
        channel.setSound(sound, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
        channel.vibrationPattern = vibration
        notificationManager.createNotificationChannel(channel)
    }

    private fun showAlert(type: String, id: String, table: String) {
        if (!notificationManager.areNotificationsEnabled()) return
        val title = when (type) {
            "new_order" -> "Nuevo pedido"
            "bill_requested" -> "Pago solicitado"
            "payment_confirmed" -> "Pago confirmado"
            "waiter_called" -> "Llamada al mesero"
            else -> return
        }
        val channel = when (type) {
            "bill_requested" -> billChannel
            "payment_confirmed" -> paymentChannel
            "waiter_called" -> waiterChannel
            else -> serviceChannel
        }
        val detail = when (type) {
            "new_order" -> "$table · Pedido #$id"
            "payment_confirmed" -> "$table · Mesa disponible"
            "waiter_called" -> "$table · El cliente solicita asistencia"
            else -> "$table · El cliente solicita pagar"
        }
        val target = Uri.Builder().scheme("menuapp-alert").authority(type).appendPath(id).build()
        val launch = Intent(this, MainActivity::class.java).setAction(alertAction).setData(target)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, channel)
        } else {
            val sound = when (channel) {
                billChannel -> billSound
                paymentChannel -> paymentSound
                waiterChannel -> waiterSound
                else -> orderSound
            }
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
                .setSound(sound)
                .setVibrate(if (channel == paymentChannel) paymentVibration else serviceVibration)
        }
        notificationManager.notify("$type:$id", 0, builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(detail)
            .setCategory(Notification.CATEGORY_EVENT)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build())
    }
}
