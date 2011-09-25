

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo =
{
	name = "[TF2] Prediction Framework",
	author = "Chase",
	description = "Experimental WiP",
	version = PLUGIN_VERSION,
	url = "http://www.sybolt.com"
};

//-------------------------------------------------

#define ARROW_LIFE 120.0*5

new g_iBeamSprite;
new g_iHaloSprite;

// Resets on respawn
new Float:g_fGeneralDV[MAXPLAYERS+1][3];
new Float:g_fLastPosition[MAXPLAYERS+1][3];

// debugging
new bool:g_bWatchingPredictions[MAXPLAYERS+1] = { false, ... };

// this should be instanced for all, but for testing purposes, only one should be watched @ a time
new Float:g_fGeneralDVLog[5][3];
new g_iGeneralDVLogIndex = 0;
new Float:g_fTargetVector[3];

new Handle:g_hUpdateGeneralDVs = INVALID_HANDLE;

#define MAX_POIS 300

new g_iPOIList[MAX_POIS];
new g_iPOIIndex = 0;

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	RegAdminCmd("sm_pf_watch", Command_ToggleWatch, ADMFLAG_SLAY, "sm_pf_watch <#userid|name>");
	RegAdminCmd("sm_pf_identify", Command_IdentifyPOIs, ADMFLAG_SLAY, "");
}

public OnMapStart()
{
	g_iBeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");

	g_hUpdateGeneralDVs = CreateTimer(1.0, Timer_UpdateAllGeneralDVs, INVALID_HANDLE, TIMER_REPEAT);
	
	AddEntityClassToPOIList("func_respawnroom"); // not working
	AddEntityClassToPOIList("info_player_teamspawn"); // good (But there are a lot)
	AddEntityClassToPOIList("trigger_capture_area"); //<-- sourcemod claims this is correct
	AddEntityClassToPOIList("item_teamflag"); 
	AddEntityClassToPOIList("item_ammopack_full");
	AddEntityClassToPOIList("item_ammopack_medium");
	AddEntityClassToPOIList("item_ammopack_small");
	AddEntityClassToPOIList("item_healthkit_full");
	AddEntityClassToPOIList("item_healthkit_medium");
	AddEntityClassToPOIList("item_healthkit_small");
	
	// Must be added/removed late-game
	//AddEntityClassToPOIList("obj_sentrygun");
	//AddEntityClassToPOIList("obj_teleporter");
	
	AddEntityClassToPOIList("mapobj_cart_dispenser"); //not working
	AddEntityClassToPOIList("team_control_point"); // not working (payload)
	AddEntityClassToPOIList("dispenser_touch_trigger"); //not working

}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client)
	{
		ResetGeneralDV(client);
	}
}

public Action:Command_ToggleWatch(client, args)
{
	decl String:target[65];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_pf_watch <#userid|name>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, target, sizeof(target));
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
		
	for (new i = 0; i < target_count; i++)
	{
		g_bWatchingPredictions[target_list[i]] = !g_bWatchingPredictions[target_list[i]];
		ReplyToCommand(client, "Toggled watch on %N to %i", target_list[i], g_bWatchingPredictions[target_list[i]]);
	}
	return Plugin_Handled;
}

// Fires a beam from each poi into the air
public Action:Command_IdentifyPOIs(client, args)
{
	new Float:pos[3];
	new Float:end[3];
	
	for (new i = 0; i < g_iPOIIndex; ++i)
	{
		GetEntPropVector( g_iPOIList[i], Prop_Data, "m_vecOrigin", pos );
		end = pos;
		end[2] = 2000.0;
		
		SketchArrowToSpec(pos, end, {0,0,255,255});
	}
}

SketchArrowTo(client, const Float:start[3], const Float:end[3], const color[4])
{
	TE_SetupBeamPoints(start, end, g_iBeamSprite, g_iHaloSprite, 0, 0, ARROW_LIFE, 20.0, 10.0, 5, 0.0, color, 30);
	
	// just the tip
	//TE_SetupBeamPoints(start, end, g_iBeamSprite, g_iHaloSprite, 0, 0, ARROW_LIFE, 20.0, 10.0, 5, 0.0, color, 30);
	
	TE_SendToClient(client);
}


