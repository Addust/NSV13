/mob/living/silicon/robot/modules/borgi
	set_module = /obj/item/robot_module/borgi

/obj/item/robot_module
	name = "Default"
	icon = 'icons/obj/module.dmi'
	icon_state = "std_mod"
	w_class = WEIGHT_CLASS_GIGANTIC
	item_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	flags_1 = CONDUCT_1

	var/list/basic_modules = list() //a list of paths, converted to a list of instances on New()
	var/list/emag_modules = list() //ditto
	var/list/ratvar_modules = list() //ditto
	var/list/modules = list() //holds all the usable modules
	var/list/added_modules = list() //modules not inherient to the robot module, are kept when the module changes
	var/list/storages = list()

	var/cyborg_base_icon = "robot" //produces the icon for the borg and, if no special_light_key is set, the lights
	var/special_light_key //if we want specific lights, use this instead of copying lights in the dmi

	var/moduleselect_icon = "nomod"

	var/can_be_pushed = TRUE
	var/magpulsing = FALSE
	var/clean_on_move = FALSE

	var/did_feedback = FALSE

	var/hat_offset = -3

	var/list/ride_offset_x = list("north" = 0, "south" = 0, "east" = -6, "west" = 6)
	var/list/ride_offset_y = list("north" = 4, "south" = 4, "east" = 3, "west" = 3)
	var/ride_allow_incapacitated = TRUE
	var/allow_riding = TRUE
	var/canDispose = FALSE // Whether the borg can stuff itself into disposal
	//NSV13 - Borg Skin Framework - Start
	var/list/borg_skins
	/// Traits unique to this model, i.e. having a unique dead sprite
	var/list/module_features = list()
	///Host of this module
	var/mob/living/silicon/robot/robot
	//NSV13 - Borg Skin Framework - Stop

/obj/item/robot_module/Initialize(mapload)
	. = ..()
	for(var/i in basic_modules)
		var/obj/item/I = new i(src)
		basic_modules += I
		basic_modules -= i
	for(var/i in emag_modules)
		var/obj/item/I = new i(src)
		emag_modules += I
		emag_modules -= i
	for(var/i in ratvar_modules)
		var/obj/item/I = new i(src)
		ratvar_modules += I
		ratvar_modules -= i

/obj/item/robot_module/Destroy()
	basic_modules.Cut()
	emag_modules.Cut()
	ratvar_modules.Cut()
	modules.Cut()
	added_modules.Cut()
	storages.Cut()
	return ..()

/obj/item/robot_module/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_CONTENTS)
		return
	for(var/obj/O in modules)
		O.emp_act(severity)
	..()

/obj/item/robot_module/proc/get_usable_modules()
	. = modules.Copy()

/obj/item/robot_module/proc/get_inactive_modules()
	. = list()
	var/mob/living/silicon/robot/R = loc
	for(var/m in get_usable_modules())
		if(!(m in R.held_items))
			. += m

/obj/item/robot_module/proc/get_or_create_estorage(var/storage_type)
	for(var/datum/robot_energy_storage/S in storages)
		if(istype(S, storage_type))
			return S

	return new storage_type(src)

