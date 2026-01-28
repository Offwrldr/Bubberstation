
/datum/component/interactable
	/// A hard reference to the parent
	var/mob/living/carbon/human/self = null
	/// A list of interactions that the user can engage in.
	var/list/datum/interaction/interactions
	var/interact_last = 0
	var/interact_next = 0
	///Holds a reference to a relayed body if one exists
	var/obj/body_relay = null

/datum/component/interactable/Initialize(...)
	if(QDELETED(parent))
		qdel(src)
		return

	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

	self = parent

	build_interactions_list()

/datum/component/interactable/proc/build_interactions_list()
	interactions = list()
	for(var/iterating_interaction_id in GLOB.interaction_instances)
		var/datum/interaction/interaction = GLOB.interaction_instances[iterating_interaction_id]
		if(interaction.lewd)
			if(!self.client?.prefs?.read_preference(/datum/preference/toggle/erp))
				continue
			if(interaction.sexuality != "" && interaction.sexuality != self.client?.prefs?.read_preference(/datum/preference/choiced/erp_sexuality))
				continue
			// Filter by Depraved preference
			if(interaction.category_depraved)
				var/depraved_pref = self.client?.prefs?.read_preference(/datum/preference/choiced/erp_status_depraved) || "No"
				if(depraved_pref == "No")
					continue
			// Filter by Violent preference
			if(interaction.category_violent)
				var/violent_pref = self.client?.prefs?.read_preference(/datum/preference/choiced/erp_status_violent) || "No"
				if(violent_pref == "No")
					continue
		interactions.Add(interaction)

/datum/component/interactable/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT, PROC_REF(open_interaction_menu))

/datum/component/interactable/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT)

/datum/component/interactable/Destroy(force, silent)
	self = null
	interactions = null
	return ..()

/datum/component/interactable/proc/open_interaction_menu(datum/source, mob/user)
	if(!ishuman(user))
		return
	build_interactions_list()
	ui_interact(user)

/datum/component/interactable/proc/has_required_parts(mob/living/carbon/human/user, list/required_parts)
	if(!required_parts || !required_parts.len)
		return TRUE
	if(!ishuman(user))
		return FALSE

	for(var/part_string in required_parts)
		var/part_slot = map_part_string_to_slot(part_string)
		if(!part_slot)
			continue

		// Handle special cases
		switch(part_slot)
			if("hands")
				// Check if user has hands (arms)
				var/has_hands = FALSE
				for(var/obj/item/bodypart/arm/arm in user.bodyparts)
					has_hands = TRUE
					break
				if(!has_hands)
					return FALSE
			if("feet")
				// Check if user has feet (legs)
				var/has_feet = FALSE
				for(var/obj/item/bodypart/leg/leg in user.bodyparts)
					has_feet = TRUE
					break
				if(!has_feet)
					return FALSE
			if("arms", "armpits")
				// Check if user has arms
				var/has_arms = FALSE
				for(var/obj/item/bodypart/arm/arm in user.bodyparts)
					has_arms = TRUE
					break
				if(!has_arms)
					return FALSE
			if("belly")
				// Belly/stomach is always present
				continue
			if("tail")
				// Check if user has a tail
				var/obj/item/organ/tail/tail_organ = user.get_organ_slot(ORGAN_SLOT_TAIL)
				if(!tail_organ)
					return FALSE
			else
				// Regular organ slot check
				var/obj/item/organ/organ = user.get_organ_slot(part_slot)
				if(!organ)
					return FALSE
	return TRUE

/datum/component/interactable/proc/map_part_string_to_slot(part_string)
	switch(lowertext(part_string))
		if("mouth", "tongue")
			return ORGAN_SLOT_TONGUE
		if("penis", "cock")
			return ORGAN_SLOT_PENIS
		if("vagina", "pussy")
			return ORGAN_SLOT_VAGINA
		if("anus", "ass")
			return ORGAN_SLOT_ANUS
		if("breasts", "breast")
			return ORGAN_SLOT_BREASTS
		if("testicles", "balls")
			return ORGAN_SLOT_TESTICLES
		if("tail")
			return ORGAN_SLOT_TAIL
		if("hands", "hand")
			// Hands are special - check if user has hands
			return "hands" // Special case
		if("feet", "paws", "foot", "paw")
			// Feet are special - check if user has feet
			return "feet" // Special case
		if("arms", "arm")
			// Arms are special
			return "arms" // Special case
		if("armpits", "armpit")
			// Armpits are part of arms
			return "armpits" // Special case
		if("belly", "stomach")
			// Belly/stomach is always present
			return "belly" // Special case
		else
			return null

