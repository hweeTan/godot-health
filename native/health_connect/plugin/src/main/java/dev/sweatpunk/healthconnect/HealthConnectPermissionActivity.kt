package dev.sweatpunk.healthconnect

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.health.connect.client.PermissionController

/**
 * Shows a short rationale, then launches the Health Connect permission sheet.
 * Also serves the Android 14 privacy-dashboard rationale alias.
 */
class HealthConnectPermissionActivity : ComponentActivity() {
    private val permissionLauncher =
        registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            PermissionBridge.deliver(granted)
            finish()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val usageOnly = intent?.action == ACTION_VIEW_PERMISSION_USAGE ||
            intent?.action == "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"
        showRationale(usageOnly)
    }

    private fun showRationale(usageOnly: Boolean) {
        val density = resources.displayMetrics.density
        val pad = (24 * density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            setBackgroundColor(Color.parseColor("#0D1020"))
            gravity = Gravity.CENTER_HORIZONTAL
        }

        root.addView(TextView(this).apply {
            text = "SWEATPUNK"
            setTextColor(Color.parseColor("#FF2BD6"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.MONOSPACE
        })
        root.addView(TextView(this).apply {
            text = "Health access"
            setTextColor(Color.parseColor("#E8FFF4"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, pad / 2, 0, pad)
        })
        root.addView(TextView(this).apply {
            text = RATIONALE
            setTextColor(Color.parseColor("#C8F6EA"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setLineSpacing(0f, 1.25f)
        })

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, pad, 0, 0)
        }
        if (!usageOnly) {
            buttonRow.addView(Button(this).apply {
                text = "Continue to Health Connect"
                setOnClickListener { launchPermissionRequest() }
            })
            buttonRow.addView(Button(this).apply {
                text = "Not now"
                setOnClickListener {
                    PermissionBridge.deliver(emptySet())
                    finish()
                }
            })
        } else {
            buttonRow.addView(Button(this).apply {
                text = "Close"
                setOnClickListener { finish() }
            })
        }
        root.addView(buttonRow)
        setContentView(root)
    }

    private fun launchPermissionRequest() {
        val requested = intent.getStringArrayListExtra(EXTRA_PERMISSIONS)?.toSet()
            ?: HealthConnectPlugin.requiredPermissions
        permissionLauncher.launch(requested)
    }

    companion object {
        const val EXTRA_PERMISSIONS = "dev.sweatpunk.healthconnect.PERMISSIONS"
        private const val ACTION_VIEW_PERMISSION_USAGE = "android.intent.action.VIEW_PERMISSION_USAGE"
        private const val RATIONALE =
            "Sweatpunk reads today's steps, the last 7 days of workouts, and active calories so your character can earn energy. " +
                "Manually entered records are flagged and kept out of co-op later. " +
                "Raw samples stay on this phone. Nothing here is used for ads."
    }
}