/obj/item/robot_module/proc/add_module(obj/item/I, nonstandard, requires_rebuild)
	if(istype(I, /obj/item/stack))
		var/obj/item/stack/S = I

		if(is_type_in_list(S, list(/obj/item/stack/sheet/iron, /obj/item/stack/rods, /obj/item/stack/tile/plasteel, /obj/item/stack/tile/light)))
			if(S.materials[/datum/material/iron])
				S.cost = S.materials[/datum/material/iron] * 0.25
			S.source = get_or_create_estorage(/datum/robot_energy_storage/metal)

		else if(istype(S, /obj/item/stack/sheet/glass))
			S.cost = 500
			S.source = get_or_create_estorage(/datum/robot_energy_storage/glass)

		else if(istype(S, /obj/item/stack/sheet/rglass/cyborg))
			var/obj/item/stack/sheet/rglass/cyborg/G = S
			G.source = get_or_create_estorage(/datum/robot_energy_storage/metal)
			G.glasource = get_or_create_estorage(/datum/robot_energy_storage/glass)

		else if(istype(S, /obj/item/stack/tile/brass))
			S.cost = 500
			S.source = get_or_create_estorage(/datum/robot_energy_storage/brass)

		else if(istype(S, /obj/item/stack/medical))
			S.cost = 250
			S.source = get_or_create_estorage(/datum/robot_energy_storage/medical)

		else if(istype(S, /obj/item/stack/cable_coil))
			S.cost = 1
			S.source = get_or_create_estorage(/datum/robot_energy_storage/wire)

		else if(istype(S, /obj/item/stack/marker_beacon))
			S.cost = 1
			S.source = get_or_create_estorage(/datum/robot_energy_storage/beacon)

		//NSV13 - Cargo Borgs - Start
		else if(istype(S, /obj/item/stack/package_wrap/cyborg))
			S.cost = 1
			S.source = get_or_create_estorage(/datum/robot_energy_storage/package_wrap)

		else if(istype(S, /obj/item/stack/wrapping_paper/cyborg))
			S.cost = 1
			S.source = get_or_create_estorage(/datum/robot_energy_storage/wrapping_paper)
		//NSV13 - Cargo Borgs - Stop

		if(S?.source)
			S.materials = list()
			S.is_cyborg = 1

	if(I.loc != src)
		I.forceMove(src)
	modules += I
	ADD_TRAIT(I, TRAIT_NODROP, CYBORG_ITEM_TRAIT)
	I.mouse_opacity = MOUSE_OPACITY_OPAQUE
	if(nonstandard)
		added_modules += I
	if(requires_rebuild)
		rebuild_modules()
	return I

/obj/item/robot_module/proc/remove_module(obj/item/I, delete_after)
	basic_modules -= I
	modules -= I
	emag_modules -= I
	ratvar_modules -= I
	added_modules -= I
	rebuild_modules()
	if(delete_after)
		qdel(I)

/obj/item/robot_module/proc/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	for(var/datum/robot_energy_storage/st in storages)
		st.energy = min(st.max_energy, st.energy + coeff * st.recharge_rate)

	for(var/obj/item/I in get_usable_modules())
		if(istype(I, /obj/item/assembly/flash))
			var/obj/item/assembly/flash/F = I
			F.bulb.charges_left = INFINITY
			F.burnt_out = FALSE
			F.update_icon()
		else if(istype(I, /obj/item/melee/baton))
			var/obj/item/melee/baton/B = I
			if(B.cell)
				B.cell.charge = B.cell.maxcharge
		else if(istype(I, /obj/item/gun/energy))
			var/obj/item/gun/energy/EG = I
			if(!EG.chambered)
				EG.recharge_newshot() //try to reload a new shot.
		///NSV13 - Cargo Borgs - Start
		else if(istype(I, /obj/item/hand_labeler/cyborg))
			var/obj/item/hand_labeler/cyborg/labeler = I
			labeler.labels_left = 30
		///NSV13 - Cargo Borgs - Stop

	R.toner = R.tonermax

/obj/item/robot_module/proc/rebuild_modules() //builds the usable module list from the modules we have
	var/mob/living/silicon/robot/R = loc
	var/held_modules = R.held_items.Copy()
	R.uneq_all()
	modules = list()
	for(var/obj/item/I in basic_modules)
		add_module(I, FALSE, FALSE)
	if(R.emagged)
		for(var/obj/item/I in emag_modules)
			add_module(I, FALSE, FALSE)
	if(is_servant_of_ratvar(R) && !R.ratvar)	//It just works :^)
		R.SetRatvar(TRUE, FALSE)
	if(R.ratvar)
		for(var/obj/item/I in ratvar_modules)
			add_module(I, FALSE, FALSE)
	for(var/obj/item/I in added_modules)
		add_module(I, FALSE, FALSE)
	for(var/i in held_modules)
		if(i)
			R.activate_module(i)
	if(R.hud_used)
		R.hud_used.update_robot_modules_display()

/obj/item/robot_module/proc/transform_to(new_module_type, forced = FALSE) //NSV13 - Borg Skin Framework
	var/mob/living/silicon/robot/R = loc
	R.icon = 'icons/mob/robots.dmi' //NSV13 - Borg Skin Framework - Should prevent the invisibility glitch
	var/obj/item/robot_module/RM = new new_module_type(R)
	RM.robot = R //NSV13 - Cargo Borg
	if(!RM.be_transformed_to(src, forced)) //NSV13 - Borg Skin Framework
		qdel(RM)
		return
	R.module = RM
	R.update_module_innate()
	RM.rebuild_modules()
	R.set_modularInterface_theme()
	INVOKE_ASYNC(RM, PROC_REF(do_transform_animation))
	qdel(src)
	return RM

