/mob/living/silicon/android
	name = "Android"
	real_name = "Android"
	icon = 'icons/mob/robots.dmi'
	icon_state = "robot"
	maxHealth = 100
	health = 100
	bubble_icon = "robot"
	designation = "Default" //used for displaying the prefix & getting the current module of cyborg
	has_limbs = 1

	var/custom_name = ""
	var/braintype = "Android"
	var/obj/item/robot_suit/robot_suit = null //Used for deconstruction to remember what the borg was constructed out of..
	var/obj/item/mmi/posibrain/posibrain = null

	var/deployed = FALSE
	var/datum/action/innate/undeployment/undeployment_action = new

//Hud stuff

	var/obj/screen/inv1 = null
	var/obj/screen/inv2 = null
	var/obj/screen/inv3 = null
	var/obj/screen/lamp_button = null
	var/obj/screen/thruster_button = null
	var/obj/screen/hands = null

	var/shown_robot_modules = 0	//Used to determine whether they have the module menu shown or not
	var/obj/screen/robot_modules_background

//3 Modules can be activated at any one time.
	var/obj/item/robot_module/module = null
	var/obj/item/module_active = null
	held_items = list(null, null, null) //we use held_items for the module holding, because that makes sense to do!

	var/mutable_appearance/eye_lights

	var/obj/item/stock_parts/cell/cell = null

	var/opened = 0
	var/emagged = FALSE
	var/emag_cooldown = 0
	var/wiresexposed = 0

	var/ident = 0
	var/locked = TRUE
	var/list/req_access = list(ACCESS_ROBOTICS)

	var/alarms = list("Motion"=list(), "Fire"=list(), "Atmosphere"=list(), "Power"=list(), "Camera"=list(), "Burglar"=list())

	var/speed = 0 // VTEC speed boost.
	var/magpulse = FALSE // Magboot-like effect.
	var/ionpulse = FALSE // Jetpack-like effect.
	var/ionpulse_on = FALSE // Jetpack-like effect.
	var/datum/effect_system/trail_follow/ion/ion_trail // Ionpulse effect.

	var/low_power_mode = 0 //whether the robot has no charge left.
	var/datum/effect_system/spark_spread/spark_system // So they can initialize sparks whenever/N

	var/lawupdate = 1 //Cyborgs will sync their laws with their AI by default
	var/scrambledcodes = 0 // Used to determine if a borg shows up on the robotics console.  Setting to one hides them.
	var/lockcharge //Boolean of whether the borg is locked down or not

	var/toner = 0
	var/tonermax = 40

	var/lamp_max = 10 //Maximum brightness of a borg lamp. Set as a var for easy adjusting.
	var/lamp_intensity = 0 //Luminosity of the headlamp. 0 is off. Higher settings than the minimum require power.
	var/lamp_cooldown = 0 //Flag for if the lamp is on cooldown after being forcibly disabled.

	var/sight_mode = 0
	hud_possible = list(ANTAG_HUD, DIAG_STAT_HUD, DIAG_HUD, DIAG_BATT_HUD, DIAG_TRACK_HUD)

	var/list/upgrades = list()

	var/hasExpanded = FALSE
	var/obj/item/hat
	var/hat_offset = -3

	buckle_lying = FALSE

/mob/living/silicon/android/get_cell()
	return cell

/mob/living/silicon/android/Initialize(mapload)
	spark_system = new /datum/effect_system/spark_spread()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)

	wires = new /datum/wires/robot(src)

	robot_modules_background = new()
	robot_modules_background.icon_state = "block"
	robot_modules_background.layer = HUD_LAYER	//Objects that appear on screen are on layer ABOVE_HUD_LAYER, UI should be just below it.
	robot_modules_background.plane = HUD_PLANE

	ident = rand(1, 999)

	if(!cell)
		cell = new /obj/item/stock_parts/cell/high(src)

	if(lawupdate)
		make_laws()

	radio = new /obj/item/radio/borg(src)
	if(!scrambledcodes && !builtInCamera)
		builtInCamera = new (src)
		builtInCamera.c_tag = real_name
		builtInCamera.network = list("ss13")
		builtInCamera.internal_light = FALSE
		if(wires.is_cut(WIRE_CAMERA))
			builtInCamera.status = 0
	module = new /obj/item/robot_module(src)
	module.rebuild_modules()
	update_icons()
	. = ..()

	//If this body is meant to be a borg controlled by the AI player

	//MMI stuff. Held togheter by magic. ~Miauw
	if(!posibrain || !posibrain.brainmob)
		posibrain = new (src)
		posibrain.icon_state = "posibrain-occupied"
		posibrain.name = "Android Interface: [real_name]"
		posibrain.brainmob = new(posibrain)
		posibrain.brainmob.name = src.real_name
		posibrain.brainmob.real_name = src.real_name
		posibrain.brainmob.container = posibrain

	updatename()


	playsound(loc, 'sound/voice/liveagain.ogg', 75, 1)
	aicamera = new/obj/item/camera/siliconcam/robot_camera(src)
	toner = tonermax