/datum/component/interactable/proc/can_interact(datum/interaction/interaction, mob/living/carbon/human/user)
	// user is the person performing the interaction (holder)
	// self is the target (component owner)
	if(!interaction.allow_act(user, self))
		return FALSE
	// For lewd interactions, both actor (user) and target (self) must have ERP enabled
	if(interaction.lewd)
		// Check actor's ERP preference
		if(!user.client?.prefs?.read_preference(/datum/preference/toggle/erp))
			return FALSE
		// Check target's ERP preference
		if(!self.client?.prefs?.read_preference(/datum/preference/toggle/erp))
			return FALSE
	if(!interaction.distance_allowed && !user.Adjacent(self))
		if(!body_relay || !user.Adjacent(body_relay))
			return FALSE
	if(interaction.category == INTERACTION_CAT_HIDE)
		return FALSE
	if(self == user && interaction.usage == INTERACTION_OTHER)
		return FALSE

	// Check if user has required parts (user_required_parts)
	if(!has_required_parts(user, interaction.user_required_parts))
		return FALSE

	// Check if target (self) has required parts (target_required_parts)
	if(!has_required_parts(self, interaction.target_required_parts))
		return FALSE

	return TRUE

/// UI Control
/datum/component/interactable/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "InteractionMenu")
		ui.open()

/datum/component/interactable/ui_status(mob/user, datum/ui_state/state)
	if(!ishuman(user))
		return UI_CLOSE

	return UI_INTERACTIVE // This UI is always interactive as we handle distance flags via can_interact

/datum/component/interactable/ui_data(mob/user)
	var/list/data = list()
	var/list/descriptions = list()
	var/list/categories = list()
	var/list/display_categories = list()
	var/list/colors = list()
	for(var/datum/interaction/interaction in interactions)
		if(!can_interact(interaction, user))
			continue
		if(!categories[interaction.category])
			categories[interaction.category] = list(interaction.name)
		else
			categories[interaction.category] += interaction.name
			var/list/sorted_category = sort_list(categories[interaction.category])
			categories[interaction.category] = sorted_category
		descriptions[interaction.name] = interaction.description
		colors[interaction.name] = interaction.color
	data["descriptions"] = descriptions
	data["colors"] = colors
	for(var/category in categories)
		display_categories += category
	data["categories"] = sort_list(display_categories)
	data["ref_user"] = REF(user)
	data["ref_self"] = REF(self)
	data["self"] = self.name
	if(body_relay)
		if(!can_see(user, self))
			data["self"] = body_relay.name
	data["block_interact"] = interact_next >= world.time
	data["interactions"] = categories

	var/list/parts = list()

	if(ishuman(user) && can_lewd_strip(user, self))
		if(self.client?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy))
			if(self.has_vagina())
				parts += list(generate_strip_entry(ORGAN_SLOT_VAGINA, self, user, self.vagina))
			if(self.has_penis())
				parts += list(generate_strip_entry(ORGAN_SLOT_PENIS, self, user, self.penis))
			if(self.has_anus())
				parts += list(generate_strip_entry(ORGAN_SLOT_ANUS, self, user, self.anus))
			parts += list(generate_strip_entry(ORGAN_SLOT_NIPPLES, self, user, self.nipples))

	data["lewd_slots"] = parts

	return data

/**
 *  Takes the organ slot name, along with a target and source, along with the item on the target that the source can potentially interact with.
 *  If the source can't interact with said slot, or there is no item in the first place, it'll set the icon to null to indicate that TGUI should put a placeholder sprite.
 *
 * Arguments:
 * * name - The name of slot to check and return inside the generated list.
 * * target - The mob that's being interacted with.
 * * source - The mob that's interacting.
 * * item - The item that's currently inside said slot. Can be null.
 */
/datum/component/interactable/proc/generate_strip_entry(name, mob/living/carbon/human/target, mob/living/carbon/human/source, obj/item/clothing/sextoy/item)
	return list(
		"name" = name,
		"img" = (item && can_lewd_strip(source, target, name)) ? icon2base64(icon(item.icon, item.icon_state, SOUTH, 1)) : null
		)

