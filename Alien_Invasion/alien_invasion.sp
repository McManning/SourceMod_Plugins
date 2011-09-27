

/*
	Milestones
	1. Create UFO players with proper controls, weapons, model, health, etc
		- Controls done (besides adjustments)
		- Model done (still need to fix colorize() in common_utils to cover weapons/hats
		- Primary weapon implemented, but not finished
	2. Add in manual team management, alert messaging, 
	3. Add Comm Towers gameplay
	4. Balance! Balance! Balance!
*/

#include <tf2items_giveweapon>
#include <sdkhooks>
#include "common_utils"

// GLOBALS

#define UFO_MODEL "models/props_nucleus/mp_captop.mdl"
#define UFO_GRAVITY (0.00001)
#define UFO_HITBOX_Z_OFFSET (100)
#define UFO_THINK (0.5)
#define TF2ITEMS_WEAPONS_OFFSET (3000)

/// @todo Convert to cvars
#define UFO_HORIZONTAL_FORCE (250.0)
#define UFO_VERTICAL_FORCE (90.0)
#define UFO_BASE_HEALTH (5000)
#define UFO_PRIMARY_ANGULAR_RANGE (15)

/// @todo per-map settings, not hardcoded
#define UFO_SPAWN_POSITION {-112.0, 444.0, 3366.0}
#define UFO_SPAWN_RANGE (300.0)
#define UFO_MIN_Z (1974.0) 


// Notification codes for UFO players
enum UFONotification
{
	UFO_NOTIFY_NONE = 0,
	UFO_NOTIFY_LOOKDOWN, /**< Triggered when they try to fire a weapon in an invalid direction **/
	UFO_NOTIFY_TOOLOW /**< When the UFO has gotten too close to the ground and has to pull up */
};


new bool:g_bIsUFO[MAXPLAYERS+1];
new UFONotification:g_UFONotifyCode[MAXPLAYERS+1];
new g_eUFOHitbox[MAXPLAYERS+1];

new g_lastButtons[MAXPLAYERS+1];

// INFO SECTION

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo =
{
	name = "[TF2] Alien Invasion",
	author = "Chase",
	description = "Boss Battle - UFOs",
	version = PLUGIN_VERSION,
	url = "http://www.sybolt.com"
};

// CODE

public OnPluginStart()
{
	RegAdminCmd("sm_testufo", Command_TestUFO, ADMFLAG_ROOT);

	HookEvent("post_inventory_application", Event_InventoryApplication,  
				EventHookMode_Post);
				
	CleanUp();
	
	CreateTimer(UFO_THINK, Timer_UFOThink, INVALID_HANDLE, TIMER_REPEAT); /// @todo here or OnMapStart?

	/*for (new i = 1; i <= MaxClients; i++) 
	{
        if(IsClientInGame(i))
		{
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
    }*/
	
	// Construct some alien weaponry
	
	// primary
	TF2Items_CreateWeapon(TF2ITEMS_WEAPONS_OFFSET, "tf_weapon_particle_cannon", 441, 0, 3, 100,
							"107 ; 2.0 ; 6 ; 0.25 ; 97 ; 0.01 ; 2 ; 10100.0", 
							5000, "", true);
	
	// secondary
	TF2Items_CreateWeapon(TF2ITEMS_WEAPONS_OFFSET + 1, "tf_weapon_raygun", 442, 1, 3, 100,
							"107 ; 2.0 ; 281 ; 0.0 ; 6 ; 0.25 ; 97 ; 0.01", 
							5000, "", true);
							
	// spaceships don't need no stinkin' melee... but, just for fun
	TF2Items_CreateWeapon(TF2ITEMS_WEAPONS_OFFSET + 2, "tf_weapon_bat_fish", 221, 2, 3, 100,
							"",
							-1, "", true);
}

/**
 * Resets client data, globals, etc.
 */
CleanUp()
{
	for (new i = 0; i < MAXPLAYERS+1; ++i)
	{
		g_bIsUFO[i] = false;
		g_UFONotifyCode[i] = UFO_NOTIFY_NONE;
		g_lastButtons[i] = 0;
		g_eUFOHitbox[i] = 0;
	}
}

