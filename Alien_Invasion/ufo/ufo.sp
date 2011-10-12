
/**
 *	@brief Alien Invasion boss battle event
 *	@author Chase McManning
 */


///////////////////// UFO GLOBALS /////////////////////

#include "ufo/hud.sp"
#include "include/boss_battle"
#include "include/explode"

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
#define UFO_SPAWN_POSITION {-112.0, 444.0, 3000.0}
#define UFO_SPAWN_RANGE (300.0)
#define UFO_MIN_Z (1974.0) 

new bool:g_bIsUFO[MAXPLAYERS+1];
new g_eUFOHitbox[MAXPLAYERS+1];
new g_lastButtons[MAXPLAYERS+1];


///////////////////// UFO INITIALIZATION /////////////////////


InitializeUFOs()
{
	// Initialize boss framework forwards
	CreateBossForwards();

	PreloadUFOWeapons();
	
	PreloadExplodeEffect();
	
	HookEvent("player_death", Event_UFODeath, EventHookMode_Pre);
	
	// set starting value for all globals
	for (new i = 0; i < MAXPLAYERS+1; ++i)
	{
		g_bIsUFO[i] = false;
		SetUFONotification(i, UFO_NOTIFY_NONE);
		g_lastButtons[i] = 0;
		g_eUFOHitbox[i] = 0;
	}
	
	// start the brain			
	CreateTimer(UFO_THINK, Timer_UFOThink, INVALID_HANDLE, TIMER_REPEAT); 

}

PreloadUFOWeapons()
{
	// Construct some alien weaponry
	
	/*
		NOTES:
			Property 100 is Blast Radius Decrease (0.3 is direct hit)
	*/
	
	// primary
	TF2Items_CreateWeapon(TF2ITEMS_WEAPONS_OFFSET, "tf_weapon_particle_cannon", 
							441, 0, 3, 100,
							"107 ; 2.0 ; 6 ; 0.25 ; 97 ; 0.01 ; 2 ; 10100.0", 
							5000, "", true);
	
	// secondary
	TF2Items_CreateWeapon(TF2ITEMS_WEAPONS_OFFSET + 1, "tf_weapon_raygun", 
							442, 1, 3, 100,
							"107 ; 2.0 ; 281 ; 0.0 ; 6 ; 0.25 ; 97 ; 0.01", 
							5000, "", true);
							
	// spaceships don't need no stinkin' melee... but, just for fun
	TF2Items_CreateWeapon(TF2ITEMS_WEAPONS_OFFSET + 2, "tf_weapon_bat_fish", 
							221, 2, 3, 100,
							"",
							-1, "", true);
}


///////////////////// UFO CREATION /////////////////////


/**
 * Converts the specified player into a UFO entity. This'll override their model, 
 * weapons, movement behavior, switch their team, etc. 
 */
BecomeUFO(client)
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
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 0);
	
	PrintUFOHealthHud(client, UFO_BASE_HEALTH, UFO_BASE_HEALTH);
	PrintUFOHelpHud(client);
	
	g_bIsUFO[client] = true;
	
	ExecuteForward_OnBossSpawn(client);
}

/**
 * Warps the specified player to the designated spawn point for UFOs for the current map.
 * Will also randomize slightly on the X/Z plane so that all UFOs don't spawn on top of 
 * each other. 
 */
TeleportToUFOSpawn(client)
{
	decl Float:pos[3] = UFO_SPAWN_POSITION;
	decl Float:vel[3] = { 0.0, 0.0, 0.0 };

	// randomize a bit
	pos[0] += GetRandomFloat(-UFO_SPAWN_RANGE, UFO_SPAWN_RANGE);
	pos[1] += GetRandomFloat(-UFO_SPAWN_RANGE, UFO_SPAWN_RANGE);
	
	TeleportEntity(client, pos, NULL_VECTOR, vel); 
}

/**
 * Constructs a "hitbox" entity that is basically a clone of the UFO craft, but follows
 * the player, maintains health, and is invisible. Used as a replacement for the player's 
 * hitbox for damage calculations.
 */
