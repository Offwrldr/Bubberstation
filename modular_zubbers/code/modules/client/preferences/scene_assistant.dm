/// Hidden player prefs for Scene Assistant log appearance. Edited from the panel, not the prefs menu.

/datum/preference/toggle/scene_assistant_show_avatars
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "scene_assistant_show_avatars"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = TRUE

/datum/preference/toggle/scene_assistant_show_avatars/is_accessible(datum/preferences/preferences)
	return FALSE

/datum/preference/numeric/scene_assistant_avatar_size
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "scene_assistant_avatar_size"
	savefile_identifier = PREFERENCE_PLAYER
	minimum = 32
	maximum = 128
	step = 1

/datum/preference/numeric/scene_assistant_avatar_size/create_default_value()
	return 64

/datum/preference/numeric/scene_assistant_avatar_size/is_accessible(datum/preferences/preferences)
	return FALSE

/datum/preference/text/scene_assistant_font
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "scene_assistant_font"
	savefile_identifier = PREFERENCE_PLAYER
	maximum_value_length = 64

/datum/preference/text/scene_assistant_font/create_default_value()
	return "Verdana"

/datum/preference/text/scene_assistant_font/deserialize(input, datum/preferences/preferences)
	return sanitize_scene_assistant_font(..())

/datum/preference/text/scene_assistant_font/is_accessible(datum/preferences/preferences)
	return FALSE

/datum/preference/numeric/scene_assistant_font_size
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "scene_assistant_font_size"
	savefile_identifier = PREFERENCE_PLAYER
	minimum = 80
	maximum = 160
	step = 1

/datum/preference/numeric/scene_assistant_font_size/create_default_value()
	return 100

/datum/preference/numeric/scene_assistant_font_size/is_accessible(datum/preferences/preferences)
	return FALSE

/datum/preference/numeric/scene_assistant_line_spacing
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "scene_assistant_line_spacing"
	savefile_identifier = PREFERENCE_PLAYER
	minimum = 1
	maximum = 2
	step = 0.05

/datum/preference/numeric/scene_assistant_line_spacing/create_default_value()
	return 1.35

/datum/preference/numeric/scene_assistant_line_spacing/is_accessible(datum/preferences/preferences)
	return FALSE

/proc/sanitize_scene_assistant_font(font_name)
	if(!istext(font_name))
		return "Verdana"
	var/cleaned = trim(STRIP_HTML_SIMPLE(font_name, 64))
	if(!length(cleaned))
		return "Verdana"
	var/static/list/disallowed_font_chars = list(";", ":", "(", ")", "<", ">", "\\", "/", "[", "]", "{", "}", "@", "!", "#", "$", "%", "^", "*", "=", "+")
	for(var/bad_char in disallowed_font_chars)
		if(findtext(cleaned, bad_char))
			return "Verdana"
	return cleaned