SketchArrowToSpec(const Float:start[3], const Float:end[3], const color[4])
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if ( IsClientInGame(i) ) //&& GetClientTeam(i) == 1 )
		{
			SketchArrowTo(i, start, end, color);
			//PrintToConsole(i, "Sketching Arrow From %f,%f,%f To %f,%f,%f", start[0], start[1], start[2], end[0], end[1], end[2]);
		}
	}
}

PrintToSpectators(String:text[], any:...)
{
	new String:message[128];
	VFormat(message, sizeof(message), text, 2);	
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if ( IsClientInGame(i) ) // && GetClientTeam(i) == 1 )
		{
			PrintToConsole(i, "%s", message);
		}
	}
}

SketchDV(client, const Float:start[3])
{
	new Float:end[3];
	end[0] = start[0] + g_fGeneralDV[client][0];
	end[1] = start[1] + g_fGeneralDV[client][1];
	end[2] = start[2] + g_fGeneralDV[client][2];
	
	SketchArrowToSpec(start, end, { 255,255,25,255 });
}

ResetGeneralDV(client)
{
	g_fGeneralDV[client][0] = 0.0;
	g_fGeneralDV[client][1] = 0.0;
	g_fGeneralDV[client][2] = 0.0;

	g_fLastPosition[client][0] = 0.0;
	g_fLastPosition[client][1] = 0.0;
	g_fLastPosition[client][2] = 0.0;
}

UpdateGeneralDV(client)
{
	new Float:pos[3];
	new Float:vec[3];
	GetClientAbsOrigin(client, pos);
	
	if (GetVectorLength(g_fLastPosition[client]) == 0)
	{
		PrintToSpectators("First g_fLastPosition for %L as %f,%f,%f", client, pos[0], pos[1], pos[2]);
	}
	else // generate a vector between the two points
	{
		MakeVectorFromPoints(g_fLastPosition[client], pos, vec);
		
		PrintToSpectators("Creating Vector for %L as %f,%f,%f", client, vec[0], vec[1], vec[2]);
		
		SketchArrowToSpec(g_fLastPosition[client], pos, {100,10,100,255});
		
		if (GetVectorLength(g_fGeneralDV[client]) == 0)
		{
			//PrintToSpectators("Setting initial GeneralDV for %L as %f,%f,%f", client, vec[0], vec[1], vec[2]);
			g_fGeneralDV[client] = vec;
		}
		else // average the new vector with our DV
		{
			g_fGeneralDV[client][0] = (g_fGeneralDV[client][0] + vec[0]) * 0.5;
			g_fGeneralDV[client][1] = (g_fGeneralDV[client][1] + vec[1]) * 0.5;
			g_fGeneralDV[client][2] = (g_fGeneralDV[client][2] + vec[2]) * 0.5;
		
			g_fGeneralDVLog[g_iGeneralDVLogIndex] = g_fGeneralDV[client];
			g_iGeneralDVLogIndex++;
			
			if (g_iGeneralDVLogIndex > 4)
			{
				g_iGeneralDVLogIndex = 0;
				AverageDVs(pos);
				
				PredictTargetPOI(client);
			}

			//PrintToSpectators("Averaging General DV for %L as %f,%f,%f", client, g_fGeneralDV[client][0], g_fGeneralDV[client][1], g_fGeneralDV[client][2]);
		
			// Render our DV for testing
			SketchDV(client, pos);
		}
	}
	
	g_fLastPosition[client] = pos;
}

AverageDVs(Float:start[3])
{
	for (new index = 0; index < 5; ++index)
	{
		for (new i = 0; i < 3; ++i)
		{
			g_fTargetVector[i] += g_fGeneralDVLog[index][i];
		}
	}
	
	//g_fTargetVector[0] *= 0.2;
	//g_fTargetVector[1] *= 0.2;
	//g_fTargetVector[2] *= 0.2;
	
	// sketch vector
	new Float:end[3];
	end[0] = start[0] + g_fTargetVector[0];
	end[1] = start[1] + g_fTargetVector[1];
	end[2] = start[2] + g_fTargetVector[2];
	
	SketchArrowToSpec(start, end, { 0,255,0,255 });
}