public OnMapStart()
{

}

public OnClientPutInServer(client)
{
    //SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
	g_bIsUFO[client] = false;
	g_UFONotifyCode[client] = UFO_NOTIFY_NONE;
	g_lastButtons[client] = 0;
}

// No longer necessary as we modify takedamage. But pyros can still airblast immortals. 
// So keep for now, if we want to disable pyro airblasting later
/*public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3]) 
{
	// prevent UFOs from being knocked back
    if (victim != attacker && g_bIsUFO[victim])
	{
        damagetype |= DMG_PREVENT_PHYSICS_FORCE;
        return Plugin_Changed;
    }
	
    return Plugin_Continue;
}
*/

/**
 * Set specified player as a UFO entity (give weapons, model, etc) and let them test the control scheme
*/
public Action:Command_TestUFO(client, args)
{
	if (g_bIsUFO[client]) // disable mode
	{
		RemoveUFOModel(client);
		DestroyUFOHitboxEntity(client);
		
		SetEntityGravity(client, 1.0);
		
		TF2_RespawnPlayer(client);
		
		// SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	}
	else // give them UFO mode
	{
		TF2_SetPlayerClass(client, TFClass_Soldier, true, false);
		
		SetEntityGravity(client, UFO_GRAVITY);
		
		TeleportToUFOSpawn(client);
		
		GiveUFOModel(client);
		CreateUFOHitbox(client);
		GiveUFOWeapons(client);
		
		ColorizeEquipment(client, {0,0,0,0});
		
		// disable damage, health will be handled via the hitbox entity
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		
		PrintUFOHealthHud(client, UFO_BASE_HEALTH);
		PrintUFOHelpHud(client);
	}

	g_bIsUFO[client] = !g_bIsUFO[client];
	
	return Plugin_Handled;
}

TeleportToUFOSpawn(client)
{
	decl Float:pos[3] = UFO_SPAWN_POSITION;
	decl Float:vel[3] = { 0.0, 0.0, 0.0 };

	// randomize a bit
	pos[0] += GetRandomFloat(-UFO_SPAWN_RANGE, UFO_SPAWN_RANGE);
	pos[1] += GetRandomFloat(-UFO_SPAWN_RANGE, UFO_SPAWN_RANGE);
	
	TeleportEntity(client, pos, NULL_VECTOR, vel); 
}

public Event_InventoryApplication(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// TODO: Block for UFOs?
}

/**
 *	Performs checks on UFO players, such as position, activity, ...
 */
public Action:Timer_UFOThink(Handle:timer)
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		
		if (g_bIsUFO[i])
		{
			CheckUFOHeight(i);
			CheckUFONotifications(i);
			SyncUFOHitbox(i);
		}
	}
	
	return Plugin_Continue;
}

/**
 * If a UFO gets too low, force them up. This way players can't knock UFOs to the ground
 */
CheckUFOHeight(client)
{
	decl Float:pos[3];

	GetClientEyePosition(client, pos);

	if (pos[2] < UFO_MIN_Z)
	{
		g_UFONotifyCode[client] = UFO_NOTIFY_TOOLOW;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, { 0.0, 0.0, UFO_VERTICAL_FORCE } ); 
	}
}

/**
 * If there's any pending notifications for UFOs, print them out 
 */
CheckUFONotifications(client)
{
	/// @todo Better alerts
	switch (g_UFONotifyCode[client])
	{
		case UFO_NOTIFY_LOOKDOWN:
			PrintUFONoticeHud(client, "You need to look down to fire that weapon!"); 
		case UFO_NOTIFY_TOOLOW:
			PrintUFONoticeHud(client, "WARNING: Too low! Pull UP!"); 
	}
	
	g_UFONotifyCode[client] = UFO_NOTIFY_NONE;
}

/**
 * Teleports the hitbox entity used for UFO players to the proper client. 
 * The hitbox entity will supply defenders with a larger target, and control ship health
 */
SyncUFOHitbox(client)
{
	decl Float:pos[3];
	
	if (g_eUFOHitbox[client] != 0)
	{
		GetClientEyePosition(client, pos);
		pos[2] += UFO_HITBOX_Z_OFFSET; 
		
		TeleportEntity(g_eUFOHitbox[client], pos, NULL_VECTOR, NULL_VECTOR ); 
	}
}