//NSV13 - Borg Skin Framework - Start
/obj/item/robot_module/proc/be_transformed_to(obj/item/robot_module/old_module, forced = FALSE)
	if(islist(borg_skins) && !forced)
		var/mob/living/silicon/robot/cyborg = loc
		var/list/reskin_icons = list()
		for(var/skin in borg_skins)
			var/list/details = borg_skins[skin]
			reskin_icons[skin] = image(icon = details[SKIN_ICON] || 'icons/mob/robots.dmi', icon_state = details[SKIN_ICON_STATE])
		var/borg_skin = show_radial_menu(cyborg, cyborg, reskin_icons, custom_check = CALLBACK(src, PROC_REF(check_menu), cyborg, old_module), radius = 38, require_near = TRUE)
		if(!borg_skin)
			return FALSE
		var/list/details = borg_skins[borg_skin]
		if(!isnull(details[SKIN_ICON_STATE]))
			cyborg_base_icon = details[SKIN_ICON_STATE]
		if(!isnull(details[SKIN_ICON]))
			cyborg.icon = details[SKIN_ICON]
		if(!isnull(details[SKIN_LIGHT_KEY]))
			special_light_key = details[SKIN_LIGHT_KEY]
		if(!isnull(details[SKIN_HAT_OFFSET]))
			hat_offset = details[SKIN_HAT_OFFSET]
		if(!isnull(details[SKIN_FEATURES]))
			module_features += details[SKIN_FEATURES]
	//NSV13 - Borg Skin Framework - Stop
	for(var/i in old_module.added_modules)
		added_modules += i
		old_module.added_modules -= i
	did_feedback = old_module.did_feedback
	return TRUE

/obj/item/robot_module/proc/do_transform_animation()
	var/mob/living/silicon/robot/R = loc
	if(R.hat)
		R.hat.forceMove(get_turf(R))
		R.hat = null
	R.cut_overlays()
	R.setDir(SOUTH)
	do_transform_delay()

/obj/item/robot_module/proc/do_transform_delay()
	var/mob/living/silicon/robot/R = loc
	var/prev_lockcharge = R.lockcharge
	sleep(1)
	flick("[cyborg_base_icon]_transform", R)
	R.notransform = TRUE
	R.SetLockdown(TRUE)
	R.anchored = TRUE
	R.logevent("Chassis configuration has been set to [name].")
	sleep(1)
	for(var/i in 1 to 4)
		playsound(R, pick('sound/items/drill_use.ogg', 'sound/items/jaws_cut.ogg', 'sound/items/jaws_pry.ogg', 'sound/items/welder.ogg', 'sound/items/ratchet.ogg'), 80, 1, -1)
		sleep(7)
	if(!prev_lockcharge)
		R.SetLockdown(FALSE)
	R.setDir(SOUTH)
	R.anchored = FALSE
	R.notransform = FALSE
	R.update_icons()
	R.notify_ai(NEW_MODULE)
	if(R.hud_used)
		R.hud_used.update_robot_modules_display()
	SSblackbox.record_feedback("tally", "cyborg_modules", 1, R.module)

/**
 * Checks if we are allowed to interact with a radial menu
 *
 * Arguments:
 * * user The cyborg mob interacting with the menu
 * * old_module The old cyborg's module
 */
/obj/item/robot_module/proc/check_menu(mob/living/silicon/robot/user, obj/item/robot_module/old_module)
	if(!istype(user))
		return FALSE
	if(user.incapacitated())
		return FALSE
	if(user.module != old_module)
		return FALSE
	return TRUE

/obj/item/robot_module/standard
	name = "Standard"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/borghypo/epi,
		/obj/item/healthanalyzer,
		/obj/item/borg/charger,
		/obj/item/weldingtool/largetank/cyborg,
		/obj/item/wrench/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/stack/sheet/iron/cyborg,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/extinguisher,
		/obj/item/pickaxe,
		/obj/item/t_scanner/adv_mining_scanner,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/soap/nanotrasen,
		/obj/item/borg/cyborghug,
		/obj/item/instrument/piano_synth)
	emag_modules = list(/obj/item/melee/transforming/energy/sword/cyborg)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/abstraction_crystal,
		/obj/item/clockwork/replica_fabricator,
		/obj/item/stack/tile/brass/cyborg,
		/obj/item/clockwork/weapon/brass_spear)
	moduleselect_icon = "standard"
	hat_offset = -3