//If there's an MMI in the robot, have it ejected when the mob goes away. --NEO
/mob/living/silicon/android/Destroy()
	if(posibrain && mind)//Safety for when a cyborg gets dust()ed. Or there is no MMI inside.
		var/turf/T = get_turf(loc)//To hopefully prevent run time errors.
		if(T)
			posibrain.forceMove(T)
		if(posibrain.brainmob)
			if(posibrain.brainmob.stat == DEAD)
				posibrain.brainmob.stat = CONSCIOUS
				GLOB.dead_mob_list -= posibrain.brainmob
				GLOB.alive_mob_list += posibrain.brainmob
			mind.transfer_to(posibrain.brainmob)
			posibrain.update_icon()
		else
			to_chat(src, "<span class='boldannounce'>Oops! Something went very wrong, your interface was unable to receive your mind. You have been ghosted. Please make a bug report so we can fix this bug.</span>")
			ghostize()
			stack_trace("Android posibrain lacked a brainmob")
		posibrain = null
	qdel(wires)
	qdel(module)
	qdel(eye_lights)
	wires = null
	module = null
	eye_lights = null
	cell = null
	return ..()

/mob/living/silicon/android/can_interact_with(atom/A)
	. = ..()
	return . || in_view_range(src, A)
/* TODO: fix
/mob/living/silicon/android/proc/pick_module()
	if(module.type != /obj/item/robot_module)
		return

	if(wires.is_cut(WIRE_RESET_MODULE))
		to_chat(src,"<span class='userdanger'>ERROR: Module installer reply timeout. Please check internal connections.</span>")
		return

	var/list/modulelist = list("Standard" = /obj/item/robot_module/standard, \
	"Engineering" = /obj/item/robot_module/engineering, \
	"Medical" = /obj/item/robot_module/medical, \
	"Miner" = /obj/item/robot_module/miner, \
	"Janitor" = /obj/item/robot_module/janitor, \
	"Service" = /obj/item/robot_module/butler)
	if(!CONFIG_GET(flag/disable_peaceborg))
		modulelist["Peacekeeper"] = /obj/item/robot_module/peacekeeper
	if(!CONFIG_GET(flag/disable_secborg))
		modulelist["Security"] = /obj/item/robot_module/security

	var/input_module = input("Please, select a module!", "Robot", null, null) as null|anything in modulelist
	if(!input_module || module.type != /obj/item/robot_module)
		return

	module.transform_to(modulelist[input_module])

*/
/mob/living/silicon/android/proc/updatename()
	var/changed_name = ""
	if(custom_name)
		changed_name = custom_name
	if(changed_name == "" && client)
		changed_name = client.prefs.custom_names["cyborg"]
	if(!changed_name)
		changed_name = get_standard_name()

	real_name = changed_name
	name = real_name
	if(!QDELETED(builtInCamera))
		builtInCamera.c_tag = real_name	//update the camera name too

/mob/living/silicon/android/proc/get_standard_name()
	return "[(designation ? "[designation] " : "")][posibrain.braintype]-[ident]"

//TODO: add more
/mob/living/silicon/android/Stat()
	..()
	if(statpanel("Status"))
		if(cell)
			stat("Charge Left:", "[cell.charge]/[cell.maxcharge]")
		else
			stat(null, text("No Cell Inserted!"))

		if(module)
			for(var/datum/robot_energy_storage/st in module.storages)
				stat("[st.name]:", "[st.energy]/[st.max_energy]")

/mob/living/silicon/android/restrained(ignore_grab)
	. = 0


