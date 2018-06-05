/mob/living/silicon/android/Process_Spacemove(movement_dir = 0)
	return ..()

/mob/living/silicon/android/movement_delay()
	. = ..()
	var/static/config_robot_delay
	if(isnull(config_robot_delay))
		config_robot_delay = CONFIG_GET(number/robot_delay)
	. += speed + config_robot_delay

/mob/living/silicon/android/mob_negates_gravity()
	return magpulse

/mob/living/silicon/android/mob_has_gravity()
	return ..() || mob_negates_gravity()

/mob/living/silicon/android/experience_pressure_difference(pressure_difference, direction)
	if(!magpulse)
		return ..()
