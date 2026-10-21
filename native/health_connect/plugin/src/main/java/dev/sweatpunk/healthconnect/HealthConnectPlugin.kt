package dev.sweatpunk.healthconnect

import android.content.Intent
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject

class HealthConnectPlugin(godot: Godot) : GodotPlugin(godot) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var lastPayload: String = emptyPayload("not_read", "")

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("permissions_updated", String::class.java),
        SignalInfo("health_data_ready", String::class.java),
        SignalInfo("health_error", String::class.java),
    )

    override fun onMainDestroy() {
        scope.cancel()
    }

    @UsedByGodot
    fun isAvailable(): Boolean {
        val current = activity ?: context ?: return false
        return HealthConnectClient.getSdkStatus(current) == HealthConnectClient.SDK_AVAILABLE
    }

    @UsedByGodot
    fun getSdkStatus(): String = sdkStatusName(currentSdkStatus())

    @UsedByGodot
    fun getLastPayload(): String = lastPayload

    @UsedByGodot
    fun requestPermissions() {
        val host = activity
        if (host == null) {
            emitSignal("health_error", "Godot activity is not available")
            return
        }
        val status = HealthConnectClient.getSdkStatus(host)
        if (status != HealthConnectClient.SDK_AVAILABLE) {
            val payload = permissionPayload(status, emptySet())
            lastPayload = payload
            emitSignal("permissions_updated", payload)
            return
        }
        PermissionBridge.onResult = { granted ->
            val payload = permissionPayload(HealthConnectClient.SDK_AVAILABLE, granted)
            lastPayload = payload
            emitSignal("permissions_updated", payload)
        }
        val intent = Intent(host, HealthConnectPermissionActivity::class.java).apply {
            putStringArrayListExtra(
                HealthConnectPermissionActivity.EXTRA_PERMISSIONS,
                ArrayList(requiredPermissions),
            )
        }
        host.startActivity(intent)
    }

    @UsedByGodot
    fun readRecent() {
        val host = activity ?: context
        if (host == null) {
            fail("Godot context is not available")
            return
        }
        val status = HealthConnectClient.getSdkStatus(host)
        if (status != HealthConnectClient.SDK_AVAILABLE) {
            fail("Health Connect status: ${sdkStatusName(status)}")
            return
        }
        scope.launch(Dispatchers.IO) {
            try {
                val client = HealthConnectClient.getOrCreate(host)
                val granted = client.permissionController.getGrantedPermissions()
                val missing = requiredPermissions - granted
                if (missing.isNotEmpty()) {
                    fail("permission_denied: ${missing.joinToString(",")}")
                    return@launch
                }
                val payload = HealthReader(client).read().toString()
                lastPayload = payload
                emitSignal("health_data_ready", payload)
            } catch (error: Throwable) {
                Log.e(TAG, "Health Connect read failed", error)
                fail(error.message ?: error.javaClass.simpleName)
            }
        }
    }

    private fun fail(message: String) {
        val payload = emptyPayload(sdkStatusName(currentSdkStatus()), message)
        lastPayload = payload
        emitSignal("health_error", message)
        emitSignal("health_data_ready", payload)
    }

    private fun currentSdkStatus(): Int {
        val current = activity ?: context ?: return HealthConnectClient.SDK_UNAVAILABLE
        return HealthConnectClient.getSdkStatus(current)
    }

    private fun permissionPayload(status: Int, granted: Set<String>): String {
        val grantedJson = JSONArray()
        granted.forEach { grantedJson.put(it) }
        return JSONObject()
            .put("platform", "android")
            .put("sdk_status", sdkStatusName(status))
            .put("granted", grantedJson)
            .put("steps", granted.contains(HealthPermission.getReadPermission(StepsRecord::class)))
            .put("exercise", granted.contains(HealthPermission.getReadPermission(ExerciseSessionRecord::class)))
            .put("active_calories", granted.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class)))
            .toString()
    }

    companion object {
        private const val TAG = "SweatpunkHealthConnect"

        val requiredPermissions: Set<String> = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        )

        fun sdkStatusName(status: Int): String = when (status) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            else -> "unavailable"
        }

        fun emptyPayload(status: String, error: String): String = JSONObject()
            .put("platform", "android")
            .put("available", status == "available" && error.isEmpty())
            .put("sdk_status", status)
            .put("device_verified", false)
            .put("steps_today", 0)
            .put("steps_today_manual", 0)
            .put("steps_today_device", 0)
            .put("steps_samples", JSONArray())
            .put("active_minutes_7d", 0)
            .put("active_minutes_7d_manual", 0)
            .put("active_calories_7d", 0)
            .put("active_calories_7d_manual", 0)
            .put("workouts", JSONArray())
            .put("error", error)
            .toString()
    }
}