/mob/living/silicon/android/can_interact_with(atom/A)
	return !low_power_mode && ISINRANGE(A.x, x - interaction_range, x + interaction_range) && ISINRANGE(A.y, y - interaction_range, y + interaction_range)

/mob/living/silicon/android/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/weldingtool) && (user.a_intent != INTENT_HARM || user == src))
		user.changeNext_move(CLICK_CD_MELEE)
		if (!getBruteLoss())
			to_chat(user, "<span class='warning'>[src] is already in good condition!</span>")
			return
		if (!W.tool_start_check(user, amount=0)) //The welder has 1u of fuel consumed by it's afterattack, so we don't need to worry about taking any away.
			return
		if(src == user)
			to_chat(user, "<span class='notice'>You start fixing yourself...</span>")
			if(!W.use_tool(src, user, 50))
				return

		adjustBruteLoss(-30)
		updatehealth()
		add_fingerprint(user)
		visible_message("<span class='notice'>[user] has fixed some of the dents on [src].</span>")
		return

	else if(istype(W, /obj/item/stack/cable_coil) && wiresexposed)
		user.changeNext_move(CLICK_CD_MELEE)
		var/obj/item/stack/cable_coil/coil = W
		if (getFireLoss() > 0 || getToxLoss() > 0)
			if(src == user)
				to_chat(user, "<span class='notice'>You start fixing yourself...</span>")
				if(!do_after(user, 50, target = src))
					return
			if (coil.use(1))
				adjustFireLoss(-30)
				adjustToxLoss(-30)
				updatehealth()
				user.visible_message("[user] has fixed some of the burnt wires on [src].", "<span class='notice'>You fix some of the burnt wires on [src].</span>")
			else
				to_chat(user, "<span class='warning'>You need more cable to repair [src]!</span>")
		else
			to_chat(user, "The wires seem fine, there's no need to fix them.")

	else if(istype(W, /obj/item/crowbar))	// crowbar means open or close the cover
		if(opened)
			to_chat(user, "<span class='notice'>You close the cover.</span>")
			opened = 0
			update_icons()
		else
			if(locked)
				to_chat(user, "<span class='warning'>The cover is locked and cannot be opened!</span>")
			else
				to_chat(user, "<span class='notice'>You open the cover.</span>")
				opened = 1
				update_icons()

	else if(istype(W, /obj/item/stock_parts/cell) && opened)	// trying to put a cell inside
		if(wiresexposed)
			to_chat(user, "<span class='warning'>Close the cover first!</span>")
		else if(cell)
			to_chat(user, "<span class='warning'>There is a power cell already installed!</span>")
		else
			if(!user.transferItemToLoc(W, src))
				return
			cell = W
			to_chat(user, "<span class='notice'>You insert the power cell.</span>")
		update_icons()

	else if(is_wire_tool(W))
		if (wiresexposed)
			wires.interact(user)
		else
			to_chat(user, "<span class='warning'>You can't reach the wiring!</span>")

	else if(istype(W, /obj/item/screwdriver) && opened && !cell)	// haxing
		wiresexposed = !wiresexposed
		to_chat(user, "The wires have been [wiresexposed ? "exposed" : "unexposed"]")
		update_icons()

	else if(istype(W, /obj/item/screwdriver) && opened && cell)	// radio
		if(radio)
			radio.attackby(W,user)//Push it to the radio to let it handle everything
		else
			to_chat(user, "<span class='warning'>Unable to locate a radio!</span>")
		update_icons()
	//FIX!
	else if(istype(W, /obj/item/wrench) && opened && !cell) //Deconstruction. The flashes break from the fall, to prevent this from being a ghetto reset module.
		if(!lockcharge)
			to_chat(user, "<span class='boldannounce'>[src]'s bolts spark! Maybe you should lock them down first!</span>")
			spark_system.start()
			return
		else
			to_chat(user, "<span class='notice'>You start to unfasten [src]'s securing bolts...</span>")
			if(W.use_tool(src, user, 50, volume=50) && !cell)
				user.visible_message("[user] deconstructs [src]!", "<span class='notice'>You unfasten the securing bolts, and [src] falls to pieces!</span>")
				deconstruct()

	else if(istype(W, /obj/item/encryptionkey/) && opened)
		if(radio)//sanityyyyyy
			radio.attackby(W,user)//GTFO, you have your own procs
		else
			to_chat(user, "<span class='warning'>Unable to locate a radio!</span>")

	else if (istype(W, /obj/item/card/id)||istype(W, /obj/item/pda))			// trying to unlock the interface with an ID card
		if(emagged)//still allow them to open the cover
			to_chat(user, "<span class='notice'>The interface seems slightly damaged.</span>")
		if(opened)
			to_chat(user, "<span class='warning'>You must close the cover to swipe an ID card!</span>")
		else
			if(allowed(usr))
				locked = !locked
				to_chat(user, "<span class='notice'>You [ locked ? "lock" : "unlock"] [src]'s cover.</span>")
				update_icons()
			else
				to_chat(user, "<span class='danger'>Access denied.</span>")
	//FIX UPGRADES
	/*
	else if(istype(W, /obj/item/borg/upgrade/))
		var/obj/item/borg/upgrade/U = W
		if(!opened)
			to_chat(user, "<span class='warning'>You must access the borg's internals!</span>")
		else if(!src.module && U.require_module)
			to_chat(user, "<span class='warning'>The borg must choose a module before it can be upgraded!</span>")
		else if(U.locked)
			to_chat(user, "<span class='warning'>The upgrade is locked and cannot be used yet!</span>")
		else
			if(!user.temporarilyRemoveItemFromInventory(U))
				return
			if(U.action(src))
				to_chat(user, "<span class='notice'>You apply the upgrade to [src].</span>")
				if(U.one_use)
					qdel(U)
				else
					U.forceMove(src)
					upgrades += U
			else
				to_chat(user, "<span class='danger'>Upgrade error.</span>")
				U.forceMove(drop_location())
	*/
	else if(istype(W, /obj/item/toner))
		if(toner >= tonermax)
			to_chat(user, "<span class='warning'>The toner level of [src] is at its highest level possible!</span>")
		else
			if(!user.temporarilyRemoveItemFromInventory(W))
				return
			toner = tonermax
			qdel(W)
			to_chat(user, "<span class='notice'>You fill the toner level of [src] to its max capacity.</span>")

	else if(istype(W, /obj/item/flashlight))
		if(!opened)
			to_chat(user, "<span class='warning'>You need to open the panel to repair the eye lights!</span>")
		if(lamp_cooldown <= world.time)
			to_chat(user, "<span class='warning'>The eye lights are already functional!</span>")
		else
			if(!user.temporarilyRemoveItemFromInventory(W))
				to_chat(user, "<span class='warning'>[W] seems to be stuck to your hand. You'll have to find a different light.</span>")
				return
			lamp_cooldown = 0
			qdel(W)
			to_chat(user, "<span class='notice'>You replace the eye lights.</span>")
	else
		return ..()