CreateUFOHitbox(client)
{
	new prop = CreateEntityByName("prop_physics_override");
	SetEntityModel(prop, UFO_MODEL);
	
	DispatchKeyValue(prop, "StartDisabled", "false");

	DispatchKeyValue(prop, "Solid", "6");
	
	// http://docs.sourcemod.net/api/index.php?fastload=show&id=82&
	SetEntProp(prop, Prop_Data, "m_CollisionGroup", 4); //4);  2 = COLLISION_GROUP_DEBRIS_TRIGGER
	SetEntProp(prop, Prop_Data, "m_usSolidFlags", 16);
	SetEntProp(prop, Prop_Data, "m_nSolidType", 6); //SOLID_VPHYSICS (grab VPHYS from the model and use as collision map)
	
	DispatchSpawn(prop);
	AcceptEntityInput(prop, "Enable");
	AcceptEntityInput(prop, "TurnOn");
	AcceptEntityInput(prop, "DisableMotion");
	
	SetEntProp(prop, Prop_Data, "m_takedamage", 2);
	SetEntProp(prop, Prop_Data, "m_iMaxHealth", UFO_BASE_HEALTH);
	SetEntProp(prop, Prop_Data, "m_iHealth", UFO_BASE_HEALTH);
	
	HookSingleEntityOutput(prop, "OnTakeDamage", EntityOutput_UFOHitPropDamage, false);
	
	SDKHook(prop, SDKHook_ShouldCollide, OnUFOCollisionCheck); 
	
	SetEntityRenderMode(prop, RENDER_TRANSCOLOR);
	SetEntityRenderColor(prop, 0, 0, 0, 50); /// @todo translucent only for debugging

	g_eUFOHitbox[client] = prop;
}

/**
 * Hook for UFO collisions to handle special cases (no collide with players or pilot weapons)
 * @param entity the entity this is hooked to
 * @param collisiongroup 
 * @param contentsmask details regarding the collision (see sdkhooks_trace.inc:CONTENTS_*)
 * @return true if the collision should happen, false otherwise
 */
public bool:OnUFOCollisionCheck(entity, collisiongroup, contentsmask, bool:originalResult)
{
	/*
		For a UFO on BLU team:
			0x201480B <-- collision with player
			0x200480B <-- hit by our own cow mangler
			
		Outside uses TEAM1, inside TEAM2
		
		For a UFO on RED team:
			Other players rockets: 0x200580B
			My cow mangler: 0x200500B   .: difference of 0x800 (CONTENTS_TEAM1)
			
		Outside is TEAM2, inside TEAM1
	*/
	
	/// @todo condense logic
	if (contentsmask & CONTENTS_TEAM1 == CONTENTS_TEAM1) // collision b/w player/objects of different teams
	{
		if (collisiongroup != 8 && (contentsmask & CONTENTS_TEAM2 == CONTENTS_TEAM2))
		{
			//PrintToChatAll(".sp:319 ent:%i, group:%i, mask:%i, result:%i", entity, collisiongroup, contentsmask, originalResult);
			return true;
		}
		else // spammed: mask: 0x201480B
		{
			//PrintToChatAll(".sp:319 ent:%i, group:%i, mask:%i, FALSE", entity, collisiongroup, contentsmask);
			return false;
		}
	}
	else if (collisiongroup != 8) // unhandled cases that need to be understood.
	{
		//PrintToChatAll(".sp:333 group:%i, mask:%i, result:%i", collisiongroup, contentsmask, originalResult);	
		return true;
	}
	
	return false;
}

DestroyUFOHitboxEntity(client)
{
	if (g_eUFOHitbox[client] != 0)
	{
		AcceptEntityInput(g_eUFOHitbox[client], "Kill");
		g_eUFOHitbox[client] = 0;
	}
}

OnUFOHitboxDestroy(client)
{
	/// @todo check if client is still valid, kill him, whatever.
	
	g_eUFOHitbox[client] = 0;
}

