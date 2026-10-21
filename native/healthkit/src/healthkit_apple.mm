#include "healthkit_apple.h"

#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

namespace {

NSString *iso8601(NSDate *date) {
	if (date == nil) {
		return @"";
	}
	NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
	formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
	return [formatter stringFromDate:date] ?: @"";
}

BOOL was_user_entered(HKObject *sample) {
	NSNumber *flag = sample.metadata[HKMetadataKeyWasUserEntered];
	return flag != nil && flag.boolValue;
}

NSString *recording_method(HKObject *sample) {
	return was_user_entered(sample) ? @"user_entered" : @"device";
}

NSString *source_name(HKObject *sample) {
	return sample.sourceRevision.source.bundleIdentifier ?: sample.sourceRevision.source.name ?: @"";
}

NSString *workout_name(HKWorkoutActivityType type) {
	switch (type) {
		case HKWorkoutActivityTypeRunning:
			return @"running";
		case HKWorkoutActivityTypeWalking:
			return @"walking";
		case HKWorkoutActivityTypeCycling:
			return @"cycling";
		case HKWorkoutActivityTypeSwimming:
			return @"swimming";
		case HKWorkoutActivityTypeHiking:
			return @"hiking";
		case HKWorkoutActivityTypeYoga:
			return @"yoga";
		case HKWorkoutActivityTypeFunctionalStrengthTraining:
			return @"strength_training";
		case HKWorkoutActivityTypeTraditionalStrengthTraining:
			return @"strength_training";
		case HKWorkoutActivityTypeHighIntensityIntervalTraining:
			return @"hiit";
		case HKWorkoutActivityTypeDance:
			return @"dancing";
		case HKWorkoutActivityTypeElliptical:
			return @"elliptical";
		case HKWorkoutActivityTypeRowing:
			return @"rowing";
		case HKWorkoutActivityTypeStairClimbing:
			return @"stair_climbing";
		case HKWorkoutActivityTypeCoreTraining:
			return @"core_training";
		case HKWorkoutActivityTypeFlexibility:
			return @"stretching";
		default:
			return [NSString stringWithFormat:@"activity_%lu", (unsigned long)type];
	}
}

HKHealthStore *shared_store() {
	static HKHealthStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		store = [[HKHealthStore alloc] init];
	});
	return store;
}

NSSet<HKObjectType *> *read_types() {
	return [NSSet setWithObjects:
			[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount],
			[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierAppleExerciseTime],
			[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned],
			[HKObjectType workoutType],
			nil];
}

NSString *json_string(NSDictionary *payload) {
	NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
	if (data == nil) {
		return @"{}";
	}
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

} // namespace

bool healthkit_is_available() {
	return [HKHealthStore isHealthDataAvailable];
}

void healthkit_request_authorization(const std::function<void(bool ok, const std::string &error)> &done) {
	if (![HKHealthStore isHealthDataAvailable]) {
		done(false, "Health data is not available on this device");
		return;
	}
	auto callback = done;
	[shared_store() requestAuthorizationToShareTypes:nil
										   readTypes:read_types()
										  completion:^(BOOL success, NSError *error) {
											  std::string message = error ? std::string(error.localizedDescription.UTF8String) : "";
											  callback(success, message);
										  }];
}