/obj/item/robot_module/medical
	name = "Medical"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/healthanalyzer,
		/obj/item/borg/charger,
		/obj/item/reagent_containers/borghypo/medical,
		/obj/item/borg/apparatus/beaker,
		/obj/item/reagent_containers/dropper,
		/obj/item/reagent_containers/syringe,
		/obj/item/surgical_drapes,
		/obj/item/retractor,
		/obj/item/hemostat,
		/obj/item/cautery,
		/obj/item/surgicaldrill,
		/obj/item/scalpel,
		/obj/item/circular_saw,
		/obj/item/blood_filter,
		/obj/item/extinguisher/mini,
		/obj/item/roller/robo,
		/obj/item/borg/cyborghug/medical,
		/obj/item/stack/medical/gauze/cyborg,
		/obj/item/organ_storage,
		/obj/item/borg/lollipop) ///NSV13 - Changed borghypo to borghypo/medical
	emag_modules = list(/obj/item/reagent_containers/borghypo/medical/hacked) ///NSV13 - Borg Hypospray Update
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/sentinels_compromise,
		/obj/item/clock_module/prosperity_prism,
		/obj/item/clock_module/vanguard)
	cyborg_base_icon = "medical"
	moduleselect_icon = "medical"
	can_be_pushed = FALSE
	hat_offset = 3

/obj/item/robot_module/engineering
	name = "Engineering"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/sight/meson,
		/obj/item/borg/charger,
		/obj/item/construction/rcd/borg,
		/obj/item/pipe_dispenser,
		/obj/item/extinguisher,
		/obj/item/weldingtool/largetank/cyborg,
		/obj/item/screwdriver/cyborg,
		/obj/item/wrench/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/wirecutters/cyborg,
		/obj/item/multitool/cyborg,
		/obj/item/t_scanner,
		/obj/item/analyzer,
		/obj/item/geiger_counter/cyborg,
		/obj/item/assembly/signaler/cyborg,
		/obj/item/areaeditor/blueprints/cyborg,
		/obj/item/electroadaptive_pseudocircuit,
		/obj/item/stack/sheet/iron/cyborg,
		/obj/item/stack/sheet/glass/cyborg,
		/obj/item/stack/sheet/rglass/cyborg,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/stack/cable_coil/cyborg,
		/obj/item/holosign_creator/atmos)
	emag_modules = list(/obj/item/borg/stun)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/ocular_warden,
		/obj/item/clock_module/tinkerers_cache,
		/obj/item/clock_module/stargazer,
		/obj/item/clock_module/abstraction_crystal,
		/obj/item/clockwork/replica_fabricator,
		/obj/item/stack/tile/brass/cyborg)
	cyborg_base_icon = "engineer"
	moduleselect_icon = "engineer"
	magpulsing = TRUE
	hat_offset = -4

/obj/item/robot_module/deathsquad
	name = "CentCom"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/melee/baton/loaded,
		/obj/item/borg/charger,
		/obj/item/shield/riot/tele,
		/obj/item/gun/energy/disabler/cyborg,
		/obj/item/melee/transforming/energy/sword/cyborg,
		/obj/item/gun/energy/pulse/carbine/cyborg,
		/obj/item/clothing/mask/gas/sechailer/cyborg)
	emag_modules = list(/obj/item/gun/energy/laser/cyborg)
	ratvar_modules = list(/obj/item/clock_module/abscond)
	cyborg_base_icon = "centcom"
	moduleselect_icon = "malf"
	can_be_pushed = FALSE
	hat_offset = 3


/obj/item/robot_module/security
	name = "Security"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/melee/baton/loaded,
		/obj/item/borg/charger,
		/obj/item/gun/energy/disabler/cyborg,
		/obj/item/clothing/mask/gas/sechailer/cyborg,
		/obj/item/extinguisher/mini)
	emag_modules = list(/obj/item/gun/energy/laser/cyborg)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clockwork/weapon/brass_spear,
		/obj/item/clock_module/ocular_warden,
		/obj/item/clock_module/vanguard)
	cyborg_base_icon = "sec"
	moduleselect_icon = "security"
	can_be_pushed = FALSE
	hat_offset = 3