/mob/living/silicon/android/proc/allowed(mob/M)
	//check if it doesn't require any access at all
	if(check_access(null))
		return 1
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		//if they are holding or wearing a card that has access, that works
		if(check_access(H.get_active_held_item()) || check_access(H.wear_id))
			return 1
	else if(ismonkey(M))
		var/mob/living/carbon/monkey/george = M
		//they can only hold things :(
		if(isitem(george.get_active_held_item()))
			return check_access(george.get_active_held_item())
	return 0
//FIX
/mob/living/silicon/android/proc/check_access(obj/item/card/id/I)
	if(!istype(req_access, /list)) //something's very wrong
		return 1

	var/list/L = req_access
	if(!L.len) //no requirements
		return 1

	if(!istype(I, /obj/item/card/id) && isitem(I))
		I = I.GetID()

	if(!I || !I.access) //not ID or no access
		return 0
	for(var/req in req_access)
		if(!(req in I.access)) //doesn't have this access
			return 0
	return 1

/mob/living/silicon/android/regenerate_icons()
	return update_icons()

//TODO: fix when we have sprites
/mob/living/silicon/android/update_icons()
	cut_overlays()
	icon_state = module.cyborg_base_icon
	if(stat != DEAD && !(IsUnconscious() || IsStun() || IsKnockdown() || low_power_mode)) //Not dead, not stunned.
		if(!eye_lights)
			eye_lights = new()
		if(lamp_intensity > 2)
			eye_lights.icon_state = "[module.special_light_key ? "[module.special_light_key]":"[module.cyborg_base_icon]"]_l"
		else
			eye_lights.icon_state = "[module.special_light_key ? "[module.special_light_key]":"[module.cyborg_base_icon]"]_e[is_servant_of_ratvar(src) ? "_r" : ""]"
		eye_lights.icon = icon
		add_overlay(eye_lights)

	if(opened)
		if(wiresexposed)
			add_overlay("ov-opencover +w")
		else if(cell)
			add_overlay("ov-opencover +c")
		else
			add_overlay("ov-opencover -c")
	if(hat)
		var/mutable_appearance/head_overlay = hat.build_worn_icon(state = hat.icon_state, default_layer = 20, default_icon_file = 'icons/mob/head.dmi')
		head_overlay.pixel_y += hat_offset
		add_overlay(head_overlay)
	update_fire()