void healthkit_read_recent(const std::function<void(const std::string &json)> &done) {
	auto callback = done;
	if (![HKHealthStore isHealthDataAvailable]) {
		done("{\"platform\":\"ios\",\"available\":false,\"sdk_status\":\"unavailable\",\"device_verified\":false,\"error\":\"Health data is not available on this device\"}");
		return;
	}

	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *now = [NSDate date];
	NSDate *start_of_today = [calendar startOfDayForDate:now];
	NSDate *seven_days_ago = [calendar dateByAddingUnit:NSCalendarUnitDay value:-7 toDate:now options:0];
	HKHealthStore *store = shared_store();

	dispatch_group_t group = dispatch_group_create();
	NSMutableDictionary *payload = [@{
		@"platform" : @"ios",
		@"available" : @YES,
		@"sdk_status" : @"available",
		@"device_verified" : @YES,
		@"active_minutes_source" : @"HKQuantityTypeIdentifierAppleExerciseTime",
		@"error" : @"",
	} mutableCopy];

	dispatch_group_enter(group);
	HKSampleQuery *steps = [[HKSampleQuery alloc]
		initWithSampleType:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount]
				 predicate:[HKQuery predicateForSamplesWithStartDate:start_of_today endDate:now options:HKQueryOptionStrictStartDate]
					 limit:HKObjectQueryNoLimit
			sortDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:YES] ]
			 resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {
				 long steps_today = 0;
				 long steps_manual = 0;
				 NSMutableArray *samples = [NSMutableArray array];
				 BOOL truncated = NO;
				 if (error == nil) {
					 for (HKQuantitySample *sample in results) {
						 double count = [sample.quantity doubleValueForUnit:[HKUnit countUnit]];
						 BOOL manual = was_user_entered(sample);
						 steps_today += (long)llround(count);
						 if (manual) {
							 steps_manual += (long)llround(count);
						 }
						 if (samples.count < 100) {
							 [samples addObject:@{
								 @"count" : @((long)llround(count)),
								 @"start" : iso8601(sample.startDate),
								 @"end" : iso8601(sample.endDate),
								 @"manual" : @(manual),
								 @"recording_method" : recording_method(sample),
								 @"source" : source_name(sample),
							 }];
						 } else {
							 truncated = YES;
						 }
					 }
				 }
				 @synchronized(payload) {
					 payload[@"steps_today"] = @(steps_today);
					 payload[@"steps_today_manual"] = @(steps_manual);
					 payload[@"steps_today_device"] = @(MAX(steps_today - steps_manual, 0));
					 payload[@"steps_samples"] = samples;
					 payload[@"steps_samples_truncated"] = @(truncated);
					 if (error != nil) {
						 payload[@"error"] = error.localizedDescription ?: @"step query failed";
					 }
				 }
				 dispatch_group_leave(group);
			 }];

	dispatch_group_enter(group);
	HKSampleQuery *exercise = [[HKSampleQuery alloc]
		initWithSampleType:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierAppleExerciseTime]
				 predicate:[HKQuery predicateForSamplesWithStartDate:seven_days_ago endDate:now options:HKQueryOptionStrictStartDate]
					 limit:HKObjectQueryNoLimit
			sortDescriptors:nil
			 resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {
				 double minutes = 0;
				 double manual_minutes = 0;
				 if (error == nil) {
					 HKUnit *minute = [HKUnit minuteUnit];
					 for (HKQuantitySample *sample in results) {
						 double value = [sample.quantity doubleValueForUnit:minute];
						 minutes += value;
						 if (was_user_entered(sample)) {
							 manual_minutes += value;
						 }
					 }
				 }
				 @synchronized(payload) {
					 payload[@"active_minutes_7d"] = @((long)llround(minutes));
					 payload[@"active_minutes_7d_manual"] = @((long)llround(manual_minutes));
					 payload[@"active_seconds_7d"] = @((long)llround(minutes * 60.0));
					 payload[@"active_seconds_7d_manual"] = @((long)llround(manual_minutes * 60.0));
				 }
				 dispatch_group_leave(group);
			 }];

	dispatch_group_enter(group);
	HKSampleQuery *energy = [[HKSampleQuery alloc]
		initWithSampleType:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned]
				 predicate:[HKQuery predicateForSamplesWithStartDate:seven_days_ago endDate:now options:HKQueryOptionStrictStartDate]
					 limit:HKObjectQueryNoLimit
			sortDescriptors:nil
			 resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {
				 double kcal = 0;
				 double manual_kcal = 0;
				 if (error == nil) {
					 HKUnit *unit = [HKUnit kilocalorieUnit];
					 for (HKQuantitySample *sample in results) {
						 double value = [sample.quantity doubleValueForUnit:unit];
						 kcal += value;
						 if (was_user_entered(sample)) {
							 manual_kcal += value;
						 }
					 }
				 }
				 @synchronized(payload) {
					 payload[@"active_calories_7d"] = @(kcal);
					 payload[@"active_calories_7d_manual"] = @(manual_kcal);
				 }
				 dispatch_group_leave(group);
			 }];

	dispatch_group_enter(group);
	HKSampleQuery *workouts = [[HKSampleQuery alloc]
		initWithSampleType:[HKObjectType workoutType]
				 predicate:[HKQuery predicateForSamplesWithStartDate:seven_days_ago endDate:now options:HKQueryOptionStrictStartDate]
					 limit:HKObjectQueryNoLimit
			sortDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:NO] ]
			 resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {
				 NSMutableArray *items = [NSMutableArray array];
				 BOOL truncated = NO;
				 if (error == nil) {
					 for (HKWorkout *workout in results) {
						 BOOL manual = was_user_entered(workout);
						 if (items.count < 100) {
							 double burned = 0;
							 if (workout.totalEnergyBurned != nil) {
								 burned = [workout.totalEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]];
							 }
							 [items addObject:@{
								 @"activity" : workout_name(workout.workoutActivityType),
								 @"start" : iso8601(workout.startDate),
								 @"end" : iso8601(workout.endDate),
								 @"duration_seconds" : @((long)llround(workout.duration)),
								 @"active_calories" : @(burned),
								 @"manual" : @(manual),
								 @"recording_method" : recording_method(workout),
								 @"source" : source_name(workout),
							 }];
						 } else {
							 truncated = YES;
						 }
					 }
				 }
				 @synchronized(payload) {
					 payload[@"workouts"] = items;
					 payload[@"workouts_truncated"] = @(truncated);
				 }
				 dispatch_group_leave(group);
			 }];

	[store executeQuery:steps];
	[store executeQuery:exercise];
	[store executeQuery:energy];
	[store executeQuery:workouts];

	dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		std::string json([json_string(payload) UTF8String]);
		callback(json);
	});
}
