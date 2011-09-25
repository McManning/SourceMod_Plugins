

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
#include "common_utils"

// GLOBALS

#define UFO_MODEL "models/props_nucleus/mp_captop.mdl"
#define UFO_GRAVITY (0.00001)

/// @todo Convert to cvars
#define UFO_HORIZONTAL_FORCE (100.0)
#define UFO_VERTICAL_FORCE (50.0)

/// @todo per-map settings, not hardcoded
#define UFO_SPAWN_POSITION {-112.0, 444.0, 3366.0}
#define UFO_MIN_Z (1974.0) 


// Notification codes for UFO players
enum UFONotification
{
	UFO_NOTIFY_NONE = 0,
	UFO_NOTIFY_LOOKDOWN, /**< Triggered when they try to fire a weapon in an invalid direction **/
	UFO_NOTIFY_TOOLOW /**< When the UFO has gotten too close to the ground and has to pull up */
};


new bool:g_bIsDebugUFO[MAXPLAYERS+1];
new UFONotification:g_UFONotifyCode[MAXPLAYERS+1];

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
				
	for (new i = 0; i < MAXPLAYERS+1; ++i)
	{
		g_bIsDebugUFO[i] = false;
		g_UFONotifyCode[i] = UFO_NOTIFY_NONE;
		g_lastButtons[i] = 0;
	}
	
	CreateTimer(1.0, Timer_UFOThink, INVALID_HANDLE, TIMER_REPEAT); /// @todo here or OnMapStart?

	
	// Construct some alien weaponry
	TF2Items_CreateWeapon(3000, "tf_weapon_particle_cannon", 441, 0, 3, 100,
							"107 ; 2.0 ; 6 ; 0.25 ; 134 ; 32 ; 97 ; 0.01 ; 2 ; 10100.0", 
							5000, "", true);

}

public OnMapStart()
{

}

public OnClientDisconnect(client)
{
	g_bIsDebugUFO[client] = false;
}


/**
 * Set specified player as a UFO entity (give weapons, model, etc) and let them test the control scheme
*/
public Action:Command_TestUFO(client, args)
{
	if (g_bIsDebugUFO[client]) // disable mode
	{

		RemoveUFOModel(client);
		
		SetEntityGravity(client, 1.0);
		
		TF2_RespawnPlayer(client);
	}
	else // give them UFO mode
	{
	
		GiveUFOModel(client);
		GiveUFOWeapons(client);
		
		SetEntityGravity(client, UFO_GRAVITY);
		
		TeleportToUFOSpawn(client);
	}

	g_bIsDebugUFO[client] = !g_bIsDebugUFO[client];
	
	return Plugin_Handled;
}

TeleportToUFOSpawn(client)
{
	decl Float:pos[3] = UFO_SPAWN_POSITION;
	decl Float:vel[3] = { 0.0, 0.0, 0.0 };

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
		
		if (g_bIsDebugUFO[i])
		{
			CheckUFOHeight(i);
			CheckUFONotifications(i);
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
			PrintToChat(client, "You need to look down to fire that weapon!"); 
		case UFO_NOTIFY_TOOLOW:
			PrintToChat(client, "WARNING: Too low! Pull UP!"); 
	}
	
	g_UFONotifyCode[client] = UFO_NOTIFY_NONE;
}

/**
 * Determines if the UFO can use its weapon or not
 * @return Plugin_Handled to block the attack, else Plugin_Continue
 */
Action:HandleUFOAttack(client)
{
	if (!IsLookingDown(client))
	{
		g_UFONotifyCode[client] = UFO_NOTIFY_LOOKDOWN;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/**
 * @return true if the client is looking down-ish
 */
bool:IsLookingDown(client)
{
	/// @todo THIS! Use GetClientEyeAngles and make sure we're within range (say 30deg from straight down)
	return false;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) 
{ 
	if (g_bIsDebugUFO[client])
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
		
		//return Plugin_Handled; //block, we handle it manually
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
		
		Colorize(client, COLORIZE_INVIS);
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
	
	Colorize(client, COLORIZE_NORMAL);
}

/**
 * Gives the UFO weapon set to the specified client. The clients weapons should be automatically restored to default upon death. 
 */
GiveUFOWeapons(client)
{
	TF2Items_GiveWeapon(client, 3000);
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








