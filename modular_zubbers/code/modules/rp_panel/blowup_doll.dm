/**
 * Blowup Doll - A test dummy mob for testing RP Panel verbs
 * Uses a normal human body with all genitals (penis, testicles, breasts, vagina, uterus) for comprehensive verb testing
 */

/mob/living/carbon/human/blowup_doll
	name = "Blow-Up Bianca!"
	real_name = "Blow-Up Bianca!"
	desc = "A life-sized blowup doll used for testing RP interactions. It has a realistic human body with all genitals for comprehensive testing."
	gender = FEMALE
	// Make it obvious this is a test dummy
	ai_controller = null // No AI
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID

/mob/living/carbon/human/blowup_doll/Initialize(mapload)
	. = ..()
	// Set up as a human female
	set_species(/datum/species/human)
	gender = FEMALE
	
	// Add the interactable component for verb testing
	AddComponent(/datum/component/interactable)
	
	// Ensure all necessary genitals are present for testing
	// Create penis if it doesn't exist
	if(!get_organ_slot(ORGAN_SLOT_PENIS))
		var/obj/item/organ/genital/penis/new_penis = new
		new_penis.build_from_dna(dna, ORGAN_SLOT_PENIS)
		new_penis.Insert(src, 0, FALSE)
		new_penis.genital_size = 4
		new_penis.girth = 3
	
	// Create testicles if they don't exist
	if(!get_organ_slot(ORGAN_SLOT_TESTICLES))
		var/obj/item/organ/genital/testicles/new_balls = new
		new_balls.build_from_dna(dna, ORGAN_SLOT_TESTICLES)
		new_balls.Insert(src, 0, FALSE)
		new_balls.genital_size = 0
	
	// Create breasts if they don't exist
	if(!get_organ_slot(ORGAN_SLOT_BREASTS))
		if(dna.mutant_bodyparts[ORGAN_SLOT_BREASTS][MUTANT_INDEX_NAME] == "None")
			dna.mutant_bodyparts[ORGAN_SLOT_BREASTS][MUTANT_INDEX_NAME] = "Pair"
		var/obj/item/organ/genital/breasts/new_breasts = new
		new_breasts.build_from_dna(dna, ORGAN_SLOT_BREASTS)
		new_breasts.Insert(src, FALSE, FALSE)
		new_breasts.genital_size = 2
	
	// Create vagina if it doesn't exist
	if(!get_organ_slot(ORGAN_SLOT_VAGINA))
		if(dna.mutant_bodyparts[ORGAN_SLOT_VAGINA][MUTANT_INDEX_NAME] == "None")
			dna.mutant_bodyparts[ORGAN_SLOT_VAGINA][MUTANT_INDEX_NAME] = "Human"
		var/obj/item/organ/genital/vagina/new_vagina = new
		new_vagina.build_from_dna(dna, ORGAN_SLOT_VAGINA)
		new_vagina.Insert(src, 0, FALSE)
	
	// Create womb (uterus) if it doesn't exist
	if(!get_organ_slot(ORGAN_SLOT_WOMB))
		if(dna.mutant_bodyparts[ORGAN_SLOT_WOMB][MUTANT_INDEX_NAME] == "None")
			dna.mutant_bodyparts[ORGAN_SLOT_WOMB][MUTANT_INDEX_NAME] = "Normal"
		var/obj/item/organ/genital/womb/new_womb = new
		new_womb.build_from_dna(dna, ORGAN_SLOT_WOMB)
		new_womb.Insert(src, 0, FALSE)

/mob/living/carbon/human/blowup_doll/Login()
	. = ..()
	// When a client logs in (for admin testing), set ERP preferences
	if(client && client.prefs)
		// Set ERP to enabled
		client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp], TRUE)
		// Set ERP mechanics to "Mechanical and Roleplay"
		client.prefs.write_preference(GLOB.preference_entries[/datum/preference/choiced/erp_status_mechanics], "Mechanical and Roleplay")
		// Set Depraved to "Yes"
		client.prefs.write_preference(GLOB.preference_entries[/datum/preference/choiced/erp_status_depraved], "Yes")
		// Set Violent to "Yes"
		client.prefs.write_preference(GLOB.preference_entries[/datum/preference/choiced/erp_status_violent], "Yes")

/mob/living/carbon/human/blowup_doll/examine(mob/user)
	. = ..()
	. += span_notice("This appears to be a test dummy for RP interactions.")

// Admin verb to spawn a Blowup Doll
/client/proc/spawn_blowup_doll()
	set name = "Spawn Blowup Doll"
	set category = "Admin.RP Panel"
	set desc = "Spawn a Blowup Doll test dummy for testing RP Panel verbs"
	
	if(!check_rights(R_ADMIN))
		return
	
	var/turf/spawn_turf = get_turf(usr)
	if(!spawn_turf)
		to_chat(usr, span_warning("Invalid spawn location."))
		return
	
	var/mob/living/carbon/human/blowup_doll/doll = new(spawn_turf)
	doll.ckey = null // No client initially
	
	// Set up preferences if we have a client (for testing)
	if(usr.client && usr.client.prefs)
		// Copy some preferences from the admin for testing
		doll.name = "Blow-Up Bianca! ([usr.key])"
		doll.real_name = doll.name
	
	message_admins("[key_name_admin(usr)] spawned a Blowup Doll at [ADMIN_COORDJMP(spawn_turf)]")
	log_admin("[key_name(usr)] spawned a Blowup Doll at [COORD(spawn_turf)]")
	to_chat(usr, span_notice("Spawned Blowup Doll at your location."))
