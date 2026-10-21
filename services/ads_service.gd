extends Node

signal log_line(message: String)
signal reward_earned(reward_type: String, amount: int)

## Google's public sample ids. They serve test ads and must not be replaced
## with production ids in this spike.
const TEST_APP_ID_ANDROID := "ca-app-pub-3940256099942544~3347511713"
const TEST_APP_ID_IOS := "ca-app-pub-3940256099942544~1458002511"
const TEST_REWARDED_ANDROID := "ca-app-pub-3940256099942544/5224354917"
const TEST_REWARDED_IOS := "ca-app-pub-3940256099942544/1712485313"

var plugin_ready: bool = false
var initialized: bool = false
var _rewarded_ad: RewardedAd
var _reward_listener := OnUserEarnedRewardListener.new()
var _load_callback := RewardedAdLoadCallback.new()
var _content_callback := FullScreenContentCallback.new()


func _ready() -> void:
	plugin_ready = Engine.has_singleton("PoingGodotAdMob")
	_reward_listener.on_user_earned_reward = _on_user_earned_reward
	_load_callback.on_ad_failed_to_load = _on_ad_failed_to_load
	_load_callback.on_ad_loaded = _on_ad_loaded
	_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		_log("Rewarded ad dismissed.")
	_content_callback.on_ad_failed_to_show_full_screen_content = func(err: AdError) -> void:
		_log("Rewarded ad failed to show: %s" % err.message)
	_content_callback.on_ad_showed_full_screen_content = func() -> void:
		_log("Rewarded ad showing.")


func rewarded_unit_id() -> String:
	if OS.get_name() == "iOS":
		return TEST_REWARDED_IOS
	return TEST_REWARDED_ANDROID


func request_consent() -> void:
	if not plugin_ready:
		_log("UMP plugin is not on this desktop run. On a phone this requests the consent form with EEA debug geography.")
		return
	var request := ConsentRequestParameters.new()
	var debug_settings := ConsentDebugSettings.new()
	debug_settings.debug_geography = DebugGeography.Values.EEA
	request.consent_debug_settings = debug_settings
	request.tag_for_under_age_of_consent = false
	_log("Requesting UMP consent info (debug geography EEA).")
	UserMessagingPlatform.consent_information.update(request, _on_consent_success, _on_consent_failure)


func initialize_ads() -> void:
	if not plugin_ready:
		_log("AdMob plugin is not on this desktop run.")
		return
	if initialized:
		_log("Mobile Ads SDK already initialized.")
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		initialized = true
		_log("Mobile Ads SDK initialized.")
	MobileAds.initialize(listener)
	_log("Initializing Mobile Ads SDK…")


func load_rewarded() -> void:
	if not plugin_ready:
		_log("Cannot load a rewarded ad without the native AdMob plugin.")
		return
	_log("Loading rewarded TEST ad %s" % rewarded_unit_id())
	RewardedAdLoader.new().load(rewarded_unit_id(), AdRequest.new(), _load_callback)


func show_rewarded() -> void:
	if _rewarded_ad == null:
		_log("Load a rewarded test ad first.")
		return
	_log("Showing rewarded test ad.")
	_rewarded_ad.show(_reward_listener)


func _on_consent_success() -> void:
	var info := UserMessagingPlatform.consent_information
	_log("Consent status %s. Form available: %s" % [info.get_consent_status(), info.get_is_consent_form_available()])
	if info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_form_failed)
	else:
		_log("Google did not offer a consent form. Outside the EEA this is expected unless debug geography is applied.")


func _on_consent_failure(error: FormError) -> void:
	_log("Consent update failed: [%s] %s" % [error.error_code, error.message])


func _on_form_loaded(form: ConsentForm) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		_log("Consent required. Showing the UMP form.")
		form.show(_on_form_dismissed)
	else:
		_log("Consent form loaded. Status %s, form not required." % status)


func _on_form_failed(error: FormError) -> void:
	_log("Consent form failed to load: [%s] %s" % [error.error_code, error.message])


func _on_form_dismissed(error: FormError) -> void:
	if error != null:
		_log("Consent form dismissed with error: %s" % error.message)
	else:
		_log("Consent form dismissed. Status %s" % UserMessagingPlatform.consent_information.get_consent_status())


func _on_ad_loaded(ad: RewardedAd) -> void:
	_rewarded_ad = ad
	ad.full_screen_content_callback = _content_callback
	_log("Rewarded test ad loaded.")


func _on_ad_failed_to_load(error: LoadAdError) -> void:
	_rewarded_ad = null
	_log("Rewarded test ad failed to load: %s" % error.message)


func _on_user_earned_reward(item: RewardedItem) -> void:
	_log("Reward callback: %s x %s" % [item.amount, item.type])
	reward_earned.emit(item.type, int(item.amount))


func _log(message: String) -> void:
	print("[ads] ", message)
	log_line.emit(message)
