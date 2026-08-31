// Unique Accent quirk that allows custom say/whisper/yell verbs

/datum/quirk/unique_accent
	name = "Unique Accent"
	desc = "You speak with a unique accent or mannerism. You can customize how your speech appears to others."
	icon = "fa-comments"
	value = 0
	gain_text = span_notice("You notice your speech has a unique quality to it.")
	lose_text = span_danger("Your speech returns to normal.")
	medical_record_text = "Patient speaks with a unique accent or mannerism."
	quirk_flags = QUIRK_HUMAN_ONLY
	var/custom_say_verb
	var/custom_whisper_verb
	var/custom_yell_verb
	var/original_verb_say
	var/original_verb_whisper
	var/original_verb_yell

/datum/quirk/unique_accent/post_add()
	. = ..()
	if(quirk_holder.client)
		load_custom_verbs()
	else
		RegisterSignal(quirk_holder, COMSIG_MOB_LOGIN, PROC_REF(on_login))

/datum/quirk/unique_accent/proc/on_login(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(quirk_holder, COMSIG_MOB_LOGIN)
	load_custom_verbs()

/datum/quirk/unique_accent/proc/load_custom_verbs()
	if(!quirk_holder.client)
		return

	custom_say_verb = quirk_holder.client.prefs.read_preference(/datum/preference/text/custom_say_verb)
	custom_whisper_verb = quirk_holder.client.prefs.read_preference(/datum/preference/text/custom_whisper_verb)
	custom_yell_verb = quirk_holder.client.prefs.read_preference(/datum/preference/text/custom_yell_verb)

	apply_custom_verbs()

/datum/quirk/unique_accent/proc/apply_custom_verbs()
	if(!quirk_holder)
		return

	// Store original verbs (they default to "says", "whispers", "yells" on atom/movable)
	original_verb_say = quirk_holder.verb_say || "says"
	original_verb_whisper = quirk_holder.verb_whisper || "whispers"
	original_verb_yell = quirk_holder.verb_yell || "yells"

	// Apply custom verbs if they're set
	if(custom_say_verb && custom_say_verb != "")
		quirk_holder.verb_say = custom_say_verb
	if(custom_whisper_verb && custom_whisper_verb != "")
		quirk_holder.verb_whisper = custom_whisper_verb
	if(custom_yell_verb && custom_yell_verb != "")
		quirk_holder.verb_yell = custom_yell_verb

/datum/quirk/unique_accent/remove()
	. = ..()
	if(quirk_holder)
		// Restore original verbs
		quirk_holder.verb_say = original_verb_say || "says"
		quirk_holder.verb_whisper = original_verb_whisper || "whispers"
		quirk_holder.verb_yell = original_verb_yell || "yells"