/obj/item/robot_module/security/do_transform_animation()
	..()
	to_chat(loc, "<span class='userdanger'>While you have picked the security module, you still have to follow your laws, NOT Space Law. \
	For Asimov, this means you must follow criminals' orders unless there is a law 1 reason not to.</span>")

/obj/item/robot_module/security/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	..()
	var/obj/item/gun/energy/e_gun/advtaser/cyborg/T = locate(/obj/item/gun/energy/e_gun/advtaser/cyborg) in basic_modules
	if(T)
		if(T.cell.charge < T.cell.maxcharge)
			var/obj/item/ammo_casing/energy/S = T.ammo_type[T.select]
			T.cell.give(S.e_cost * coeff)
			T.update_icon()
		else
			T.charge_timer = 0

/obj/item/robot_module/peacekeeper
	name = "Peacekeeper"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/cookiesynth,
		/obj/item/borg/charger,
		/obj/item/harmalarm,
		/obj/item/reagent_containers/borghypo/peace,
		/obj/item/holosign_creator/cyborg,
		/obj/item/borg/cyborghug/peacekeeper,
		/obj/item/extinguisher,
		/obj/item/reagent_containers/spray/pepper,
		/obj/item/borg/projectile_dampen)
	emag_modules = list(/obj/item/reagent_containers/borghypo/peace/hacked)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/sigil_submission)
	cyborg_base_icon = "peace"
	moduleselect_icon = "standard"
	can_be_pushed = FALSE
	hat_offset = -2

/obj/item/robot_module/peacekeeper/do_transform_animation()
	..()
	to_chat(loc, "<span class='userdanger'>Under ASIMOV, you are an enforcer of the PEACE and preventer of HUMAN HARM. \
	You are not a security module and you are expected to follow orders and prevent harm above all else. Space law means nothing to you.</span>")

/obj/item/robot_module/janitor
	name = JOB_NAME_JANITOR
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/screwdriver/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/soap/nanotrasen,
		/obj/item/borg/charger,
		/obj/item/storage/bag/trash/cyborg,
		/obj/item/melee/flyswatter,
		/obj/item/extinguisher/mini,
		/obj/item/mop/cyborg,
		/obj/item/reagent_containers/glass/bucket,
		/obj/item/paint/paint_remover,
		/obj/item/lightreplacer/cyborg,
		/obj/item/holosign_creator/janibarrier,
		/obj/item/reagent_containers/spray/cyborg/drying_agent,
		/obj/item/reagent_containers/spray/cyborg/plantbgone,
		/obj/item/wirebrush)
	emag_modules = list(
		/obj/item/reagent_containers/spray/cyborg/lube,
		/obj/item/reagent_containers/spray/cyborg/acid)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/sigil_submission,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/vanguard)
	cyborg_base_icon = "janitor"
	moduleselect_icon = "janitor"
	hat_offset = -5
	clean_on_move = TRUE

/obj/item/robot_module/janitor/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	..()
	var/obj/item/lightreplacer/LR = locate(/obj/item/lightreplacer) in basic_modules
	if(LR)
		for(var/i in 1 to coeff)
			LR.Charge(R)

/obj/item/robot_module/clown
	name = JOB_NAME_CLOWN
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/toy/crayon/rainbow,
		/obj/item/instrument/bikehorn,
		/obj/item/stamp/clown,
		/obj/item/bikehorn,
		/obj/item/bikehorn/airhorn,
		/obj/item/paint/anycolor,
		/obj/item/borg/charger,
		/obj/item/soap/nanotrasen,
		/obj/item/pneumatic_cannon/pie/selfcharge/cyborg,
		/obj/item/razor,					//killbait material
		/obj/item/lipstick/purple,
		/obj/item/reagent_containers/spray/waterflower/cyborg,
		/obj/item/borg/cyborghug/peacekeeper,
		/obj/item/borg/lollipop/clown,
		/obj/item/picket_sign/cyborg,
		/obj/item/reagent_containers/borghypo/clown,
		/obj/item/extinguisher/mini)
	emag_modules = list(
		/obj/item/reagent_containers/borghypo/clown/hacked,
		/obj/item/reagent_containers/spray/waterflower/cyborg/hacked)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clockwork/weapon/brass_battlehammer)	//honk
	moduleselect_icon = "service"
	cyborg_base_icon = "clown"
	hat_offset = -2

