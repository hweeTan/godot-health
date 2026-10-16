package dev.sweatpunk.healthconnect

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

private const val PAGE_SIZE = 500
private const val MAX_PAGES = 10
private const val MAX_SAMPLES = 100

/**
 * Reads the spike's Health Connect slice: today's steps, plus workouts and
 * active calories over the last 7 days. Manual entries are flagged from
 * metadata.recordingMethod. Active minutes are the sum of exercise-session
 * durations. Health Connect has no Apple Exercise Time equivalent.
 */
internal class HealthReader(private val client: HealthConnectClient) {
    suspend fun read(): JSONObject {
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val startOfToday = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val sevenDaysAgo = now.minus(7, ChronoUnit.DAYS)

        val steps = readPages { token ->
            client.readRecords(
                ReadRecordsRequest<StepsRecord>(
                    timeRangeFilter = TimeRangeFilter.between(startOfToday, now),
                    pageSize = PAGE_SIZE,
                    pageToken = token,
                ),
            )
        }
        val sessions = readPages { token ->
            client.readRecords(
                ReadRecordsRequest<ExerciseSessionRecord>(
                    timeRangeFilter = TimeRangeFilter.between(sevenDaysAgo, now),
                    pageSize = PAGE_SIZE,
                    pageToken = token,
                ),
            )
        }
        val calories = readPages { token ->
            client.readRecords(
                ReadRecordsRequest<ActiveCaloriesBurnedRecord>(
                    timeRangeFilter = TimeRangeFilter.between(sevenDaysAgo, now),
                    pageSize = PAGE_SIZE,
                    pageToken = token,
                ),
            )
        }

        var stepsToday = 0L
        var stepsManual = 0L
        val stepSamples = JSONArray()
        var stepTruncated = false
        for (record in steps) {
            val manual = isManual(record.metadata.recordingMethod)
            stepsToday += record.count
            if (manual) {
                stepsManual += record.count
            }
            if (stepSamples.length() < MAX_SAMPLES) {
                stepSamples.put(
                    JSONObject()
                        .put("count", record.count)
                        .put("start", record.startTime.toString())
                        .put("end", record.endTime.toString())
                        .put("manual", manual)
                        .put("recording_method", recordingMethodName(record.metadata.recordingMethod))
                        .put("source", record.metadata.dataOrigin.packageName),
                )
            } else {
                stepTruncated = true
            }
        }

        var activeSeconds = 0L
        var activeSecondsManual = 0L
        val workouts = JSONArray()
        var workoutsTruncated = false
        for (session in sessions) {
            val seconds = ChronoUnit.SECONDS.between(session.startTime, session.endTime).coerceAtLeast(0)
            val manual = isManual(session.metadata.recordingMethod)
            activeSeconds += seconds
            if (manual) {
                activeSecondsManual += seconds
            }
            if (workouts.length() < MAX_SAMPLES) {
                workouts.put(
                    JSONObject()
                        .put("activity", exerciseName(session.exerciseType))
                        .put("exercise_type", session.exerciseType)
                        .put("start", session.startTime.toString())
                        .put("end", session.endTime.toString())
                        .put("duration_seconds", seconds)
                        .put("manual", manual)
                        .put("recording_method", recordingMethodName(session.metadata.recordingMethod))
                        .put("source", session.metadata.dataOrigin.packageName)
                        .put("title", session.title ?: ""),
                )
            } else {
                workoutsTruncated = true
            }
        }

        var caloriesTotal = 0.0
        var caloriesManual = 0.0
        for (record in calories) {
            val kcal = record.energy.inKilocalories
            caloriesTotal += kcal
            if (isManual(record.metadata.recordingMethod)) {
                caloriesManual += kcal
            }
        }

        return JSONObject()
            .put("platform", "android")
            .put("available", true)
            .put("sdk_status", "available")
            .put("device_verified", true)
            .put("steps_today", stepsToday)
            .put("steps_today_manual", stepsManual)
            .put("steps_today_device", (stepsToday - stepsManual).coerceAtLeast(0))
            .put("steps_samples", stepSamples)
            .put("steps_samples_truncated", stepTruncated)
            .put("active_seconds_7d", activeSeconds)
            .put("active_minutes_7d", activeSeconds / 60)
            .put("active_seconds_7d_manual", activeSecondsManual)
            .put("active_minutes_7d_manual", activeSecondsManual / 60)
            .put("active_minutes_source", "sum of ExerciseSessionRecord durations")
            .put("active_calories_7d", caloriesTotal)
            .put("active_calories_7d_manual", caloriesManual)
            .put("workouts", workouts)
            .put("workouts_truncated", workoutsTruncated)
            .put("error", "")
    }

    private suspend fun <T : androidx.health.connect.client.records.Record> readPages(
        fetch: suspend (pageToken: String?) -> androidx.health.connect.client.response.ReadRecordsResponse<T>,
    ): List<T> {
        val records = ArrayList<T>()
        var pageToken: String? = null
        var pages = 0
        do {
            val response = fetch(pageToken)
            records.addAll(response.records)
            pageToken = response.pageToken
            pages += 1
        } while (pageToken != null && pages < MAX_PAGES)
        return records
    }