/mob/living/silicon/android/proc/self_destruct()
	if(emagged)
		if(posibrain)
			qdel(posibrain)
		explosion(src.loc,1,2,4,flame_range = 2)
	else
		explosion(src.loc,-1,0,2)
	gib()

//Probably not needed
/mob/living/silicon/android/proc/UnlinkSelf()
	lawupdate = 0
	lockcharge = 0
	canmove = 1
	scrambledcodes = 1
	//Disconnect it's camera so it's not so easily tracked.
	if(!QDELETED(builtInCamera))
		QDEL_NULL(builtInCamera)
		// I'm trying to get the Cyborg to not be listed in the camera list
		// Instead of being listed as "deactivated". The downside is that I'm going
		// to have to check if every camera is null or not before doing anything, to prevent runtime errors.
		// I could change the network to null but I don't know what would happen, and it seems too hacky for me.

/mob/living/silicon/android/mode()
	set name = "Activate Held Object"
	set category = "IC"
	set src = usr

	if(incapacitated())
		return
	var/obj/item/W = get_active_held_item()
	if(W)
		W.attack_self(src)

/* We dont lock down.
/mob/living/silicon/android/proc/SetLockdown(state = 1)
	// They stay locked down if their wire is cut.
	if(wires.is_cut(WIRE_LOCKDOWN))
		state = 1
	if(state)
		throw_alert("locked", /obj/screen/alert/locked)
	else
		clear_alert("locked")
	lockcharge = state
	update_canmove()
*/

/mob/living/silicon/android/proc/SetEmagged(new_state)
	emagged = new_state
	module.rebuild_modules()
	update_icons()
	if(emagged)
		throw_alert("hacked", /obj/screen/alert/hacked)
	else
		clear_alert("hacked")
/*
/mob/living/silicon/android/verb/outputlaws()
	set category = "Robot Commands"
	set name = "State Laws"

	if(usr.stat == DEAD)
		return //won't work if dead
	checklaws()

 We dont have "laws" per say, TODO: fix if needed
/mob/living/silicon/android/verb/set_automatic_say_channel() //Borg version of setting the radio for autosay messages.
	set name = "Set Auto Announce Mode"
	set desc = "Modify the default radio setting for stating your laws."
	set category = "Robot Commands"

	if(usr.stat == DEAD)
		return //won't work if dead
	set_autosay()
*/
/mob/living/silicon/android/proc/control_eye_lights()
	if(stat || lamp_cooldown > world.time || low_power_mode)
		to_chat(src, "<span class='danger'>This function is currently offline.</span>")
		return

//Some sort of magical "modulo" thing which somehow increments lamp power by 2, until it hits the max and resets to 0.
	lamp_intensity = (lamp_intensity+2) % (lamp_max+2)
	to_chat(src, "[lamp_intensity ? "Eye lights power set to Level [lamp_intensity/2]" : "Eye lights disabled."]")
	update_eye_lights()

/mob/living/silicon/android/proc/update_eye_lights(var/turn_off = 0, var/cooldown = 100)
	set_light(0)

	if(lamp_intensity && (turn_off || stat || low_power_mode))
		to_chat(src, "<span class='danger'>Your eye lights have been deactivated.</span>")
		lamp_intensity = 0
		lamp_cooldown = world.time + cooldown
	else
		set_light(lamp_intensity)

	if(lamp_button)
		lamp_button.icon_state = "lamp[lamp_intensity]"

	update_icons()