CreateUFOHitbox(client)
{
	new prop = CreateEntityByName("prop_physics_override");
	SetEntityModel(prop, UFO_MODEL);
	
	DispatchKeyValue(prop, "StartDisabled", "false");

	DispatchKeyValue(prop, "Solid", "6");
	
	// http://docs.sourcemod.net/api/index.php?fastload=show&id=82&
	SetEntProp(prop, Prop_Data, "m_CollisionGroup", 4);
	SetEntProp(prop, Prop_Data, "m_usSolidFlags", 16);
	//SOLID_VPHYSICS (Use VPHYS from model)
	SetEntProp(prop, Prop_Data, "m_nSolidType", 6); 
	
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
 * Gives the UFO weapon set to the specified client. The clients weapons 
 * should be automatically restored to default upon death. 
 */
GiveUFOWeapons(client)
{
	TF2_RemoveAllWeapons(client);
	
	for (new i = 2; i > -1; --i)
		TF2Items_GiveWeapon(client, TF2ITEMS_WEAPONS_OFFSET + i);
}


///////////////////// UFO DESTRUCTION /////////////////////

/**
 * Cleans up related UFO information from a client and respawns them
 */
RemoveUFO(client)
{
	if (g_bIsUFO[client])
	{
		DestroyUFOHitboxEntity(client);

		RemoveUFOModel(client);
		SetEntityGravity(client, 1.0);
		
		g_bIsUFO[client] = false;

		TF2_RespawnPlayer(client);
	}
}

/**
 * Explodes the UFO, respawns the player cleanly, triggers the OnBossDeath forward, 
 * and if this was the last UFO alive, triggers OnBossLose forward
 */
DestroyUFO(client)
{
	/// @todo check for valid client!

	ExecuteForward_OnBossDeath(client, BossDeath_Slayed);

	ExplodeEffectOnClient(client);
	RemoveUFO(client);
	
	// Check if this was the last UFO
	if (CountRemainingUFO() < 2)
	{
		ExecuteForward_OnBossLose(BossCond_NoneRemain);
	}
}

DestroyUFOHitboxEntity(client)
{
	if (g_eUFOHitbox[client] != 0)
	{
		AcceptEntityInput(g_eUFOHitbox[client], "Kill");
		g_eUFOHitbox[client] = 0;
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


///////////////////// UFO EVENTS /////////////////////


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
			SetUFONotification(client, UFO_NOTIFY_LOOKDOWN);
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

/**	Entity output hook. When a prop with this hook is damage, will modify the color of the prop
	to indicate the remaining health 
	@param caller the prop firing the output
	@param activator the prop that forced this prop to send its output
*/
public EntityOutput_UFOHitPropDamage(const String:output[], caller, activator, Float:delay)
{
	new health = GetEntProp(caller, Prop_Data, "m_iHealth");
	//new maxhealth = GetEntProp(caller, Prop_Data, "m_iMaxHealth");

	// Energy weapons don't work, fire doesn't work, however the player can melee his own
	// UFO ship to death!
	
	new pilot = GetUFOPilotFromHitbox(caller);
	
	if (pilot != 0)
	{
		if (health < 1) // UFO killed
		{
			g_eUFOHitbox[pilot] = 0;
			DestroyUFO(pilot);
			
			// Activator is a player (proper) idk if rockets will do the same though
			//PrintToChatAll("Activator");
			//PrintToChatAll(">> %L", activator);
			
			/* @todo something involving the activator player. Or store damage stats on everyone
				and eventually report the MVPs
			*/
		}
		else // update the pilot with statistics
		{
			PrintUFOHealthHud(pilot, health, UFO_BASE_HEALTH);
		}
	}
}

OnUFODisconnect(client)
{
	if (g_bIsUFO[client])
	{
		ExecuteForward_OnBossDeath(client, BossDeath_Disconnect);

		// Check if all UFOs have been destroyed
		if (CountRemainingUFO() < 2)
		{
			ExecuteForward_OnBossLose(BossCond_NoneRemain);
		}
		
		SetUFONotification(client, UFO_NOTIFY_NONE);
	
		DestroyUFOHitboxEntity(client);
		g_bIsUFO[client] = false;
		g_lastButtons[client] = 0;
	}
}

/**
 * Triggered when a UFO player kills themselves (or by admin). Does not trigger during
 * normal combat (as the player is assumed to be immortal, with a custom hitbox prop).
 */
public Action:Event_UFODeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client > 0 && client <= MaxClients && g_bIsUFO[client])
	{
		DestroyUFO(client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}


///////////////////// UFO THINK LOGIC /////////////////////


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
		SetUFONotification(client, UFO_NOTIFY_TOOLOW);
		
		pos[0] = 0.0;
		pos[1] = 0.0;
		pos[2] = UFO_VERTICAL_FORCE;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, pos ); 
	}
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


///////////////////// OTHER /////////////////////


/**
 * Set specified player as a UFO entity (give weapons, model, etc) and let them test the control scheme
*/
public Action:Command_TestUFO(client, args)
{
	if (g_bIsUFO[client]) // disable mode
	{
		DestroyUFO(client);
	}
	else // give them UFO mode
	{
		BecomeUFO(client);
	}

	return Plugin_Handled;
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

CountRemainingUFO()
{
	new count = 0;
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (g_bIsUFO[i])
			count += 1;
	}
	
	return count;
}