/datum/component/interactable/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	if(!ishuman(usr))
		return

	if(params["interaction"])
		var/interaction_id = params["interaction"]
		if(GLOB.interaction_instances[interaction_id])
			var/mob/living/carbon/human/user = locate(params["userref"])
			if(!can_interact(GLOB.interaction_instances[interaction_id], user))
				return FALSE
			if(body_relay && !can_see(user, self))
				GLOB.interaction_instances[interaction_id].act(user, locate(params["selfref"]), body_relay)
			else
				GLOB.interaction_instances[interaction_id].act(user, locate(params["selfref"]))
			var/datum/component/interactable/interaction_component = user.GetComponent(/datum/component/interactable)
			interaction_component.interact_last = world.time
			interact_next = interaction_component.interact_last + INTERACTION_COOLDOWN
			interaction_component.interact_next = interact_next
			return TRUE

	if(params["item_slot"])
		// This code should be easy enough to follow... I hope.
		var/item_index = params["item_slot"]
		var/mob/living/carbon/human/source = locate(params["userref"])
		var/mob/living/carbon/human/target = locate(params["selfref"])
		var/obj/item/clothing/sextoy/new_item = source.get_active_held_item()
		var/obj/item/clothing/sextoy/existing_item = target.vars[item_index]

		if(!existing_item && !new_item)
			source.show_message(span_warning("No item to insert or remove!"))
			return

		if(!existing_item && !istype(new_item))
			source.show_message(span_warning("The item you're holding is not a toy!"))
			return

		if(can_lewd_strip(source, target, item_index) && is_toy_compatible(new_item, item_index))
			var/internal = (item_index in list(ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS))
			var/insert_or_attach = internal ? "insert" : "attach"
			var/into_or_onto = internal ? "into" : "onto"

			if(existing_item)
				source.visible_message(span_purple("[source.name] starts trying to remove something from [target.name]'s [item_index]."), span_purple("You start to remove [existing_item.name] from [target.name]'s [item_index]."), span_purple("You hear someone trying to remove something from someone nearby."), vision_distance = 1, ignored_mobs = list(target))
			else if (new_item)
				source.visible_message(span_purple("[source.name] starts trying to [insert_or_attach] the [new_item.name] [into_or_onto] [target.name]'s [item_index]."), span_purple("You start to [insert_or_attach] the [new_item.name] [into_or_onto] [target.name]'s [item_index]."), span_purple("You hear someone trying to [insert_or_attach] something [into_or_onto] someone nearby."), vision_distance = 1, ignored_mobs = list(target))
			if (source != target)
				target.show_message(span_warning("[source.name] is trying to [existing_item ? "remove the [existing_item.name] [internal ? "in" : "on"]" : new_item ? "is trying to [insert_or_attach] the [new_item.name] [into_or_onto]" : span_alert("What the fuck, impossible condition? interaction_component.dm!")] your [item_index]!"))
			if(do_after(
				source,
				5 SECONDS,
				target,
				interaction_key = "interaction_[item_index]"
				) && can_lewd_strip(source, target, item_index))

				if(existing_item)
					source.visible_message(span_purple("[source.name] removes [existing_item.name] from [target.name]'s [item_index]."), span_purple("You remove [existing_item.name] from [target.name]'s [item_index]."), span_purple("You hear someone remove something from someone nearby."), vision_distance = 1)
					target.dropItemToGround(existing_item, force = TRUE) // Force is true, cause nodrop shouldn't affect lewd items.
					target.vars[item_index] = null
				else if (new_item)
					source.visible_message(span_purple("[source.name] [internal ? "inserts" : "attaches"] the [new_item.name] [into_or_onto] [target.name]'s [item_index]."), span_purple("You [insert_or_attach] the [new_item.name] [into_or_onto] [target.name]'s [item_index]."), span_purple("You hear someone [insert_or_attach] something [into_or_onto] someone nearby."), vision_distance = 1)
					target.vars[item_index] = new_item
					new_item.forceMove(target)
					new_item.lewd_equipped(target, item_index)
				target.update_inv_lewd()

		else
			source.show_message(span_warning("Failed to adjust [target.name]'s toys!"))

		return TRUE

	message_admins("Unhandled interaction '[params["interaction"]]'. Inform coders.")

/// Checks if the target has ERP toys enabled, and can be logially reached by the user.
/datum/component/interactable/proc/can_lewd_strip(mob/living/carbon/human/source, mob/living/carbon/human/target, slot_index)
	if(!target.client?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy))
		return FALSE
	if(!(source.loc == target.loc || source.Adjacent(target)))
		return FALSE
	if(!source.has_arms())
		return FALSE
	if(!slot_index) // This condition is for the UI to decide if the button is shown at all. Slot index should never be null otherwise.
		return TRUE

	switch(slot_index)
		if(ORGAN_SLOT_NIPPLES)
			var/chest_exposed = target.has_breasts(required_state = REQUIRE_GENITAL_EXPOSED)
			if(!chest_exposed)
				chest_exposed = target.is_topless() // for when we don't have breasts

			return chest_exposed

		if(ORGAN_SLOT_PENIS)
			return target.has_penis(required_state = REQUIRE_GENITAL_EXPOSED)
		if(ORGAN_SLOT_VAGINA)
			return target.has_vagina(required_state = REQUIRE_GENITAL_EXPOSED)
		if(ORGAN_SLOT_ANUS)
			return target.has_anus(required_state = REQUIRE_GENITAL_EXPOSED)

/// Decides if a player should be able to insert or remove an item from a provided lewd slot_index.
/datum/component/interactable/proc/is_toy_compatible(obj/item/clothing/sextoy/item, slot_index)
	if(!item) // Used for UI code, should never be actually null during actual logic code.
		return TRUE

	switch(slot_index)
		if(ORGAN_SLOT_VAGINA)
			return item.lewd_slot_flags & LEWD_SLOT_VAGINA
		if(ORGAN_SLOT_PENIS)
			return item.lewd_slot_flags & LEWD_SLOT_PENIS
		if(ORGAN_SLOT_ANUS)
			return item.lewd_slot_flags & LEWD_SLOT_ANUS
		if(ORGAN_SLOT_NIPPLES)
			return item.lewd_slot_flags & LEWD_SLOT_NIPPLES
		else
			return FALSE
