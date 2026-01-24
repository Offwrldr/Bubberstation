/**
 * RP Panel - A TGUI interface for roleplay interactions
 * Allows players to send emotes to nearby players with different visibility modes
 */

/datum/rp_panel
	/// The mob that owns this RP panel
	var/mob/living/holder
	/// List of mobs currently in the chat (weakrefs)
	var/list/participants = list()
	/// Current emote mode: "say", "whisper", "public", "subtle", "subtle_antighost"
	var/emote_mode = "say"
	/// Chat history
	var/list/messages = list()
	/// Flag to prevent duplicate recording when sending messages through the panel
	var/sending_message = FALSE
	/// Current approach mode: "gentle", "neutral", "hard", "rough"
	var/approach_mode = "neutral"
	/// Current selected participant for verb targeting
	var/mob/living/selected_participant = null
	/// List of participants currently typing (weakrefs)
	var/list/typing_participants = list()
	/// Current theme: "default", "light", "cream", "strawberry", "super_dark", "apple"
	var/theme = "default"
	/// Sound toggles
	var/sound_message_enabled = TRUE
	var/sound_join_enabled = TRUE
	var/sound_leave_enabled = TRUE

/datum/rp_panel/New(mob/living/new_holder)
	. = ..()
	holder = new_holder
	// Register signals to capture external say/emote
	RegisterSignal(holder, COMSIG_MOB_SAY, PROC_REF(on_say))
	RegisterSignal(holder, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
	// Hook into show_message to capture span_purple messages (sex toy interactions)
	if(holder.client)
		RegisterSignal(holder, COMSIG_MOB_LOGIN, PROC_REF(on_login))
		on_login() // Call immediately if already logged in

/datum/rp_panel/Destroy()
	if(holder)
		UnregisterSignal(holder, list(COMSIG_MOB_SAY, COMSIG_MOB_EMOTE, COMSIG_MOB_LOGIN))
	holder = null
	participants = null
	messages = null
	return ..()

// Hook to set up message capture when holder logs in
/datum/rp_panel/proc/on_login()
	SIGNAL_HANDLER
	// Message capture is handled via to_chat hook - see on_to_chat proc

/datum/rp_panel/ui_state(mob/user)
	// Allow access even when sleeping (for debugging/admin purposes)
	return GLOB.always_state

/datum/rp_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "RpPanel")
		ui.open()