/**
 * @param ent UFO hitbox entity linked to a pilot
 * @return entity ID of the associated client. 0 if none are found. 
 */
GetUFOPilotFromHitbox(ent)
{
	new result = 0;
	for (new i = 1; i <= MaxClients && result == 0; i++)
	{
		if (g_eUFOHitbox[i] == ent)
		{
			result = i;
		}
	}
	
	return result;
}

/**
 * Updates the HUD display of the client's UFO 
 * @param client 
 * @param health The new health (health <= UFO_BASE_HEALTH)
 */
PrintUFOHealthHud(client, health)
{
	decl String:buffer[64];
	Format(buffer, sizeof(buffer), "Health: %d/%d", health, UFO_BASE_HEALTH);
	
	SendHudMsg(client, 1, 0.01, 0.5, 
                    255, 0, 0, 255, 
                    255, 0, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    65535.0, 0.0, /// @todo proper "forever" display time 
                    buffer
			);
}

PrintUFOHelpHud(client)
{
	decl String:buffer[64];
	Format(buffer, sizeof(buffer), "[w] Accelerate, [a] Ascend, [d] Descend");
	
	SendHudMsg(client, 2, 0.01, 0.45, 
                    0, 255, 0, 255, 
                    0, 255, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    120.0, 0.0, 
                    buffer
			);
}

/// @todo after a while, this just stops working?
PrintUFONoticeHud(client, String:notice[])
{
	PrintToChat(client, notice);
	SendHudMsg(client, 3, -1.0, -1.0, 
                    255, 0, 0, 255, 
                    255, 0, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    5.0, 0.0, 
                    notice
			);
}


/**	Entity output hook. When a prop with this hook is damage, will modify the color of the prop
	to indicate the remaining health 
	@param caller the prop firing the output
	@param activator the prop that forced this prop to send its output
*/
public EntityOutput_UFOHitPropDamage(const String:output[], caller, activator, Float:delay)
{
	new health = GetEntProp(caller, Prop_Data, "m_iHealth");
	new maxhealth = GetEntProp(caller, Prop_Data, "m_iMaxHealth");

	// Energy weapons don't work, fire doesn't work, however the player can melee his own
	// UFO ship to death!
	
	new pilot = GetUFOPilotFromHitbox(caller);
	
	if (pilot != 0)
	{
		if (health < 1) // UFO killed
		{
			PrintToChatAll("UFO Hitbox destroyed");
			
			g_eUFOHitbox[pilot] = 0;
		}
		else
		{
			PrintUFOHealthHud(pilot, health);
		}
	}
}  

/**
 * Determines if the UFO can use its weapon or not
 * @return Plugin_Handled to block the attack, else Plugin_Continue
 */
Action:HandleUFOAttack(client)
{
	new String:weapon[64];
	GetClientWeapon(client, weapon, sizeof(weapon));
	
	if (StrEqual(weapon, "tf_weapon_particle_cannon")) // primary
	{ 
		// only let them fire 
		if (!IsLookingDown(client))
		{
			g_UFONotifyCode[client] = UFO_NOTIFY_LOOKDOWN;
			return Plugin_Handled;
		}
	} 
	else if (StrEqual(weapon, "tf_weapon_raygun")) // secondary
	{ 
		
	} 
	else if (StrEqual(weapon, "tf_weapon_bat_fish")) // melee
	{ 
		
	} 

	return Plugin_Continue;
}

/**
 * @return true if the client is looking down-ish
 */
bool:IsLookingDown(client)
{
	decl Float:ang[3];

	// In terms of pitch/yaw/roll, not a direction vector
	GetClientEyeAngles(client, ang);

	return ang[0] > (90 - UFO_PRIMARY_ANGULAR_RANGE);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) 
{ 
	if (g_bIsUFO[client])
	{		
		/// @todo this may be called a little too fast, optimize!
		if (buttons & IN_ATTACK)
		{
			return HandleUFOAttack(client);
		}
	
		decl Float:fVel[3];

		if ((buttons & IN_FORWARD) && !(g_lastButtons[client] & IN_FORWARD))
		{
			GetAngleVectors(angles, fVel, NULL_VECTOR, NULL_VECTOR); 
			NormalizeVector(fVel, fVel);
			ScaleVector(fVel, UFO_HORIZONTAL_FORCE);
		}
		else if ((buttons & IN_BACK) && !(g_lastButtons[client] & IN_BACK))
		{
			GetAngleVectors(angles, fVel, NULL_VECTOR, NULL_VECTOR); 
			NormalizeVector(fVel, fVel);
			//ScaleVector(fVel, UFO_HORIZONTAL_FORCE);
		}
		else
		{
			fVel[0] = fVel[1] = 0.0;
		}
		
		// Float up/down
		if ((buttons & IN_MOVELEFT) && !(g_lastButtons[client] & IN_MOVELEFT))
		{
			fVel[2] = UFO_VERTICAL_FORCE;
		}
		else if ((buttons & IN_MOVERIGHT) && !(g_lastButtons[client] & IN_MOVERIGHT))
		{
			fVel[2] = -UFO_VERTICAL_FORCE;
		}
		else
		{
			fVel[2] = 0.0;
		}

		g_lastButtons[client] = buttons;
			
		if (fVel[0] != 0.0 || fVel[1] != 0.0 || fVel[2] != 0.0)
		{
			//PrintToChat(client, "ang: %f,%f,%f", angles[0], angles[1], angles[2]);
			//PrintToChat(client, "Vel: %f,%f,%f vs %f,%f%f", fVel[0], fVel[1], fVel[2], vel[0], vel[1], vel[2]);
			TeleportEntity(client, NULL_VECTOR, angles, fVel); 
			
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}  


/**
 * Determines how many players should be UFOs based on the amountof players currently playing
 * @return number of players to become alien ships
 */
GetMaxUFOCount()
{

}

/**
 * @return current number of active UFOs (number of players on RED team)
 */
GetCurrentUFOCount()
{

}

/**
 * @return true if the specified client is an active UFO (alive and on RED)
 */
bool:IsUFO(client)
{

}

/**
 * Entry point to trigger an invasion. Will set some players as UFOs, set up control points, etc. 
 */
StartInvasion()
{
	/*n = GetMaxUFOCount();
	pick N random players, and BecomeUFO() on each one
	spawn comm towers
	*/
	
}


/**
 * Called when a UFO player is killed off. Perform some effect and alert everyone that the threat is eliminated, then determine if all the enemies are gone. 
 */
OnUFODestroyed(client)
{

}

/**
 * Called to manually kill a UFO (ex: UFO player goes idle or quits)
 */
ForceDestroyUFO(client)
{

}

/**
 * Converts the specified player into a UFO entity. This'll override their model, weapons, movement behavior, switch their team, etc. 
 */
BecomeUFO(client)
{

}

/**
 * Applies UFO model to specified player
 */
GiveUFOModel(client)
{
	if (IsPlayerAlive(client) && IsValidEntity(client))
	{
		SetVariantString(UFO_MODEL);
		AcceptEntityInput(client, "SetCustomModel");
		
		//SetVariantInt(1);
		//AcceptEntityInput(client, "SetCustomModelRotates");
		
		ColorizeEquipment(client, COLORIZE_INVIS);
	}
}

/**
 * Removes UFO model from specified player
 */
RemoveUFOModel(client)
{
	// TODO: Check for valid entity?
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	ColorizeEquipment(client, COLORIZE_NORMAL);
}

/**
 * Gives the UFO weapon set to the specified client. The clients weapons should be automatically restored to default upon death. 
 */
GiveUFOWeapons(client)
{
	for (new i = 2; i > -1; --i)
		TF2Items_GiveWeapon(client, TF2ITEMS_WEAPONS_OFFSET + i);
}

/**
 * Spawns Comm Tower entities that must be destroyed by BLU to weaken invading UFOs
*/
SpawnCommTowers()
{

}

/**
 * Triggered when a Comm Tower is destroyed. Effect changes depending on how many have been lost and how many remain. 
 */
OnCommTowerDestroyed()
{

}


/**
 * Stores the team (RED/BLU/SPEC) for all players to be later restored
 */
StoreTeams()
{

}

/**
 * Moves all players back to their previously stored teams 
 */
RestoreTeams()
{

}








