/datum/preference/choiced/erp_status_hypno
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "erp_status_pref_hypnosis"

/datum/preference/choiced/erp_status_hypno/init_possible_values()
	return list("Yes - Switch", "Yes - Dom", "Yes - Sub", "Check OOC", "Ask", "No", "Yes")

/datum/preference/choiced/erp_status_hypno/create_default_value()
	return "Ask"

/datum/preference/choiced/erp_status_hypno/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	if(CONFIG_GET(flag/disable_erp_preferences))
		return FALSE

	return preferences.read_preference(/datum/preference/toggle/master_erp_preferences)

/datum/preference/choiced/erp_status_hypno/deserialize(input, datum/preferences/preferences)
	if(CONFIG_GET(flag/disable_erp_preferences))
		return "No"

	if(!preferences.read_preference(/datum/preference/toggle/master_erp_preferences))
		return "No"
	. = ..()

/datum/preference/choiced/erp_status_hypno/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/datum/preference/choiced/erp_status_depraved
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "erp_status_pref_depraved"

/datum/preference/choiced/erp_status_depraved/init_possible_values()
	return list("Yes", "Ask (L)OOC", "Check OOC Notes", "No")

/datum/preference/choiced/erp_status_depraved/create_default_value()
	return "No"

/datum/preference/choiced/erp_status_depraved/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	if(CONFIG_GET(flag/disable_erp_preferences))
		return FALSE

	return preferences.read_preference(/datum/preference/toggle/master_erp_preferences)

/datum/preference/choiced/erp_status_depraved/deserialize(input, datum/preferences/preferences)
	if(CONFIG_GET(flag/disable_erp_preferences))
		return "No"

	if(!preferences.read_preference(/datum/preference/toggle/master_erp_preferences))
		return "No"

	// Handle null/undefined input (for old savefiles)
	if(isnull(input))
		return create_default_value()

	. = ..()

/datum/preference/choiced/erp_status_depraved/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/datum/preference/choiced/erp_status_violent
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "erp_status_pref_violent"

/datum/preference/choiced/erp_status_violent/init_possible_values()
	return list("Yes", "Ask (L)OOC", "Check OOC Notes", "No")

/datum/preference/choiced/erp_status_violent/create_default_value()
	return "No"

/datum/preference/choiced/erp_status_violent/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	if(CONFIG_GET(flag/disable_erp_preferences))
		return FALSE

	return preferences.read_preference(/datum/preference/toggle/master_erp_preferences)

/datum/preference/choiced/erp_status_violent/deserialize(input, datum/preferences/preferences)
	if(CONFIG_GET(flag/disable_erp_preferences))
		return "No"

	if(!preferences.read_preference(/datum/preference/toggle/master_erp_preferences))
		return "No"

	// Handle null/undefined input (for old savefiles)
	if(isnull(input))
		return create_default_value()

	. = ..()

/datum/preference/choiced/erp_status_violent/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE
