/// How often the sensor data updates.
#define SENSORS_UPDATE_PERIOD 1 MINUTES

/// The job sorting ID associated with otherwise unknown jobs
#define UNKNOWN_JOB_ID	81

/obj/machinery/computer/crew
	name = "crew monitoring console"
	desc = "Used to monitor active health sensors built into most of the crew's uniforms."
	icon_screen = "crew"
	icon_keyboard = "med_key"
	use_power = IDLE_POWER_USE
	idle_power_usage = 250
	active_power_usage = 500
	circuit = /obj/item/circuitboard/computer/crew

	light_color = LIGHT_COLOR_BLUE

/obj/machinery/computer/crew/syndie
	icon_keyboard = "syndie_key"

/obj/machinery/computer/crew/ui_interact(mob/user)
	GLOB.crewmonitor.show(user,src)

GLOBAL_DATUM_INIT(crewmonitor, /datum/crewmonitor, new)

/datum/crewmonitor

	/// List of user -> UI source
	var/list/ui_sources = list()

	/// Cache of data generated by z-level, used for serving the data within SENSOR_UPDATE_PERIOD of the last update
	var/list/data_by_z = list()

	/// Cache of last update time for each z-level
	var/list/last_update = list()

	/// Map of job to ID for sorting purposes
	var/list/jobs = list(
		// Note that jobs divisible by 10 are considered heads of staff, and bolded
		// Job names are based on `hud_state` from id card.
		// 0: Captain
		JOB_HUD_CAPTAIN = 0,
		JOB_HUD_ACTINGCAPTAIN  = 1,
		JOB_HUD_RAWCOMMAND = 7,
		// 8-9: self-important people
		JOB_HUD_VIP = 8,
		JOB_HUD_KING = 9,
		// 10-19: Security
		JOB_HUD_HEADOFSECURITY = 10,
		JOB_HUD_WARDEN = 11,
		JOB_HUD_SECURITYOFFICER = 12,
		JOB_HUD_DETECTIVE = 13,
		JOB_HUD_BRIGPHYSICIAN = 14,
		JOB_HUD_DEPUTY = 15,
		JOB_HUD_RAWSECURITY = 19,
		// 20-29: Medbay
		JOB_HUD_CHEIFMEDICALOFFICIER = 20,
		JOB_HUD_CHEMIST = 21,
		JOB_HUD_GENETICIST = 22,
		JOB_HUD_VIROLOGIST = 23,
		JOB_HUD_MEDICALDOCTOR = 24,
		JOB_HUD_PARAMEDIC = 25,
		JOB_HUD_PSYCHIATRIST = 26,
		JOB_HUD_RAWMEDICAL = 29,
		// 30-39: Science
		JOB_HUD_RESEARCHDIRECTOR = 30,
		JOB_HUD_SCIENTIST = 31,
		JOB_HUD_ROBOTICIST = 32,
		JOB_HUD_EXPLORATIONCREW = 33,
		JOB_HUD_RAWSCIENCE = 39,
		// 40-49: Engineering
		JOB_HUD_CHIEFENGINEER = 40,
		JOB_HUD_STATIONENGINEER = 41,
		JOB_HUD_ATMOSPHERICTECHNICIAN = 42,
		JOB_HUD_RAWENGINEERING = 49,
		// 50-59: Cargo
		JOB_HUD_HEADOFPERSONNEL = 50,
		JOB_HUD_QUARTERMASTER = 51,
		JOB_HUD_SHAFTMINER = 52,
		JOB_HUD_CARGOTECHNICIAN = 53,
		JOB_HUD_RAWCARGO = 59,
		// 60+: Civilian/other
		JOB_HUD_BARTENDER = 61,
		JOB_HUD_COOK = 62,
		JOB_HUD_BOTANIST = 63,
		JOB_HUD_CURATOR = 64,
		JOB_HUD_CHAPLAIN = 65,
		JOB_HUD_CLOWN = 66,
		JOB_HUD_MIME = 67,
		JOB_HUD_JANITOR = 68,
		JOB_HUD_LAWYER = 69,
		JOB_HUD_BARBER = 71,
		JOB_HUD_STAGEMAGICIAN = 72,
		// nsv13 - 80+ Munitions
		JOB_HUD_MASTERATARMS = 80,
		JOB_HUD_PILOT = 81,
		JOB_HUD_MUNITIONSTECH = 82,
		JOB_HUD_ATC = 83, 
		JOB_HUD_RAWMUNITIONS = 84,
		JOB_HUD_BRIDGESTAFF = 85, //NSV13 end
		JOB_HUD_RAWSERVICE = 99,
		// ANYTHING ELSE = UNKNOWN_JOB_ID, Unknowns/custom jobs will appear after civilians, and before assistants
		JOB_HUD_ASSISTANT = 999,

		// 200-229: Centcom
		JOB_HUD_CENTCOM = 200,
		JOB_HUD_RAWCENTCOM = 229,


		// 300-309: misc
		JOB_HUD_SYNDICATE = 301,
		JOB_HUD_PRISONER = 302
	)

/datum/crewmonitor/Destroy()
	return ..()


/datum/crewmonitor/ui_state(mob/user)
	return GLOB.default_state

/datum/crewmonitor/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "CrewConsole")
		ui.open()
		ui.set_autoupdate(TRUE)

/datum/crewmonitor/proc/show(mob/M, source)
	ui_sources[WEAKREF(M)] = source
	ui_interact(M)

/datum/crewmonitor/ui_host(mob/user)
	return ui_sources[WEAKREF(user)]

/datum/crewmonitor/ui_data(mob/user)
	var/z = user.get_virtual_z_level()
	var/turf/T = get_turf(user)
	if(!z)
		z = T.get_virtual_z_level()
	. = list(
		"sensors" = update_data(z, T.z),
		"link_allowed" = isAI(user)
	)

/// z represents the virtual z-level the user is on
/// zlevel represents the physical z-level the mob is at.
/datum/crewmonitor/proc/update_data(z, zlevel)
	if(data_by_z["[z]"] && last_update["[z]"] && world.time <= last_update["[z]"] + SENSORS_UPDATE_PERIOD)
		return data_by_z["[z]"]

	var/list/results = list()

	for(var/mob/living/carbon/human/tracked_human as () in GLOB.suit_sensors_list)
		if(!tracked_human)
			stack_trace("Null reference in suit sensors list")
			GLOB.suit_sensors_list -= tracked_human
			continue

		var/turf/pos = get_turf(tracked_human)
		if(!pos)
			stack_trace("Tracked mob has no loc and is likely in nullspace: [tracked_human] ([tracked_human.type])")
			continue

		// Check their humanity.
		if(!ishuman(tracked_human))
			stack_trace("Non-human mob is in suit_sensors_list: [tracked_human] ([tracked_human.type])")
			continue

		var/virtual_z_level = tracked_human.get_virtual_z_level()

		// Check if their virtual z-level is correct or in case it isn't
		// check if they are on station's 'real' z-level
		if (virtual_z_level != z && !(is_station_level(pos.z) && is_station_level(zlevel)))
			continue

		// Determine if this person is using nanites for sensors,
		// in which case the sensors are always set to full detail
		var/nanite_sensors = HAS_TRAIT(tracked_human, TRAIT_NANITE_SENSORS)

		// Check for a uniform if not using nanites
		var/obj/item/clothing/under/uniform = tracked_human.w_uniform

		if (!nanite_sensors && !istype(uniform))
			stack_trace("Human without a suit sensors compatible uniform is in suit_sensors_list: [tracked_human] ([tracked_human.type]) ([uniform?.type])")
			continue

		// Are the suit sensors on?
		if (!nanite_sensors && (uniform?.has_sensor <= NO_SENSORS || !uniform?.sensor_mode))
			stack_trace("Human without active nanite and suit sensors is in suit_sensors_list: [tracked_human] ([tracked_human.type]) ([uniform.type])")
			continue

		// Radio transmitters are jammed
		if(tracked_human.is_jammed())
			continue

		// The entry for this human
		var/list/entry = list(
			"ref" = REF(tracked_human),
			"name" = "Unknown",
			"ijob" = UNKNOWN_JOB_ID,
		)

		var/obj/item/card/id/I = tracked_human.wear_id ? tracked_human.wear_id.GetID() : null

		if (I)
			entry["name"] = I.registered_name ? I.registered_name : "Unknown"
			entry["assignment"] = I.assignment ? I.assignment : "Unknown"
			if(jobs[I.hud_state] != null)
				entry["ijob"] = jobs[I.hud_state]

		// Binary living/dead status
		if (nanite_sensors || uniform.sensor_mode >= SENSOR_LIVING)
			entry["life_status"] = !tracked_human.stat

		// Damage
		if (nanite_sensors || uniform.sensor_mode >= SENSOR_VITALS)
			entry["oxydam"] = round(tracked_human.getOxyLoss(), 1)
			entry["toxdam"] = round(tracked_human.getToxLoss(), 1)
			entry["burndam"] = round(tracked_human.getFireLoss(), 1)
			entry["brutedam"] = round(tracked_human.getBruteLoss(), 1)

		// Area
		if (pos && (nanite_sensors || uniform.sensor_mode >= SENSOR_COORDS))
			entry["area"] = get_area_name(tracked_human, TRUE)

		// Trackability
		entry["can_track"] = tracked_human.can_track()

		results[++results.len] = entry

	data_by_z["[z]"] = results
	last_update["[z]"] = world.time

	return results

/datum/crewmonitor/ui_act(action,params)

	switch (action)
		if ("select_person")
			var/mob/living/silicon/ai/AI = usr
			if(!istype(AI))
				return
			AI.ai_camera_track(params["name"])

#undef SENSORS_UPDATE_PERIOD
#undef UNKNOWN_JOB_ID