    companion object {
        fun isManual(method: Int): Boolean = method == Metadata.RECORDING_METHOD_MANUAL_ENTRY

        fun recordingMethodName(method: Int): String = when (method) {
            Metadata.RECORDING_METHOD_MANUAL_ENTRY -> "manual_entry"
            Metadata.RECORDING_METHOD_ACTIVELY_RECORDED -> "actively_recorded"
            Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED -> "automatically_recorded"
            else -> "unknown"
        }

        fun exerciseName(type: Int): String = when (type) {
            ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT -> "other"
            ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON -> "badminton"
            ExerciseSessionRecord.EXERCISE_TYPE_BASEBALL -> "baseball"
            ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL -> "basketball"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "biking"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "biking_stationary"
            ExerciseSessionRecord.EXERCISE_TYPE_BOOT_CAMP -> "boot_camp"
            ExerciseSessionRecord.EXERCISE_TYPE_BOXING -> "boxing"
            ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS -> "calisthenics"
            ExerciseSessionRecord.EXERCISE_TYPE_CRICKET -> "cricket"
            ExerciseSessionRecord.EXERCISE_TYPE_DANCING -> "dancing"
            ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL -> "elliptical"
            ExerciseSessionRecord.EXERCISE_TYPE_EXERCISE_CLASS -> "exercise_class"
            ExerciseSessionRecord.EXERCISE_TYPE_FENCING -> "fencing"
            ExerciseSessionRecord.EXERCISE_TYPE_FOOTBALL_AMERICAN -> "football_american"
            ExerciseSessionRecord.EXERCISE_TYPE_FOOTBALL_AUSTRALIAN -> "football_australian"
            ExerciseSessionRecord.EXERCISE_TYPE_FRISBEE_DISC -> "frisbee"
            ExerciseSessionRecord.EXERCISE_TYPE_GOLF -> "golf"
            ExerciseSessionRecord.EXERCISE_TYPE_GUIDED_BREATHING -> "guided_breathing"
            ExerciseSessionRecord.EXERCISE_TYPE_GYMNASTICS -> "gymnastics"
            ExerciseSessionRecord.EXERCISE_TYPE_HANDBALL -> "handball"
            ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING -> "hiit"
            ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "hiking"
            ExerciseSessionRecord.EXERCISE_TYPE_ICE_HOCKEY -> "ice_hockey"
            ExerciseSessionRecord.EXERCISE_TYPE_ICE_SKATING -> "ice_skating"
            ExerciseSessionRecord.EXERCISE_TYPE_MARTIAL_ARTS -> "martial_arts"
            ExerciseSessionRecord.EXERCISE_TYPE_PADDLING -> "paddling"
            ExerciseSessionRecord.EXERCISE_TYPE_PARAGLIDING -> "paragliding"
            ExerciseSessionRecord.EXERCISE_TYPE_PILATES -> "pilates"
            ExerciseSessionRecord.EXERCISE_TYPE_RACQUETBALL -> "racquetball"
            ExerciseSessionRecord.EXERCISE_TYPE_ROCK_CLIMBING -> "rock_climbing"
            ExerciseSessionRecord.EXERCISE_TYPE_ROLLER_HOCKEY -> "roller_hockey"
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING -> "rowing"
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> "rowing_machine"
            ExerciseSessionRecord.EXERCISE_TYPE_RUGBY -> "rugby"
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "running"
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "running_treadmill"
            ExerciseSessionRecord.EXERCISE_TYPE_SAILING -> "sailing"
            ExerciseSessionRecord.EXERCISE_TYPE_SCUBA_DIVING -> "scuba_diving"
            ExerciseSessionRecord.EXERCISE_TYPE_SKATING -> "skating"
            ExerciseSessionRecord.EXERCISE_TYPE_SKIING -> "skiing"
            ExerciseSessionRecord.EXERCISE_TYPE_SNOWBOARDING -> "snowboarding"
            ExerciseSessionRecord.EXERCISE_TYPE_SNOWSHOEING -> "snowshoeing"
            ExerciseSessionRecord.EXERCISE_TYPE_SOCCER -> "soccer"
            ExerciseSessionRecord.EXERCISE_TYPE_SOFTBALL -> "softball"
            ExerciseSessionRecord.EXERCISE_TYPE_SQUASH -> "squash"
            ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING -> "stair_climbing"
            ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE -> "stair_climbing_machine"
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> "strength_training"
            ExerciseSessionRecord.EXERCISE_TYPE_STRETCHING -> "stretching"
            ExerciseSessionRecord.EXERCISE_TYPE_SURFING -> "surfing"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "swimming_open_water"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "swimming_pool"
            ExerciseSessionRecord.EXERCISE_TYPE_TABLE_TENNIS -> "table_tennis"
            ExerciseSessionRecord.EXERCISE_TYPE_TENNIS -> "tennis"
            ExerciseSessionRecord.EXERCISE_TYPE_VOLLEYBALL -> "volleyball"
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
            ExerciseSessionRecord.EXERCISE_TYPE_WATER_POLO -> "water_polo"
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "weightlifting"
            ExerciseSessionRecord.EXERCISE_TYPE_WHEELCHAIR -> "wheelchair"
            ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "yoga"
            else -> "type_$type"
        }
    }
}