//TODO: fix this up for androids
/mob/living/silicon/android/proc/deconstruct()
	var/turf/T = get_turf(src)
	if (robot_suit)
		robot_suit.forceMove(T)
		robot_suit.l_leg.forceMove(T)
		robot_suit.l_leg = null
		robot_suit.r_leg.forceMove(T)
		robot_suit.r_leg = null
		new /obj/item/stack/cable_coil(T, robot_suit.chest.wired)
		robot_suit.chest.forceMove(T)
		robot_suit.chest.wired = 0
		robot_suit.chest = null
		robot_suit.l_arm.forceMove(T)
		robot_suit.l_arm = null
		robot_suit.r_arm.forceMove(T)
		robot_suit.r_arm = null
		robot_suit.head.forceMove(T)
		robot_suit.head.flash1.forceMove(T)
		robot_suit.head.flash1.burn_out()
		robot_suit.head.flash1 = null
		robot_suit.head.flash2.forceMove(T)
		robot_suit.head.flash2.burn_out()
		robot_suit.head.flash2 = null
		robot_suit.head = null
		robot_suit.updateicon()
	else
		new /obj/item/robot_suit(T)
		new /obj/item/bodypart/l_leg/robot(T)
		new /obj/item/bodypart/r_leg/robot(T)
		new /obj/item/stack/cable_coil(T, 1)
		new /obj/item/bodypart/chest/robot(T)
		new /obj/item/bodypart/l_arm/robot(T)
		new /obj/item/bodypart/r_arm/robot(T)
		new /obj/item/bodypart/head/robot(T)
		var/b
		for(b=0, b!=2, b++)
			var/obj/item/assembly/flash/handheld/F = new /obj/item/assembly/flash/handheld(T)
			F.burn_out()
	if (cell) //Sanity check.
		cell.forceMove(T)
		cell = null
	qdel(src)

/mob/living/silicon/android/modules
	var/set_module = null

/mob/living/silicon/android/modules/Initialize()
	. = ..()
	module.transform_to(set_module)

/mob/living/silicon/android/modules/standard
	set_module = /obj/item/robot_module/standard

/mob/living/silicon/android/modules/medical
	set_module = /obj/item/robot_module/medical

/mob/living/silicon/android/modules/engineering
	set_module = /obj/item/robot_module/engineering

/mob/living/silicon/android/modules/security
	set_module = /obj/item/robot_module/security

/mob/living/silicon/android/modules/clown
	set_module = /obj/item/robot_module/clown

/mob/living/silicon/android/modules/peacekeeper
	set_module = /obj/item/robot_module/peacekeeper

/mob/living/silicon/android/modules/miner
	set_module = /obj/item/robot_module/miner

/mob/living/silicon/android/modules/janitor
	set_module = /obj/item/robot_module/janitor


/mob/living/silicon/android/canUseTopic(atom/movable/M, be_close=FALSE, no_dextery=FALSE)
	if(stat || lockcharge || low_power_mode)
		to_chat(src, "<span class='warning'>You can't do that right now!</span>")
		return FALSE
	if(be_close && !in_range(M, src))
		to_chat(src, "<span class='warning'>You are too far away!</span>")
		return FALSE
	return TRUE
/* TODO: work this out
/mob/living/silicon/android/updatehealth()
	..()
	if(health < maxHealth*0.5) //Gradual break down of modules as more damage is sustained
		if(uneq_module(held_items[3]))
			playsound(loc, 'sound/machines/warning-buzzer.ogg', 50, 1, 1)
			visible_message("<span class='warning'>[src] sounds an alarm! \"SYSTEM ERROR: Module 3 OFFLINE.\"</span>", "<span class='userdanger'>SYSTEM ERROR: Module 3 OFFLINE.</span>")
		if(health < 0)
			if(uneq_module(held_items[2]))
				visible_message("<span class='warning'>[src] sounds an alarm! \"SYSTEM ERROR: Module 2 OFFLINE.\"</span>", "<span class='userdanger'>SYSTEM ERROR: Module 2 OFFLINE.</span>")
				playsound(loc, 'sound/machines/warning-buzzer.ogg', 60, 1, 1)
			if(health < -maxHealth*0.5)
				if(uneq_module(held_items[1]))
					visible_message("<span class='warning'>[src] sounds an alarm! \"CRITICAL ERROR: All modules OFFLINE.\"</span>", "<span class='userdanger'>CRITICAL ERROR: All modules OFFLINE.</span>")
					playsound(loc, 'sound/machines/warning-buzzer.ogg', 75, 1, 1)
*/

