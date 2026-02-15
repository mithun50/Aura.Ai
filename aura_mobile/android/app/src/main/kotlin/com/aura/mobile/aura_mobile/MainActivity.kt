package com.aura.mobile.aura_mobile

import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.aura.mobile/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMessages" -> {
                        val count = call.argument<Int>("count") ?: 20
                        result.success(getMessages(count))
                    }
                    "searchMessages" -> {
                        val query = call.argument<String>("query") ?: ""
                        val limit = call.argument<Int>("limit") ?: 10
                        result.success(searchMessages(query, limit))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getMessages(count: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        try {
            val cursor: Cursor? = contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE
                ),
                null, null,
                "${Telephony.Sms.DATE} DESC"
            )
            cursor?.use {
                var i = 0
                while (it.moveToNext() && i < count) {
                    messages.add(mapOf(
                        "address" to it.getString(0),
                        "body" to it.getString(1),
                        "date" to it.getLong(2)
                    ))
                    i++
                }
            }
        } catch (e: Exception) {
            // Permission denied or other error - return empty
        }
        return messages
    }

    private fun searchMessages(query: String, limit: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        try {
            val selection = "${Telephony.Sms.ADDRESS} LIKE ? OR ${Telephony.Sms.BODY} LIKE ?"
            val selectionArgs = arrayOf("%$query%", "%$query%")
            val cursor: Cursor? = contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE
                ),
                selection, selectionArgs,
                "${Telephony.Sms.DATE} DESC"
            )
            cursor?.use {
                var i = 0
                while (it.moveToNext() && i < limit) {
                    messages.add(mapOf(
                        "address" to it.getString(0),
                        "body" to it.getString(1),
                        "date" to it.getLong(2)
                    ))
                    i++
                }
            }
        } catch (e: Exception) {
            // Permission denied or other error - return empty
        }
        return messages
    }
}
