/mob/living/silicon/android/Life()
	set invisibility = 0
	if (src.notransform)
		return

	..()
	adjustOxyLoss(-10) //we're a robot!
	handle_robot_hud_updates()
	update_health_hud()
	handle_robot_cell()

/mob/living/silicon/android/proc/handle_robot_cell()
	if(stat != DEAD)
		if(low_power_mode)
			if(cell && cell.charge)
				low_power_mode = 0
				update_eye_lights()
		else if(stat == CONSCIOUS)
			use_power()

/mob/living/silicon/android/proc/use_power()
	if(cell && cell.charge)
		var/amt = CLAMP((lamp_intensity - 2) * 2,1,cell.charge) //Always try to use at least one charge per tick, but allow it to completely drain the cell.
		cell.use(amt) //Usage table: 1/tick if off/lowest setting, 4 = 4/tick, 6 = 8/tick, 8 = 12/tick, 10 = 16/tick
	else
		low_power_mode = 1
		update_eye_lights()

/mob/living/silicon/android/proc/handle_robot_hud_updates()
	if(!client)
		return

	update_cell_hud_icon()

/mob/living/silicon/android/update_health_hud()
	if(!client || !hud_used)
		return
	if(hud_used.healths)
		if(stat != DEAD)
			if(health >= maxHealth)
				hud_used.healths.icon_state = "health0"
			else if(health > maxHealth*0.6)
				hud_used.healths.icon_state = "health2"
			else if(health > maxHealth*0.2)
				hud_used.healths.icon_state = "health3"
			else if(health > -maxHealth*0.2)
				hud_used.healths.icon_state = "health4"
			else if(health > -maxHealth*0.6)
				hud_used.healths.icon_state = "health5"
			else
				hud_used.healths.icon_state = "health6"
		else
			hud_used.healths.icon_state = "health7"

/mob/living/silicon/android/proc/update_cell_hud_icon()
	if(cell)
		var/cellcharge = cell.charge/cell.maxcharge
		switch(cellcharge)
			if(0.75 to INFINITY)
				clear_alert("charge")
			if(0.5 to 0.75)
				throw_alert("charge", /obj/screen/alert/lowcell, 1)
			if(0.25 to 0.5)
				throw_alert("charge", /obj/screen/alert/lowcell, 2)
			if(0.01 to 0.25)
				throw_alert("charge", /obj/screen/alert/lowcell, 3)
			else
				throw_alert("charge", /obj/screen/alert/emptycell)
	else
		throw_alert("charge", /obj/screen/alert/nocell)

//Robots on fire
/mob/living/silicon/android/handle_fire()
	if(..())
		return
	if(fire_stacks > 0)
		fire_stacks--
		fire_stacks = max(0, fire_stacks)
	else
		ExtinguishMob()

	//adjustFireLoss(3)
	return

/mob/living/silicon/android/update_fire()
	var/mutable_appearance/fire_overlay = mutable_appearance('icons/mob/OnFire.dmi', "Generic_mob_burning")
	if(on_fire)
		add_overlay(fire_overlay)
	else
		cut_overlay(fire_overlay)

/mob/living/silicon/android/update_canmove()
	if(stat || buckled || lockcharge)
		canmove = 0
	else
		canmove = 1
	update_transform()
	update_action_buttons_icon()
	return canmove