/mob/living/silicon/android/update_sight()
	if(!client)
		return
	if(stat == DEAD)
		sight = (SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = 8
		see_invisible = SEE_INVISIBLE_OBSERVER
		return

	see_invisible = initial(see_invisible)
	see_in_dark = initial(see_in_dark)
	sight = initial(sight)
	lighting_alpha = LIGHTING_PLANE_ALPHA_VISIBLE

	if(client.eye != src)
		var/atom/A = client.eye
		if(A.update_remote_sight(src)) //returns 1 if we override all other sight updates.
			return

	if(sight_mode & BORGMESON)
		sight |= SEE_TURFS
		lighting_alpha = LIGHTING_PLANE_ALPHA_INVISIBLE
		see_in_dark = 1

	if(sight_mode & BORGMATERIAL)
		sight |= SEE_OBJS
		lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
		see_in_dark = 1

	if(sight_mode & BORGXRAY)
		sight |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_invisible = SEE_INVISIBLE_LIVING
		see_in_dark = 8

	if(sight_mode & BORGTHERM)
		sight |= SEE_MOBS
		see_invisible = min(see_invisible, SEE_INVISIBLE_LIVING)
		see_in_dark = 8

	if(see_override)
		see_invisible = see_override
	sync_lighting_plane_alpha()

/mob/living/silicon/android/update_stat()
	if(status_flags & GODMODE)
		return
	if(stat != DEAD)
		if(health <= -maxHealth) //die only once
			death()
			return
		if(IsUnconscious() || IsStun() || IsKnockdown() || getOxyLoss() > maxHealth*0.5)
			if(stat == CONSCIOUS)
				stat = UNCONSCIOUS
				blind_eyes(1)
				update_canmove()
				update_eye_lights()
		else
			if(stat == UNCONSCIOUS)
				stat = CONSCIOUS
				adjust_blindness(-1)
				update_canmove()
				update_eye_lights()
	diag_hud_set_status()
	diag_hud_set_health()
	update_health_hud()

/mob/living/silicon/android/revive(full_heal = 0, admin_revive = 0)
	if(..()) //successfully ressuscitated from death
		if(!QDELETED(builtInCamera) && !wires.is_cut(WIRE_CAMERA))
			builtInCamera.toggle_cam(src,0)
		update_eye_lights()
		if(admin_revive)
			locked = TRUE
		. = 1

/mob/living/silicon/android/fully_replace_character_name(oldname, newname)
	..()
	if(!QDELETED(builtInCamera))
		builtInCamera.c_tag = real_name
	custom_name = newname

/*
/mob/living/silicon/android/proc/ResetModule()
	//TODO: Fix this
	uneq_all()
	shown_robot_modules = FALSE
	if(hud_used)
		hud_used.update_robot_modules_display()

	if (hasExpanded)
		resize = 0.5
		hasExpanded = FALSE
		update_transform()
	module.transform_to(/obj/item/robot_module)

	// Remove upgrades.
	for(var/obj/item/I in upgrades)
		I.forceMove(get_turf(src))

	upgrades.Cut()

	speed = 0
	ionpulse = FALSE
	revert_shell()

	return 1
*/

/mob/living/silicon/android/proc/has_module()
	if(!module || module.type == /obj/item/robot_module)
		. = FALSE
	else
		. = TRUE

/mob/living/silicon/android/proc/update_module_innate()
	designation = module.name
	if(hands)
		hands.icon_state = module.moduleselect_icon
	if(module.can_be_pushed)
		status_flags |= CANPUSH
	else
		status_flags &= ~CANPUSH

	if(module.clean_on_move)
		AddComponent(/datum/component/cleaning)
	else
		qdel(GetComponent(/datum/component/cleaning))

	hat_offset = module.hat_offset

	magpulse = module.magpulsing
	updatename()

/mob/living/silicon/android/MouseDrop_T(mob/living/M, mob/living/user)
	. = ..()
	if(!(M in buckled_mobs) && isliving(M))
		buckle_mob(M)


//Human stuff, androids are much like them