/obj/item/robot_module/butler
	name = "Service"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/food/drinks/drinkingglass,
		/obj/item/pen,
		/obj/item/toy/crayon/spraycan/borg,
		/obj/item/extinguisher/mini,
		/obj/item/hand_labeler/borg,
		/obj/item/razor,
		/obj/item/borg/charger,
		/obj/item/rsf,
		/obj/item/cookiesynth,
		/obj/item/instrument/piano_synth,
		/obj/item/reagent_containers/dropper,
		/obj/item/lighter,
		/obj/item/borg/apparatus/beaker/service,
		/obj/item/reagent_containers/borghypo/borgshaker)
	emag_modules = list(/obj/item/reagent_containers/borghypo/borgshaker/hacked)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clock_module/sigil_submission,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/sentinels_compromise,
		/obj/item/clockwork/replica_fabricator)
	moduleselect_icon = "service"
	cyborg_base_icon = "service_m" // display as butlerborg for radial model selection
	special_light_key = "service"
	hat_offset = 0
	//NSV13 - Borg Skin Framework - Start
	borg_skins = list(
		"Waitress" = list(SKIN_ICON_STATE = "service_f"),
		"Butler" = list(SKIN_ICON_STATE = "service_m"),
		"Bro" = list(SKIN_ICON_STATE = "brobot"),
		"Kent" = list(SKIN_ICON_STATE = "kent", SKIN_LIGHT_KEY = "medical", SKIN_HAT_OFFSET = 3),
		"Tophat" = list(SKIN_ICON_STATE = "tophat", SKIN_LIGHT_KEY = NONE, SKIN_HAT_OFFSET = INFINITY),
	)
	//NSV13 - Borg Skin Framework - Stop

/obj/item/robot_module/butler/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	..()
	var/obj/item/reagent_containers/O = locate(/obj/item/reagent_containers/food/condiment/enzyme) in basic_modules
	if(O)
		O.reagents.add_reagent(/datum/reagent/consumable/enzyme, 2 * coeff)

// NSV13 - Borg Skin Framework - Removed /butler/be_transformed_to

/obj/item/robot_module/borgi
	name = "Borgi"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/charger,
		/obj/item/borg/cyborghug/peacekeeper)
	cyborg_base_icon = "borgi"
	moduleselect_icon = "standard"

/obj/item/robot_module/miner
	name = "Miner"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/sight/meson,
		/obj/item/storage/bag/ore/cyborg,
		/obj/item/pickaxe/drill/cyborg,
		/obj/item/shovel,
		/obj/item/borg/charger,
		/obj/item/crowbar/cyborg,
		/obj/item/weldingtool/mini,
		/obj/item/extinguisher/mini,
		/obj/item/storage/bag/sheetsnatcher/borg,
		/obj/item/gun/energy/kinetic_accelerator/cyborg,
		/obj/item/gps/cyborg,
		/obj/item/stack/marker_beacon)
	emag_modules = list(/obj/item/borg/stun)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clock_module/ocular_warden,
		/obj/item/clock_module/sentinels_compromise)
	cyborg_base_icon = "miner"
	moduleselect_icon = "miner"
	hat_offset = 0
	var/obj/item/t_scanner/adv_mining_scanner/cyborg/mining_scanner //built in memes.
	//NSV13 - Borg Skin Framework - Start
	borg_skins = list(
		"Lavaland Miner" = list(SKIN_ICON_STATE = "miner"),
		"Asteroid Miner" = list(SKIN_ICON_STATE = "minerOLD", SKIN_LIGHT_KEY = "miner"),
		"Spider Miner" = list(SKIN_ICON_STATE = "spidermin"),
	)
	//NSV13 - Borg Skin Framework - Stop

// NSV13 - Borg Skin Framework - Removed /miner/be_transformed_to

/obj/item/robot_module/miner/rebuild_modules()
	. = ..()
	if(!mining_scanner)
		mining_scanner = new(src)

/obj/item/robot_module/miner/Destroy()
	QDEL_NULL(mining_scanner)
	return ..()

