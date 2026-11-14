// Preferences for Unique Accent quirk

/datum/preference/text/custom_say_verb
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_say_verb"
	maximum_value_length = 32
	can_randomize = FALSE

/datum/preference/text/custom_say_verb/create_default_value()
	return ""

/datum/preference/text/custom_say_verb/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/datum/preference/text/custom_whisper_verb
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_whisper_verb"
	maximum_value_length = 32
	can_randomize = FALSE

/datum/preference/text/custom_whisper_verb/create_default_value()
	return ""

/datum/preference/text/custom_whisper_verb/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/datum/preference/text/custom_yell_verb
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_yell_verb"
	maximum_value_length = 32
	can_randomize = FALSE

/datum/preference/text/custom_yell_verb/create_default_value()
	return ""

/datum/preference/text/custom_yell_verb/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