public Action:Timer_UpdateAllGeneralDVs(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if ( IsClientOnValidTeam(i) && g_bWatchingPredictions[i] )
		{
			UpdateGeneralDV(i);
		}
	}
	
	return Plugin_Handled;
}


/*	Returns true if the client is actively playing on RED or BLU */
stock bool:IsClientOnValidTeam(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return false;

	new team = GetClientTeam(client);
	return (team == 2 || team == 3);
}

stock FindEntityByClassname2(startEnt, const String:classname[])
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	
	return FindEntityByClassname(startEnt, classname);
}

AddEntityClassToPOIList(const String:classname[])
{
	new index = -1;
	new count = 0;
	while ((index = FindEntityByClassname2(index, classname)) != -1)
	{
		if (g_iPOIIndex >= MAX_POIS)
		{
			ThrowError("Reached POI Limit");
		}
		else
		{
			g_iPOIList[g_iPOIIndex++] = index;
			count++;
		}
	}
	
	PrintToSpectators("Found %i instances of %s", count, classname);
}

stock Float:Magnitude(const Float:a[3], const Float:b[3])
{
	new Float:r[3];
	r[0] = b[0] - a[0];
	r[1] -= b[1] - a[1];
	r[2] -= b[2] - a[2];
	
	return SquareRoot( r[0]*r[0] + r[1]*r[1] + r[2]+r[2] );
}

stock Float:DistancePointLine(const Float:point[3], const Float:start[3], const Float:end[3])
{
	new Float:mag;
	new Float:u;
	new Float:intersection[3];
	
	mag = Magnitude(start, end);
	
	u = ( ( ( point[0] - start[0] ) * ( end[0] - start[0] ) ) +
		( ( point[1] - start[1] ) * ( end[1] - start[1] ) ) +
        ( ( point[2] - start[2] ) * ( end[2] - start[2] ) ) ) /
        ( mag * mag );
		
	if (u < 0.0 || u > 1.0)
		return 0.0; //closest point does not fall within line segment
		
	intersection[0] = start[0] + u * ( end[0] - start[0] );
	intersection[1] = start[1] + u * ( end[1] - start[1] );
	intersection[2] = start[2] + u * ( end[2] - start[2] );
	
	return Magnitude(point, intersection);
}


/**
	Based on class, nearest POI (CPs/Carts/Flags/Sentries) and various other variables.
	@return a length value to check against the length of our Target Vector. 
*/
GetDefensiveThreshold(client)
{
	return 100; // More like return rand() amirite
}

/**
	The meat. Will weigh the distance/direction of our Target Vector against each POI,
	where each POI also changes its weight based on various bits of information (our class,
	health, ammo, other players actions, the state of the POI, etc)
	
	@return Index of our POI entity, or -1 if we just don't have a good enough prediction
*/
PredictTargetPOI(client)
{
	new index = GetClosestPOIToTargetVector(client);
	
	if (index != -1)
	{
		new String:classname[64];
		GetEntPropString(index, Prop_Data, "classname", classname, sizeof(classname));
		
		PrintToSpectators("PredictTargetPOI(%N) To %s", client, classname);
	}
	
	return index;
}

GetClosestPOIToTargetVector(client)
{
	// For laziness sake since this is sitting as a todo, this will just get the closest POI to our 
	// TV and return that. Or -1 if there's nothing nearby. 

	new Float:pos[3];
	new Float:start[3];
	new Float:end[3];
	
	new Float:distance;
	
	new shortestDistance = 100; // magic number, everything further than this ignored
	new selectedIndex = -1;
	
	GetClientAbsOrigin(client, start);
	
	end = start;
	end[0] += g_fTargetVector[0];
	end[1] += g_fTargetVector[1];
	end[2] += g_fTargetVector[2];
	
	for (new i = 0; i < g_iPOIIndex; ++i)
	{
		GetEntPropVector( g_iPOIList[i], Prop_Data, "m_vecOrigin", pos );
		
		distance = DistancePointLine(pos, start, end);
		
		if (distance < shortestDistance)
		{
			shortestDistance = distance;
			selectedIndex = g_iPOIList[i];
		}
	}

	return selectedIndex;
}