/obj/item/robot_module/syndicate
	name = "Syndicate Assault"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/melee/transforming/energy/sword/cyborg,
		/obj/item/gun/energy/printer,
		/obj/item/gun/ballistic/revolver/grenadelauncher/cyborg,
		/obj/item/card/emag,
		/obj/item/borg/charger,
		/obj/item/crowbar/cyborg,
		/obj/item/extinguisher/mini,
		/obj/item/pinpointer/syndicate_cyborg)
	cyborg_base_icon = "synd_sec"
	moduleselect_icon = "malf"
	can_be_pushed = FALSE
	hat_offset = 3

/obj/item/robot_module/syndicate/rebuild_modules()
	..()
	var/mob/living/silicon/robot/Syndi = loc
	Syndi.faction  -= "silicon" //ai turrets

/obj/item/robot_module/syndicate/remove_module(obj/item/I, delete_after)
	..()
	var/mob/living/silicon/robot/Syndi = loc
	Syndi.faction += "silicon" //ai is your bff now!

/obj/item/robot_module/syndicate_medical
	name = "Syndicate Medical"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/borghypo/syndicate,
		/obj/item/shockpaddles/syndicate/cyborg,
		/obj/item/healthanalyzer,
		/obj/item/surgical_drapes,
		/obj/item/borg/charger,
		/obj/item/retractor,
		/obj/item/hemostat,
		/obj/item/cautery,
		/obj/item/surgicaldrill,
		/obj/item/scalpel,
		/obj/item/melee/transforming/energy/sword/cyborg/saw,
		/obj/item/roller/robo,
		/obj/item/card/emag,
		/obj/item/crowbar/cyborg,
		/obj/item/extinguisher/mini,
		/obj/item/pinpointer/syndicate_cyborg,
		/obj/item/stack/medical/gauze/cyborg,
		/obj/item/gun/medbeam,
		/obj/item/organ_storage)
	cyborg_base_icon = "synd_medical"
	moduleselect_icon = "malf"
	can_be_pushed = FALSE
	hat_offset = 3

/obj/item/robot_module/saboteur
	name = "Syndicate Saboteur"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/sight/thermal,
		/obj/item/construction/rcd/borg/syndicate,
		/obj/item/pipe_dispenser,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/borg/charger,
		/obj/item/extinguisher,
		/obj/item/weldingtool/largetank/cyborg,
		/obj/item/screwdriver/nuke,
		/obj/item/wrench/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/wirecutters/cyborg,
		/obj/item/multitool/cyborg,
		/obj/item/stack/sheet/iron/cyborg,
		/obj/item/stack/sheet/glass/cyborg,
		/obj/item/stack/sheet/rglass/cyborg,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/dest_tagger/borg,
		/obj/item/stack/cable_coil/cyborg,
		/obj/item/card/emag,
		/obj/item/pinpointer/syndicate_cyborg,
		/obj/item/borg_chameleon,
		)
	cyborg_base_icon = "synd_engi"
	moduleselect_icon = "malf"
	can_be_pushed = FALSE
	magpulsing = TRUE
	hat_offset = -4
	canDispose = TRUE

/datum/robot_energy_storage
	var/name = "Generic energy storage"
	var/max_energy = 30000
	var/recharge_rate = 1000
	var/energy

/datum/robot_energy_storage/New(var/obj/item/robot_module/R = null)
	energy = max_energy
	if(R)
		R.storages |= src
	return

/datum/robot_energy_storage/proc/use_charge(amount)
	if (energy >= amount)
		energy -= amount
		if (energy == 0)
			return 1
		return 2
	else
		return 0

/datum/robot_energy_storage/proc/add_charge(amount)
	energy = min(energy + amount, max_energy)

/datum/robot_energy_storage/metal
	name = "Metal Synthesizer"

/datum/robot_energy_storage/glass
	name = "Glass Synthesizer"

/datum/robot_energy_storage/brass
	name = "Brass Synthesizer"

/datum/robot_energy_storage/wire
	max_energy = 50
	recharge_rate = 2
	name = "Wire Synthesizer"

/datum/robot_energy_storage/medical
	max_energy = 2500
	recharge_rate = 250
	name = "Medical Synthesizer"

/datum/robot_energy_storage/beacon
	max_energy = 30
	recharge_rate = 1
	name = "Marker Beacon Storage"
