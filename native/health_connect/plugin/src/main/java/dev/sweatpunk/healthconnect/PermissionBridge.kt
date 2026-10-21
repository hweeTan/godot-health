package dev.sweatpunk.healthconnect

/**
 * One-shot callback from [HealthConnectPermissionActivity] back to the Godot plugin.
 * The Godot host activity is already started, so the permission contract has to live
 * on a dedicated activity that can register it in onCreate.
 */
internal object PermissionBridge {
    var onResult: ((Set<String>) -> Unit)? = null

    fun deliver(granted: Set<String>) {
        val callback = onResult
        onResult = null
        callback?.invoke(granted)
    }
}