/datum/rp_panel/ui_data(mob/user)
	var/list/data = list()

	// Current emote mode
	data["emote_mode"] = emote_mode

	// Available emote modes
	data["emote_modes"] = list(
		"say" = "Say",
		"whisper" = "Whisper",
		"public" = "Public Emote",
		"subtle" = "Subtle Emote",
		"subtle_antighost" = "Subtle Anti-Ghost"
	)

	// Autocum preference
	if(ishuman(holder))
		var/mob/living/carbon/human/human_holder = holder
		data["autocum_enabled"] = human_holder.client?.prefs?.read_preference(/datum/preference/toggle/erp/autocum) || FALSE
	else
		data["autocum_enabled"] = FALSE

	// Check and remove out-of-range participants
	check_and_remove_out_of_range()

	// Participants list with their info
	var/list/participant_data = list()
	for(var/datum/weakref/participant_ref as anything in participants)
		var/mob/living/participant = participant_ref.resolve()
		if(!participant || QDELETED(participant))
			continue

		var/list/participant_info = list()
		participant_info["name"] = participant.name
		participant_info["ref"] = REF(participant)

		// Get headshot URL
		var/headshot_url = ""
		if(ishuman(participant))
			var/mob/living/carbon/human/human_participant = participant
			headshot_url = human_participant.dna?.features["headshot"] || ""
		else if(participant.client?.ckey)
			// Fallback to stored_link from preference datum (static cache)
			var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
			if(headshot_pref && headshot_pref.stored_link)
				headshot_url = headshot_pref.stored_link[participant.client.ckey] || ""

		participant_info["headshot"] = headshot_url

		// Check if participant is typing
		var/is_typing = FALSE
		for(var/datum/weakref/typing_ref as anything in typing_participants)
			var/mob/living/typing_participant = typing_ref.resolve()
			if(typing_participant == participant)
				is_typing = TRUE
				break
		participant_info["is_typing"] = is_typing

		participant_data += list(participant_info)

	data["participants"] = participant_data

	// Typing participants for UI
	data["typing_participants"] = typing_participants

	// Messages
	data["messages"] = messages


	// Current approach mode
	data["approach_mode"] = approach_mode

	// Selected participant for verb targeting (default to holder if none selected)
	if(!selected_participant || QDELETED(selected_participant))
		selected_participant = holder

	if(selected_participant && !QDELETED(selected_participant))
		var/list/selected_data = list()
		selected_data["name"] = selected_participant.name
		selected_data["ref"] = REF(selected_participant)
		selected_data["is_self"] = (selected_participant == holder)

		// Get headshot
		var/headshot_url = ""
		if(ishuman(selected_participant))
			var/mob/living/carbon/human/human_selected = selected_participant
			headshot_url = human_selected.dna?.features["headshot"] || ""
		else if(selected_participant.client?.ckey)
			var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
			if(headshot_pref && headshot_pref.stored_link)
				headshot_url = headshot_pref.stored_link[selected_participant.client.ckey] || ""

		selected_data["headshot"] = headshot_url

		// Generate participant details
		var/list/details = list()
		if(ishuman(selected_participant))
			var/mob/living/carbon/human/human_selected = selected_participant

			// Check hands (using has_arms to get count)
			var/hand_count = human_selected.has_arms(REQUIRE_GENITAL_ANY)
			// Only show hand status if they have hands
			if(hand_count > 0)
				// Check if hands are uncovered (is_hands_uncovered returns true if covered, so invert)
				if(!human_selected.is_hands_uncovered())
					details += "have uncovered hands"
				else
					details += "have covered hands"

			// Check feet
			var/feet_count = human_selected.has_feet(REQUIRE_GENITAL_ANY)
			if(feet_count > 0)
				// Check if barefoot (no shoes covering feet) AND no socks (or socks are "Nude")
				var/is_barefoot_check = human_selected.is_barefoot()
				var/has_socks = human_selected.socks && human_selected.socks != "Nude"
				if(is_barefoot_check && !has_socks)
					details += "are barefoot"
				else if(is_barefoot_check && has_socks)
					details += "are wearing socks"
				else
					details += "have feet covered"

			// Check mouth
			var/obj/item/bodypart/head/head_part = human_selected.get_bodypart(BODY_ZONE_HEAD)
			if(head_part)
				var/mouth_covered = (human_selected.wear_mask?.flags_inv & HIDEFACE) || (human_selected.head?.flags_inv & HIDEFACE)
				if(mouth_covered)
					details += "have a mouth, which is covered"
				else
					details += "have a mouth, which is uncovered"

			// Check if head is uncovered (is_head_uncovered returns true if covered, so invert)
			if(!human_selected.is_head_uncovered())
				details += "have head uncovered"
			else
				details += "have head covered"

			// Check approach mode (gentle, neutral, hard, rough)
			if(approach_mode == "gentle")
				details += "are acting gentle"
			else if(approach_mode == "neutral")
				details += "are acting neutral"
			else if(approach_mode == "hard")
				details += "are acting hard"
			else if(approach_mode == "rough")
				details += "are acting rough"

			// Check if naked
			if(human_selected.is_topless() && human_selected.is_bottomless())
				details += "are naked"
			else if(human_selected.is_topless())
				details += "are topless"
			else if(human_selected.is_bottomless())
				details += "are bottomless"

			// Check genitals (only show if actually exposed, accounting for visibility preferences and underwear)
			var/obj/item/organ/genital/penis = human_selected.get_organ_slot(ORGAN_SLOT_PENIS)
			if(penis && is_genital_actually_exposed(human_selected, penis))
				details += "have a penis"

			var/obj/item/organ/genital/testicles = human_selected.get_organ_slot(ORGAN_SLOT_TESTICLES)
			if(testicles && is_genital_actually_exposed(human_selected, testicles))
				details += "have testicles"

			var/obj/item/organ/genital/vagina = human_selected.get_organ_slot(ORGAN_SLOT_VAGINA)
			if(vagina && is_genital_actually_exposed(human_selected, vagina))
				details += "have a vagina"

			var/obj/item/organ/genital/breasts = human_selected.get_organ_slot(ORGAN_SLOT_BREASTS)
			if(breasts && is_genital_actually_exposed(human_selected, breasts))
				details += "have breasts"

			var/obj/item/organ/genital/anus = human_selected.get_organ_slot(ORGAN_SLOT_ANUS)
			if(anus && is_genital_actually_exposed(human_selected, anus))
				details += "have an anus"

			// Get pleasure, arousal, and pain values
			if(human_selected.client?.prefs?.read_preference(/datum/preference/toggle/erp))
				selected_data["pleasure"] = human_selected.pleasure
				selected_data["arousal"] = human_selected.arousal
				selected_data["pain"] = human_selected.pain
			else
				selected_data["pleasure"] = 0
				selected_data["arousal"] = 0
				selected_data["pain"] = 0
		else
			selected_data["pleasure"] = 0
			selected_data["arousal"] = 0
			selected_data["pain"] = 0

		// Get status indicators for selected participant (ERP, HYPNOSIS, VORE, NON-CON, ERP MECHANICS)
		if(selected_participant.client?.prefs)
			var/datum/preferences/target_prefs = selected_participant.client.prefs
			var/erp_status = "NO"
			var/hypno_status = "NO"
			var/vore_status = "NO"
			var/noncon_status = "NO"
			var/erp_mechanics_status = "NONE"

			// Check ERP status
			if(target_prefs.read_preference(/datum/preference/toggle/master_erp_preferences))
				var/erp_choice = target_prefs.read_preference(/datum/preference/choiced/erp_status) || "No"
				erp_status = get_preference_status(erp_choice)
			selected_data["erp_status_display"] = erp_status

			// Check Hypnosis status
			if(target_prefs.read_preference(/datum/preference/toggle/master_erp_preferences))
				var/hypno_choice = target_prefs.read_preference(/datum/preference/choiced/erp_status_hypno) || "No"
				hypno_status = get_preference_status(hypno_choice)
			selected_data["hypno_status_display"] = hypno_status

			// Check Vore status
			if(target_prefs.read_preference(/datum/preference/toggle/master_erp_preferences))
				var/vore_choice = target_prefs.read_preference(/datum/preference/choiced/erp_status_v) || "No"
				vore_status = get_preference_status(vore_choice)
			selected_data["vore_status_display"] = vore_status

			// Check Noncon status
			if(target_prefs.read_preference(/datum/preference/toggle/master_erp_preferences))
				var/noncon_choice = target_prefs.read_preference(/datum/preference/choiced/erp_status_nc) || "No"
				noncon_status = get_preference_status(noncon_choice)
			selected_data["noncon_status_display"] = noncon_status

			// Check ERP Mechanics status
			if(target_prefs.read_preference(/datum/preference/toggle/master_erp_preferences))
				var/erp_mechanics_choice = target_prefs.read_preference(/datum/preference/choiced/erp_status_mechanics) || "None"
				// Convert to uppercase for display
				erp_mechanics_status = uppertext(erp_mechanics_choice)
			selected_data["erp_mechanics_display"] = erp_mechanics_status
		else
			selected_data["erp_status_display"] = "NO"
			selected_data["hypno_status_display"] = "NO"
			selected_data["vore_status_display"] = "NO"
			selected_data["noncon_status_display"] = "NO"
			selected_data["erp_mechanics_display"] = "NONE"

		selected_data["details"] = details
		data["selected_participant"] = selected_data
	else
		data["selected_participant"] = null

	// Always get self preferences for holder (for Manage Self button)
	if(holder.client?.prefs)
		var/datum/preferences/prefs = holder.client.prefs
		var/list/self_prefs = list()

		// Read ERP preferences
		if(prefs.read_preference(/datum/preference/toggle/master_erp_preferences))
			self_prefs["erp_status"] = prefs.read_preference(/datum/preference/choiced/erp_status) || "Ask (L)OOC"
			self_prefs["erp_status_nc"] = prefs.read_preference(/datum/preference/choiced/erp_status_nc) || "No"
			self_prefs["erp_status_v"] = prefs.read_preference(/datum/preference/choiced/erp_status_v) || "No"
			self_prefs["erp_status_hypno"] = prefs.read_preference(/datum/preference/choiced/erp_status_hypno) || "No"
			self_prefs["erp_status_mechanics"] = prefs.read_preference(/datum/preference/choiced/erp_status_mechanics) || "None"
		else
			self_prefs["erp_status"] = "No"
			self_prefs["erp_status_nc"] = "No"
			self_prefs["erp_status_v"] = "No"
			self_prefs["erp_status_hypno"] = "No"
			self_prefs["erp_status_mechanics"] = "None"

		// Get genital visibility data
		if(ishuman(holder))
			var/mob/living/carbon/human/human_holder = holder
			var/list/genitals_data = list()
			for(var/organ_slot in list(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS, ORGAN_SLOT_BREASTS, ORGAN_SLOT_TESTICLES))
				var/obj/item/organ/genital/genital = human_holder.get_organ_slot(organ_slot)
				if(genital && genital.visibility_preference != 0) // GENITAL_SKIP_VISIBILITY = 0
					var/list/genital_info = list(
						"slot" = organ_slot,
						"name" = capitalize(organ_slot),
						"visibility" = genital.visibility_preference
					)
					genitals_data += list(genital_info)
			self_prefs["genitals"] = genitals_data

			// Get underwear visibility flags
			self_prefs["hide_underwear"] = !!(human_holder.underwear_visibility & UNDERWEAR_HIDE_UNDIES)
			self_prefs["hide_bra"] = !!(human_holder.underwear_visibility & UNDERWEAR_HIDE_BRA)
			self_prefs["hide_undershirt"] = !!(human_holder.underwear_visibility & UNDERWEAR_HIDE_SHIRT)
			self_prefs["hide_socks"] = !!(human_holder.underwear_visibility & UNDERWEAR_HIDE_SOCKS)

		data["self_preferences"] = self_prefs
	else
		data["self_preferences"] = null

	// Verb category filter

	// Settings data
	data["theme"] = theme
	data["sound_message_enabled"] = sound_message_enabled
	data["sound_join_enabled"] = sound_join_enabled
	data["sound_leave_enabled"] = sound_leave_enabled

	// Check ERP preferences for showing Romance/Sex approaches
	var/show_erp_approaches = TRUE
	if(holder.client?.prefs)
		var/erp_enabled = holder.client.prefs.read_preference(/datum/preference/toggle/erp)
		var/erp_mechanics = holder.client.prefs.read_preference(/datum/preference/choiced/erp_status_mechanics)
		if(!erp_enabled || erp_mechanics == "Roleplay only" || erp_mechanics == "None")
			show_erp_approaches = FALSE
	data["show_erp_approaches"] = show_erp_approaches


	// Get interaction data for participants (verb mode)
	data["verb_mode_data"] = get_verb_mode_data(user)

	// Available players in 5x5 range
	var/list/available_players = list()
	var/turf/user_turf = get_turf(holder)
	var/is_admin = check_rights_for(user?.client, R_ADMIN)
	if(user_turf)
		for(var/mob/living/player in view(2, user_turf)) // 2 tiles = 5x5 area (2+1+2)
			if(player == holder)
				continue
			// Allow admins to see mobs without clients for testing
			if(!player.client && !is_admin)
				continue
			if(player.stat == DEAD && !isobserver(player))
				continue

			// Check if already in participants
			var/already_added = FALSE
			for(var/datum/weakref/participant_ref as anything in participants)
				var/mob/living/participant = participant_ref.resolve()
				if(participant == player)
					already_added = TRUE
					break

			if(already_added)
				continue

			var/list/player_info = list()
			player_info["name"] = player.name
			player_info["ref"] = REF(player)

			// Get headshot URL
			var/headshot_url = ""
			if(ishuman(player))
				var/mob/living/carbon/human/human_player = player
				headshot_url = human_player.dna?.features["headshot"] || ""
			else if(player.client?.ckey)
				// Fallback to stored_link from preference datum (static cache)
				var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
				if(headshot_pref && headshot_pref.stored_link)
					headshot_url = headshot_pref.stored_link[player.client.ckey] || ""

			player_info["headshot"] = headshot_url
			available_players += list(player_info)

	data["available_players"] = available_players

	return data

/datum/rp_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("set_approach_mode")
			var/new_approach = params["approach"]
			if(new_approach in list("gentle", "neutral", "hard", "rough"))
				approach_mode = new_approach
				. = TRUE

		if("set_selected_participant")
			var/participant_ref = params["ref"]
			if(!participant_ref)
				selected_participant = holder
				. = TRUE
				return

			var/mob/living/target = locate(participant_ref)
			if(!target || QDELETED(target))
				selected_participant = holder
			else
				// Verify target is in participants or is holder
				var/is_participant = FALSE
				if(target == holder)
					is_participant = TRUE
				else
					for(var/datum/weakref/ref as anything in participants)
						var/mob/living/participant = ref.resolve()
						if(participant == target)
							is_participant = TRUE
							break

				if(is_participant)
					selected_participant = target
				else
					selected_participant = holder
			. = TRUE

		if("open_examine")
			var/mob/living/target = null
			if(selected_participant && !QDELETED(selected_participant))
				target = selected_participant
			else if(params["ref"])
				// Allow opening from message headshot
				target = locate(params["ref"])

			if(!target || QDELETED(target))
				return

			// Open examine panel if available
			if(ishuman(target))
				var/mob/living/carbon/human/human_target = target
				if(human_target.tgui)
					var/datum/examine_panel/panel = human_target.tgui
					panel.holder = human_target
					panel.ui_interact(holder)
				else
					holder.examinate(target)
			else if(issilicon(target))
				var/mob/living/silicon/silicon_target = target
				if(silicon_target.examine_panel)
					silicon_target.examine_panel.holder = silicon_target
					silicon_target.examine_panel.ui_interact(holder)
				else
					holder.examinate(target)
			else
				holder.examinate(target)
			. = TRUE

		if("open_reference")
			if(selected_participant && !QDELETED(selected_participant))
				var/mob/living/target = selected_participant
				if(!target || QDELETED(target))
					return

				// Get reference image URL
				var/reference_url = ""
				if(ishuman(target))
					var/mob/living/carbon/human/human_target = target
					reference_url = human_target.dna?.features["art_ref"] || ""
				else if(target.client?.ckey)
					var/datum/preference/text/headshot/art_ref/art_ref_pref = GLOB.preference_entries[/datum/preference/text/headshot/art_ref]
					if(art_ref_pref && art_ref_pref.stored_link)
						reference_url = art_ref_pref.stored_link[target.client.ckey] || ""

				if(reference_url && length(reference_url))
					// Open reference image in browser
					holder << browse(reference_url, "window=reference_image;size=800x600")
				else
					to_chat(holder, span_warning("[target] doesn't have a reference image set."))
			. = TRUE

		if("remove_lewd_item")
			var/item_slot = params["item_slot"]
			if(!item_slot)
				return

			var/mob/living/target = selected_participant
			if(!target || QDELETED(target))
				if(length(participants) > 0)
					var/datum/weakref/first_ref = participants[1]
					target = first_ref.resolve()
			if(!target || QDELETED(target))
				target = holder

			if(!ishuman(target))
				return

			var/datum/component/interactable/interaction_component = target.GetComponent(/datum/component/interactable)
			if(!interaction_component)
				return

			// Call the interaction component's ui_act with the remove_lewd_item action
			var/list/lewd_params = list(
				"item_slot" = item_slot,
				"userref" = REF(holder),
				"selfref" = REF(target)
			)
			interaction_component.ui_act("remove_lewd_item", lewd_params, null, null)
			. = TRUE

		if("set_theme")
			var/new_theme = params["theme"]
			if(new_theme in list("default", "light", "cream", "strawberry", "super_dark", "apple"))
				theme = new_theme
			. = TRUE

		if("set_sound_message")
			sound_message_enabled = !sound_message_enabled
			. = TRUE

		if("set_sound_join")
			sound_join_enabled = !sound_join_enabled
			. = TRUE

		if("set_sound_leave")
			sound_leave_enabled = !sound_leave_enabled
			. = TRUE


		if("set_self_preference")
			if(!holder.client?.prefs)
				return
			var/pref_type = params["pref_type"]
			var/pref_value = params["pref_value"]

			if(!pref_type || !pref_value)
				return

			var/datum/preferences/prefs = holder.client.prefs
			var/datum/preference/preference_entry

			switch(pref_type)
				if("erp_status")
					preference_entry = GLOB.preference_entries[/datum/preference/choiced/erp_status]
				if("erp_status_nc")
					preference_entry = GLOB.preference_entries[/datum/preference/choiced/erp_status_nc]
				if("erp_status_v")
					preference_entry = GLOB.preference_entries[/datum/preference/choiced/erp_status_v]
				if("erp_status_hypno")
					preference_entry = GLOB.preference_entries[/datum/preference/choiced/erp_status_hypno]
				if("erp_status_mechanics")
					preference_entry = GLOB.preference_entries[/datum/preference/choiced/erp_status_mechanics]

			if(preference_entry)
				// Write the preference (updates value_cache and save_data immediately)
				if(prefs.write_preference(preference_entry, pref_value))
					// Mark as recently updated so it gets saved
					prefs.recently_updated_keys |= preference_entry.type
					// Save the character preferences to persist to disk
					prefs.save_character(TRUE)
				// Update UI immediately to reflect the change
				SStgui.update_uis(src)
			. = TRUE

		if("set_genital_visibility")
			if(!ishuman(holder))
				return
			var/mob/living/carbon/human/human_holder = holder
			var/organ_slot = params["organ_slot"]
			var/visibility = text2num(params["visibility"])

			if(!organ_slot || !visibility)
				return

			var/obj/item/organ/genital/genital = human_holder.get_organ_slot(organ_slot)
			if(!genital)
				return

			// Validate visibility value
			if(visibility != GENITAL_NEVER_SHOW && visibility != GENITAL_HIDDEN_BY_CLOTHES && visibility != GENITAL_ALWAYS_SHOW)
				return

			genital.visibility_preference = visibility
			human_holder.update_body()
			SEND_SIGNAL(human_holder, COMSIG_HUMAN_TOGGLE_GENITALS)
			. = TRUE

		if("remove_underwear")
			if(!ishuman(holder))
				return
			var/mob/living/carbon/human/human_holder = holder
			human_holder.underwear = "Nude"
			human_holder.undershirt = "Nude"
			human_holder.bra = "Nude"
			human_holder.socks = "Nude"
			human_holder.update_body()
			. = TRUE

		if("toggle_underwear_visibility")
			if(!ishuman(holder))
				return
			var/underwear_type = params["underwear_type"]
			if(!underwear_type)
				return
			var/mob/living/carbon/human/human_holder = holder
			switch(underwear_type)
				if("underwear")
					human_holder.underwear_visibility ^= UNDERWEAR_HIDE_UNDIES
				if("bra")
					human_holder.underwear_visibility ^= UNDERWEAR_HIDE_BRA
				if("undershirt")
					human_holder.underwear_visibility ^= UNDERWEAR_HIDE_SHIRT
				if("socks")
					human_holder.underwear_visibility ^= UNDERWEAR_HIDE_SOCKS
			human_holder.update_body()
			SEND_SIGNAL(human_holder, COMSIG_HUMAN_TOGGLE_UNDERWEAR, underwear_type)
			// Update UI immediately to reflect the change
			SStgui.update_uis(src)
			. = TRUE

		if("toggle_autocum")
			if(!ishuman(holder))
				return
			var/mob/living/carbon/human/human_holder = holder
			if(!human_holder.client?.prefs)
				return
			var/datum/preferences/prefs = human_holder.client.prefs
			var/datum/preference/toggle/erp/autocum/autocum_pref = GLOB.preference_entries[/datum/preference/toggle/erp/autocum]
			if(autocum_pref)
				// Read current value using type path
				var/current_value = prefs.read_preference(/datum/preference/toggle/erp/autocum)
				// Write new value (toggle it)
				if(prefs.write_preference(autocum_pref, !current_value))
					// Mark as recently updated so it gets saved
					prefs.recently_updated_keys |= autocum_pref.type
					// Apply to client (for PREFERENCE_PLAYER preferences)
					autocum_pref.apply_to_client_updated(human_holder.client, !current_value)
					// Save preferences (autocum is PREFERENCE_PLAYER, not PREFERENCE_CHARACTER)
					prefs.save_preferences()
				SStgui.update_uis(src)
			. = TRUE

		if("trigger_climax")
			if(!ishuman(holder))
				return
			var/mob/living/carbon/human/human_holder = holder
			human_holder.climax(manual = TRUE)
			. = TRUE

		if("set_emote_mode")
			var/new_mode = params["mode"]
			if(new_mode in list("say", "whisper", "public", "subtle", "subtle_antighost"))
				emote_mode = new_mode
				. = TRUE

		if("trigger_interaction")
			var/interaction_name = params["interaction"]
			if(!interaction_name)
				return

			// Use selected participant or first available
			var/mob/living/target = selected_participant
			if(!target || QDELETED(target))
				if(length(participants) > 0)
					var/datum/weakref/first_ref = participants[1]
					target = first_ref.resolve()
			if(!target || QDELETED(target))
				target = holder

			if(!target || QDELETED(target))
				to_chat(holder, span_warning("No target selected."))
				return

			// Get the interaction component from the target
			if(!ishuman(target))
				to_chat(holder, span_warning("[target] doesn't have an interaction component."))
				return

			var/datum/component/interactable/interaction_component = target.GetComponent(/datum/component/interactable)
			if(!interaction_component)
				to_chat(holder, span_warning("[target] doesn't have an interaction component."))
				return

			// Find the interaction
			var/datum/interaction/found_interaction = null
			for(var/datum/interaction/interaction in interaction_component.interactions)
				if(interaction.name == interaction_name)
					found_interaction = interaction
					break

			if(!found_interaction)
				to_chat(holder, span_warning("Interaction '[interaction_name]' not found."))
				return

			// Check if we can interact
			if(!interaction_component.can_interact(found_interaction, holder))
				to_chat(holder, span_warning("You cannot perform '[interaction_name]' on [target]."))
				return

			// Get the message that will be displayed (before triggering)
			var/interaction_message = ""
			if(found_interaction.message && length(found_interaction.message))
				var/msg = pick(found_interaction.message)
				if(interaction_component.body_relay && !can_see(holder, target))
					msg = replacetext(msg, "%TARGET%", "\the [interaction_component.body_relay.name]")
				interaction_message = trim(replacetext(replacetext(msg, "%TARGET%", "[target]"), "%USER%", ""), INTERACTION_MAX_CHAR)

			// Trigger the interaction
			if(interaction_component.body_relay && !can_see(holder, target))
				found_interaction.act(holder, target, interaction_component.body_relay)
			else
				found_interaction.act(holder, target)

			// Update interaction cooldown
			var/datum/component/interactable/holder_component = holder.GetComponent(/datum/component/interactable)
			if(holder_component)
				holder_component.interact_last = world.time
				interaction_component.interact_next = holder_component.interact_last + INTERACTION_COOLDOWN
				holder_component.interact_next = interaction_component.interact_next

			// Record interaction in chat if there's a message
			if(interaction_message && length(interaction_message))
				// Get headshot
				var/headshot_url = ""
				if(ishuman(holder))
					var/mob/living/carbon/human/human_holder = holder
					headshot_url = human_holder.dna?.features["headshot"] || ""
				else if(holder.client?.ckey)
					var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
					if(headshot_pref && headshot_pref.stored_link)
						headshot_url = headshot_pref.stored_link[holder.client.ckey] || ""

				// Create message entry
				var/list/message_entry = list(
					"name" = holder.name,
					"message" = interaction_message,
					"headshot" = headshot_url,
					"mode" = found_interaction.lewd ? "subtle" : "public",
					"timestamp" = time2text(world.timeofday, "HH:MM:SS"),
					"ref" = REF(holder)
				)

				// Add to all participants' panels
				messages += list(message_entry)
				for(var/datum/weakref/participant_ref as anything in participants)
					var/mob/living/participant = participant_ref.resolve()
					if(participant && !QDELETED(participant) && participant.rp_panel)
						participant.rp_panel.messages += list(message_entry)
						SStgui.update_uis(participant.rp_panel)
						// Play chime sound
						if(participant.client)
							participant.playsound_local(get_turf(holder), 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg', 50, FALSE)

				// Play chime for holder
				if(holder.client)
					holder.playsound_local(get_turf(holder), 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg', 50, FALSE)

			. = TRUE

		if("add_participant")
			var/mob_ref = params["ref"]
			var/mob/living/target = locate(mob_ref)
			if(!target || QDELETED(target))
				return

			// Block simplemobs and pets, but allow cyborgs
			if(isanimal(target) || istype(target, /mob/living/basic/pet))
				if(!iscyborg(target))
					to_chat(holder, span_warning("You cannot add simplemobs or station pets to the RP panel."))
					return

			// Check if already added
			for(var/datum/weakref/participant_ref as anything in participants)
				var/mob/living/participant = participant_ref.resolve()
				if(participant == target)
					return

			// Check if in range
			var/turf/user_turf = get_turf(holder)
			var/turf/target_turf = get_turf(target)
			if(!user_turf || !target_turf || get_dist(user_turf, target_turf) > 2)
				to_chat(holder, span_warning("[target] is too far away."))
				return

			participants += WEAKREF(target)
			to_chat(holder, span_notice("Added [target] to the RP panel."))

			// Open the target's RP panel if they don't have one open
			if(!target.rp_panel)
				target.rp_panel = new(target)

			// Sync participants - add holder to target's panel and vice versa
			var/already_in_target_panel = FALSE
			for(var/datum/weakref/other_ref as anything in target.rp_panel.participants)
				var/mob/living/other = other_ref.resolve()
				if(other == holder)
					already_in_target_panel = TRUE
					break

			if(!already_in_target_panel)
				target.rp_panel.participants += WEAKREF(holder)

			// Sync messages - copy all messages from holder's panel to target's panel
			for(var/list/msg as anything in messages)
				var/found = FALSE
				for(var/list/existing_msg as anything in target.rp_panel.messages)
					if(existing_msg["name"] == msg["name"] && existing_msg["message"] == msg["message"] && existing_msg["mode"] == msg["mode"])
						found = TRUE
						break
				if(!found)
					target.rp_panel.messages += list(msg)

			// Copy messages from target's panel to holder's panel
			for(var/list/msg as anything in target.rp_panel.messages)
				var/found = FALSE
				for(var/list/existing_msg as anything in messages)
					if(existing_msg["name"] == msg["name"] && existing_msg["message"] == msg["message"] && existing_msg["mode"] == msg["mode"])
						found = TRUE
						break
				if(!found)
					messages += list(msg)

			// Play join sound for all participants
			play_sound_to_participants('modular_zubbers/sound/misc/rppanelsounds/messagejoin.ogg')

			// Open the target's panel
			target.rp_panel.ui_interact(target)
			. = TRUE

		if("remove_participant")
			var/mob_ref = params["ref"]
			var/mob/living/target = locate(mob_ref)
			if(!target)
				return

			for(var/datum/weakref/participant_ref as anything in participants)
				var/mob/living/participant = participant_ref.resolve()
				if(participant == target)
					participants -= participant_ref
					to_chat(holder, span_notice("Removed [target] from the RP panel."))
					// Remove holder from target's panel as well
					if(target.rp_panel)
						for(var/datum/weakref/other_ref as anything in target.rp_panel.participants)
							var/mob/living/other = other_ref.resolve()
							if(other == holder)
								target.rp_panel.participants -= other_ref
								to_chat(target, span_notice("[holder] removed you from the RP panel."))
								SStgui.update_uis(target.rp_panel)
								break

					// Play leave sound
					play_sound_to_participants('modular_zubbers/sound/misc/rppanelsounds/messageleave.ogg')
					. = TRUE
					break

		if("set_typing")
			var/is_typing = params["typing"]
			if(is_typing)
				// Add to typing participants if not already there
				var/already_typing = FALSE
				for(var/datum/weakref/typing_ref as anything in typing_participants)
					var/mob/living/typing_participant = typing_ref.resolve()
					if(typing_participant == holder)
						already_typing = TRUE
						break
				if(!already_typing)
					typing_participants += WEAKREF(holder)
					// Show typing indicator above sprite
					if(holder.client?.typing_indicators)
						ADD_TRAIT(holder, TRAIT_THINKING_IN_CHARACTER, CURRENTLY_TYPING_TRAIT)
						holder.create_typing_indicator()
				. = TRUE
			else
				// Remove from typing participants
				for(var/datum/weakref/typing_ref as anything in typing_participants)
					var/mob/living/typing_participant = typing_ref.resolve()
					if(typing_participant == holder)
						typing_participants -= typing_ref
						// Remove typing indicator
						holder.remove_typing_indicator()
						if(!holder.active_thinking_indicator)
							REMOVE_TRAIT(holder, TRAIT_THINKING_IN_CHARACTER, CURRENTLY_TYPING_TRAIT)
						break
				. = TRUE

			// Update all participants' UIs to show typing status
			for(var/datum/weakref/participant_ref as anything in participants)
				var/mob/living/participant = participant_ref.resolve()
				if(participant && !QDELETED(participant) && participant.rp_panel)
					SStgui.update_uis(participant.rp_panel)

		if("send_message")
			var/message = params["message"]
			if(!message || !length(message))
				return

			message = trim(message)
			if(!length(message))
				return

			// Remove from typing participants
			for(var/datum/weakref/typing_ref as anything in typing_participants)
				var/mob/living/typing_participant = typing_ref.resolve()
				if(typing_participant == holder)
					typing_participants -= typing_ref
					holder.remove_typing_indicator()
					if(!holder.active_thinking_indicator)
						REMOVE_TRAIT(holder, TRAIT_THINKING_IN_CHARACTER, CURRENTLY_TYPING_TRAIT)
					break

			// Set flag to prevent duplicate recording via signal handlers
			sending_message = TRUE

			// Apply autopunctuation if enabled
			if(holder.client?.autopunctuation)
				message = autopunct_bare(message)

			// Send the emote based on mode
			var/list/recipients = list()
			for(var/datum/weakref/participant_ref as anything in participants)
				var/mob/living/participant = participant_ref.resolve()
				if(participant && !QDELETED(participant))
					recipients += participant

			// Add holder to recipients if not already there
			if(!(holder in recipients))
				recipients += holder

			var/headshot_url = ""
			if(ishuman(holder))
				var/mob/living/carbon/human/human_holder = holder
				headshot_url = human_holder.dna?.features["headshot"] || ""
			else if(holder.client?.ckey)
				// Fallback to stored_link from preference datum (static cache)
				var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
				if(headshot_pref && headshot_pref.stored_link)
					headshot_url = headshot_pref.stored_link[holder.client.ckey] || ""

			// Create message entry for chat history (quotes added in frontend)
			var/list/message_entry = list(
				"name" = holder.name,
				"message" = message,
				"headshot" = headshot_url,
				"mode" = emote_mode,
				"timestamp" = time2text(world.timeofday, "HH:MM:SS"),
				"ref" = REF(holder)
			)

			// Send emote based on mode
			switch(emote_mode)
				if("say")
					// Regular say message
					holder.say(message)
					// Add to chat history for all participants
					messages += list(message_entry)
					// Sync to all participants' panels
					for(var/datum/weakref/participant_ref as anything in participants)
						var/mob/living/participant = participant_ref.resolve()
						if(participant && !QDELETED(participant) && participant.rp_panel)
							participant.rp_panel.messages += list(message_entry)
							SStgui.update_uis(participant.rp_panel)

				if("whisper")
					// Whisper message
					holder.whisper(message)
					// Add to chat history for all participants
					messages += list(message_entry)
					// Sync to all participants' panels
					for(var/datum/weakref/participant_ref as anything in participants)
						var/mob/living/participant = participant_ref.resolve()
						if(participant && !QDELETED(participant) && participant.rp_panel)
							participant.rp_panel.messages += list(message_entry)
							SStgui.update_uis(participant.rp_panel)

				if("public")
					// Public /me emote
					holder.emote("me", message = message, intentional = TRUE)
					// Add to chat history for all participants
					messages += list(message_entry)
					// Sync to all participants' panels
					for(var/datum/weakref/participant_ref as anything in participants)
						var/mob/living/participant = participant_ref.resolve()
						if(participant && !QDELETED(participant) && participant.rp_panel)
							participant.rp_panel.messages += list(message_entry)
							SStgui.update_uis(participant.rp_panel)

				if("subtle")
					// Subtle emote (1 tile range)
					var/space = should_have_space_before_emote(html_decode(message)) ? " " : ""
					var/subtle_message = span_subtle("<b>[holder]</b>[space]<i>[holder.apply_message_emphasis(message)]</i>")

					// If a participant is selected, send only to that target
					if(selected_participant && !QDELETED(selected_participant))
						var/mob/living/target = selected_participant
						holder.show_message(subtle_message, alt_msg = subtle_message)
						var/turf/holder_turf = get_turf(holder)
						var/turf/target_turf = get_turf(target)
						if(holder_turf && target_turf && get_dist(holder_turf, target_turf) <= 1)
							target.show_message(subtle_message, alt_msg = subtle_message)
					else
						// Send to all recipients in 1 tile range
						var/list/viewers = get_hearers_in_view(1, holder)
						for(var/mob/living/viewer in viewers)
							if(viewer in recipients)
								viewer.show_message(subtle_message, alt_msg = subtle_message)

					// Add to chat history for all participants
					messages += list(message_entry)
					// Sync to all participants' panels
					for(var/datum/weakref/participant_ref as anything in participants)
						var/mob/living/participant = participant_ref.resolve()
						if(participant && !QDELETED(participant) && participant.rp_panel)
							participant.rp_panel.messages += list(message_entry)
							SStgui.update_uis(participant.rp_panel)

				if("subtle_antighost")
					// Subtle antighost emote (default range, no ghosts)
					var/space = should_have_space_before_emote(html_decode(message)) ? " " : ""
					var/subtler_message = span_subtler("<b>[holder]</b>[space]<i>[holder.apply_message_emphasis(message)]</i>")

					// If a participant is selected, send only to that target
					if(selected_participant && !QDELETED(selected_participant))
						var/mob/living/target = selected_participant
						holder.show_message(subtler_message, alt_msg = subtler_message)
						var/turf/holder_turf = get_turf(holder)
						var/turf/target_turf = get_turf(target)
						if(holder_turf && target_turf && get_dist(holder_turf, target_turf) <= world.view)
							target.show_message(subtler_message, alt_msg = subtler_message)
					else
						// Send to all recipients in view (no ghosts)
						var/list/in_view = get_hearers_in_view(world.view, holder)
						in_view -= GLOB.dead_mob_list
						in_view.Remove(holder)

						// Filter out clientless mobs and AI eye
						for(var/mob/mob in in_view)
							if(istype(mob, /mob/eye/camera/ai))
								in_view.Remove(mob)
								continue
							if(!mob.client)
								in_view.Remove(mob)

						// Send to all recipients in view
						for(var/mob/living/viewer in in_view)
							if(viewer in recipients)
								viewer.show_message(subtler_message, alt_msg = subtler_message)

					// Add to chat history for all participants
					messages += list(message_entry)
					// Sync to all participants' panels
					for(var/datum/weakref/participant_ref as anything in participants)
						var/mob/living/participant = participant_ref.resolve()
						if(participant && !QDELETED(participant) && participant.rp_panel)
							participant.rp_panel.messages += list(message_entry)
							SStgui.update_uis(participant.rp_panel)

			// Play chime sound for all participants
			play_sound_to_participants('modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg')

			// Reset flag after a brief delay to allow signal handlers to complete
			spawn(1)
				sending_message = FALSE

			. = TRUE

// Play sound to all participants
/datum/rp_panel/proc/play_sound_to_participants(sound_file)
	if(!sound_file)
		return
	var/should_play = FALSE
	// Check which sound this is and if it's enabled
	if(sound_file == 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg')
		should_play = sound_message_enabled
	else if(sound_file == 'modular_zubbers/sound/misc/rppanelsounds/messagejoin.ogg')
		should_play = sound_join_enabled
	else if(sound_file == 'modular_zubbers/sound/misc/rppanelsounds/messageleave.ogg')
		should_play = sound_leave_enabled
	else
		should_play = TRUE // Default to enabled for unknown sounds

	if(!should_play)
		return

	for(var/datum/weakref/participant_ref as anything in participants)
		var/mob/living/participant = participant_ref.resolve()
		if(participant && !QDELETED(participant) && participant.client)
			participant.playsound_local(get_turf(holder), sound_file, 50, FALSE)
	// Also play to holder
	if(holder.client)
		holder.playsound_local(get_turf(holder), sound_file, 50, FALSE)

// Signal handler for external say messages
/datum/rp_panel/proc/on_say(mob/living/source, list/speech_args)
	SIGNAL_HANDLER
	if(!length(participants))
		return

	// Don't record if we're currently sending a message through the panel
	if(sending_message)
		return

	var/message = speech_args[SPEECH_MESSAGE]
	var/list/message_mods = speech_args[SPEECH_MODS] || list()

	// Only record if it's a regular say or whisper (not radio, etc.)
	if(message_mods[RADIO_EXTENSION])
		return

	// Determine mode
	var/mode = "say"
	if(message_mods[WHISPER_MODE])
		mode = "whisper"

	// Format message with quotation marks
	var/formatted_message = "\"[message]\""

	// Get headshot
	var/headshot_url = ""
	if(ishuman(holder))
		var/mob/living/carbon/human/human_holder = holder
		headshot_url = human_holder.dna?.features["headshot"] || ""
	else if(holder.client?.ckey)
		var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
		if(headshot_pref && headshot_pref.stored_link)
			headshot_url = headshot_pref.stored_link[holder.client.ckey] || ""

	// Create message entry
	var/list/message_entry = list(
		"name" = holder.name,
		"message" = formatted_message,
		"headshot" = headshot_url,
		"ref" = REF(holder),
		"mode" = mode,
		"timestamp" = time2text(world.timeofday, "HH:MM:SS")
	)

	// Add to all participants' panels
	messages += list(message_entry)
	for(var/datum/weakref/participant_ref as anything in participants)
		var/mob/living/participant = participant_ref.resolve()
		if(participant && !QDELETED(participant) && participant.rp_panel)
			participant.rp_panel.messages += list(message_entry)
			SStgui.update_uis(participant.rp_panel)
			// Play chime sound
			if(participant.client)
				participant.playsound_local(get_turf(holder), 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg', 50, FALSE)

	// Play chime for holder
	if(holder.client)
		holder.playsound_local(get_turf(holder), 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg', 50, FALSE)

// Signal handler for external emote messages
/datum/rp_panel/proc/on_emote(mob/living/source, datum/emote/emote, act, type_override, message, intentional)
	SIGNAL_HANDLER
	if(!length(participants))
		return

	// Don't record if we're currently sending a message through the panel
	if(sending_message)
		return

	// Record /me emotes and subtle (lewd) emotes
	var/emote_key = emote?.key
	if(emote_key != "me" && emote_key != "subtle")
		return

	var/emote_message = message || act || ""
	if(!emote_message)
		return

	// Determine mode based on emote type
	var/mode = "public"
	if(emote_key == "subtle")
		mode = "subtle"

	// Get headshot
	var/headshot_url = ""
	if(ishuman(holder))
		var/mob/living/carbon/human/human_holder = holder
		headshot_url = human_holder.dna?.features["headshot"] || ""
	else if(holder.client?.ckey)
		var/datum/preference/text/headshot/headshot_pref = GLOB.preference_entries[/datum/preference/text/headshot]
		if(headshot_pref && headshot_pref.stored_link)
			headshot_url = headshot_pref.stored_link[holder.client.ckey] || ""

	// Create message entry
	var/list/message_entry = list(
		"name" = holder.name,
		"message" = emote_message,
		"headshot" = headshot_url,
		"mode" = mode,
		"timestamp" = time2text(world.timeofday, "HH:MM:SS"),
		"ref" = REF(holder)
	)

	// Add to all participants' panels
	messages += list(message_entry)
	for(var/datum/weakref/participant_ref as anything in participants)
		var/mob/living/participant = participant_ref.resolve()
		if(participant && !QDELETED(participant) && participant.rp_panel)
			participant.rp_panel.messages += list(message_entry)
			SStgui.update_uis(participant.rp_panel)
			// Play chime sound
			if(participant.client)
				participant.playsound_local(get_turf(holder), 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg', 50, FALSE)

	// Play chime for holder
	if(holder.client)
		holder.playsound_local(get_turf(holder), 'modular_zubbers/sound/misc/rppanelsounds/messagechime.ogg', 50, FALSE)

// Check if a genital is actually exposed, accounting for visibility preferences, clothing, and underwear
// Helper proc to determine status display from preference value
// Returns "NO", "L(OOC)", "NOTE", or "YES" based on the preference choice
/datum/rp_panel/proc/get_preference_status(choice)
	if(!choice || choice == "No")
		return "NO"

	// Check for specific "Ask (L)OOC" variants
	if(findtext(choice, "Ask (L)OOC", 1, 11) || findtext(choice, "Ask", 1, 4))
		return "L(OOC)"

	// Check for "Check OOC Notes" or "Check OOC" variants
	if(findtext(choice, "Check OOC Notes", 1, 16) || findtext(choice, "Check OOC", 1, 10) || findtext(choice, "Check", 1, 6))
		return "NOTE"

	// Everything else (Yes, Top - Dom, etc.) is YES
	return "YES"

/datum/rp_panel/proc/is_genital_actually_exposed(mob/living/carbon/human/human, obj/item/organ/genital/genital)
	if(!genital || !human)
		return FALSE

	switch(genital.visibility_preference)
		if(GENITAL_ALWAYS_SHOW)
			return TRUE
		if(GENITAL_NEVER_SHOW)
			return FALSE
		if(GENITAL_HIDDEN_BY_CLOTHES)
			// Check if clothing covers the genital location
			if((human.w_uniform && human.w_uniform.body_parts_covered & genital.genital_location) || (human.wear_suit && human.wear_suit.body_parts_covered & genital.genital_location))
				return FALSE

			// Check for hospital gown
			if(istype(human.wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
				return FALSE

			// Check for undershirt
			if(human.undershirt != "Nude" && !(human.underwear_visibility & UNDERWEAR_HIDE_SHIRT))
				var/datum/sprite_accessory/undershirt/worn_undershirt = SSaccessories.undershirt_list[human.undershirt]
				if(worn_undershirt)
					if(genital.genital_location == CHEST)
						return FALSE
					else if(genital.genital_location == GROIN && worn_undershirt.hides_groin)
						return FALSE

			// Check for underwear
			if(human.underwear != "Nude" && !(human.underwear_visibility & UNDERWEAR_HIDE_UNDIES))
				var/datum/sprite_accessory/underwear/worn_underwear = SSaccessories.underwear_list[human.underwear]
				if(worn_underwear)
					if(genital.genital_location == GROIN)
						return FALSE
					else if(genital.genital_location == CHEST && worn_underwear.hides_breasts)
						return FALSE

			// Check for bra
			if(human.bra != "Nude" && !(human.underwear_visibility & UNDERWEAR_HIDE_BRA) && genital.genital_location == CHEST)
				return FALSE

			// Nothing is covering it
			return TRUE
		else
			return FALSE

// Check and remove participants who are out of range
/datum/rp_panel/proc/check_and_remove_out_of_range()
	var/turf/holder_turf = get_turf(holder)
	if(!holder_turf)
		return

	var/list/to_remove = list()
	for(var/datum/weakref/participant_ref as anything in participants)
		var/mob/living/participant = participant_ref.resolve()
		if(!participant || QDELETED(participant))
			to_remove += participant_ref
			continue

		var/turf/participant_turf = get_turf(participant)
		if(!participant_turf || get_dist(holder_turf, participant_turf) > 2)
			to_remove += participant_ref
			// Remove holder from participant's panel as well
			if(participant.rp_panel)
				for(var/datum/weakref/other_ref as anything in participant.rp_panel.participants)
					var/mob/living/other = other_ref.resolve()
					if(other == holder)
						participant.rp_panel.participants -= other_ref
						to_chat(participant, span_notice("[holder] has left the RP panel range."))
						SStgui.update_uis(participant.rp_panel)
						break
			// Play leave sound
			play_sound_to_participants('modular_zubbers/sound/misc/rppanelsounds/messageleave.ogg')
			to_chat(holder, span_notice("[participant] has left the RP panel range and was removed."))

	// Remove out-of-range participants
	for(var/datum/weakref/ref_to_remove as anything in to_remove)
		participants -= ref_to_remove

// Get verb mode data (interactions from participants)
/datum/rp_panel/proc/get_verb_mode_data(mob/user)
	var/list/verb_data = list()

	// Determine target participant (selected or holder)
	var/mob/living/target_participant = selected_participant
	if(!target_participant || QDELETED(target_participant))
		target_participant = holder

	if(!ishuman(target_participant))
		return verb_data

	var/datum/component/interactable/interaction_component = target_participant.GetComponent(/datum/component/interactable)
	if(!interaction_component)
		return verb_data

	// Build interaction data similar to interaction_component.ui_data
	var/list/descriptions = list()
	var/list/categories = list()
	var/list/display_categories = list()
	var/list/colors = list()

	// Check ERP preferences for filtering Sex verbs
	var/show_sex_verbs = FALSE
	if(holder.client?.prefs)
		var/erp_enabled = holder.client.prefs.read_preference(/datum/preference/toggle/erp)
		var/erp_mechanics = holder.client.prefs.read_preference(/datum/preference/choiced/erp_status_mechanics)
		// Show sex verbs only if ERP is enabled AND mechanics is Mechanical or Mechanical and Roleplay
		if(erp_enabled && (erp_mechanics == "Mechanical only" || erp_mechanics == "Mechanical and Roleplay"))
			show_sex_verbs = TRUE

	for(var/datum/interaction/interaction in interaction_component.interactions)
		if(!interaction_component.can_interact(interaction, holder))
			continue
		if(interaction.category == INTERACTION_CAT_HIDE)
			continue

		// Hide Sex interactions if ERP/mechanics requirements not met (Romance is always shown)
		if(interaction.category == "Sex" && !show_sex_verbs)
			continue

			if(!categories[interaction.category])
				categories[interaction.category] = list(interaction.name)
			else
				categories[interaction.category] += interaction.name
				var/list/sorted_category = sort_list(categories[interaction.category])
				categories[interaction.category] = sorted_category
			descriptions[interaction.name] = interaction.description
			colors[interaction.name] = interaction.color


	for(var/category in categories)
		display_categories += category

	// Get lewd slots (using generate_strip_entry from interaction component)
	var/list/lewd_slots = list()
	if(ishuman(holder) && ishuman(target_participant))
		var/mob/living/carbon/human/human_holder = holder
		var/mob/living/carbon/human/human_target = target_participant
		if(interaction_component.can_lewd_strip(human_holder, human_target))
			if(human_target.client?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy))
				if(human_target.has_vagina())
					lewd_slots += list(interaction_component.generate_strip_entry(ORGAN_SLOT_VAGINA, human_target, human_holder, human_target.vagina))
				if(human_target.has_penis())
					lewd_slots += list(interaction_component.generate_strip_entry(ORGAN_SLOT_PENIS, human_target, human_holder, human_target.penis))
				if(human_target.has_anus())
					lewd_slots += list(interaction_component.generate_strip_entry(ORGAN_SLOT_ANUS, human_target, human_holder, human_target.anus))
				lewd_slots += list(interaction_component.generate_strip_entry(ORGAN_SLOT_NIPPLES, human_target, human_holder, human_target.nipples))

	verb_data = list(
		"name" = target_participant.name,
		"ref" = REF(target_participant),
		"categories" = sort_list(display_categories),
		"interactions" = categories,
		"descriptions" = descriptions,
		"colors" = colors,
		"block_interact" = interaction_component.interact_next >= world.time,
		"lewd_slots" = lewd_slots
	)

	return verb_data

/mob/living/Destroy()
	QDEL_NULL(rp_panel)
	return ..()

// Helper proc to open RP panel
/mob/living/proc/open_rp_panel_proc(mob/living/target_mob, mob/living/caller = null)
	// caller can be provided for admin verbs, otherwise use usr
	var/mob/living/living_user = caller || usr

	if(!isliving(living_user))
		return

	// Create RP panel if it doesn't exist
	if(!living_user.rp_panel)
		living_user.rp_panel = new(living_user)

	// Open the panel
	living_user.rp_panel.ui_interact(living_user)

	// If clicking on another player (not yourself), auto-add them if in range
	if(living_user != target_mob && isliving(target_mob))
		var/turf/user_turf = get_turf(living_user)
		var/turf/target_turf = get_turf(target_mob)
		if(user_turf && target_turf && get_dist(user_turf, target_turf) <= 2)
			var/already_added = FALSE
			for(var/datum/weakref/participant_ref as anything in living_user.rp_panel.participants)
				var/mob/living/participant = participant_ref.resolve()
				if(participant == target_mob)
					already_added = TRUE
					break

			if(!already_added)
				living_user.rp_panel.participants += WEAKREF(target_mob)
				to_chat(living_user, span_notice("Added [target_mob] to the RP panel."))

				// Open the target's RP panel if they don't have one open
				if(!target_mob.rp_panel)
					target_mob.rp_panel = new(target_mob)

				// Sync participants - add living_user to target's panel
				var/already_in_target_panel = FALSE
				for(var/datum/weakref/other_ref as anything in target_mob.rp_panel.participants)
					var/mob/living/other = other_ref.resolve()
					if(other == living_user)
						already_in_target_panel = TRUE
						break

				if(!already_in_target_panel)
					target_mob.rp_panel.participants += WEAKREF(living_user)

				// Sync messages - copy all messages from living_user's panel to target's panel
				for(var/list/msg as anything in living_user.rp_panel.messages)
					var/found = FALSE
					for(var/list/existing_msg as anything in target_mob.rp_panel.messages)
						if(existing_msg["name"] == msg["name"] && existing_msg["message"] == msg["message"] && existing_msg["mode"] == msg["mode"])
							found = TRUE
							break
					if(!found)
						target_mob.rp_panel.messages += list(msg)

				// Copy messages from target's panel to living_user's panel
				for(var/list/msg as anything in target_mob.rp_panel.messages)
					var/found = FALSE
					for(var/list/existing_msg as anything in living_user.rp_panel.messages)
						if(existing_msg["name"] == msg["name"] && existing_msg["message"] == msg["message"] && existing_msg["mode"] == msg["mode"])
							found = TRUE
							break
					if(!found)
						living_user.rp_panel.messages += list(msg)

				// Open the target's panel
				target_mob.rp_panel.ui_interact(target_mob)

// Verb to open RP panel - available in context menu
// This verb appears when you shift-right click on any living mob
/mob/living/verb/open_rp_panel()
	set name = "RP Panel"
	set category = "IC"
	set desc = "Open the RP panel for roleplay interactions"
	set hidden = FALSE // Ensure it's visible

	open_rp_panel_proc(src)

// Admin verb version - appears in admin context menu
ADMIN_VERB_ONLY_CONTEXT_MENU(open_rp_panel_admin, R_ADMIN, "RP Panel", mob/living/target in world)
	// Allow admins to use RP panel on mobs without clients (for testing)
	if(!target)
		to_chat(user, span_warning("Invalid target."), confidential = TRUE)
		return

	if(!isliving(user.mob))
		to_chat(user, span_warning("You must be a living mob to use the RP panel."), confidential = TRUE)
		return

	// Call the helper proc with the admin's mob as the caller
	target.open_rp_panel_proc(target, user.mob)

