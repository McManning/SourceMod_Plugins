
/**
 *	@brief Generic team management and locking framework
 *	@author Chase McManning
 */

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1

#define UNIT_TEST

// Team store, manage, and recover

// also class locking!

#define RED_TEAM (2)
#define BLU_TEAM (3)
#define SPEC_TEAM (1)

new g_originalTeam[MAXPLAYERS+1];
new TFClassType:g_originalClass[MAXPLAYERS+1];

new g_originalREDCount;
new g_originalBLUCount;

new g_bAllowedToClosedTeam[MAXPLAYERS+1];
new g_openJoinTeam;

new g_bTeamGuardEnabled = false;

new Handle:g_cvarAutoTeamBalance = INVALID_HANDLE;
new g_oldAutoTeamBalanceValue = 1;

new TFClassType:g_forceClass[2];


TeamGuard_GetOpenTeam()
{
	return g_openJoinTeam;
}

TeamGuard_GetClosedTeam()
{
	if (g_openJoinTeam == RED_TEAM)
		return BLU_TEAM;

	return RED_TEAM;
}

#if defined UNIT_TEST

	#define PLUGIN_VERSION "1.0"
	public Plugin:myinfo =
	{
		name = "[TF2] Team Guard",
		author = "Chase",
		description = "Unit Tests for Team Guard include",
		version = PLUGIN_VERSION,
		url = "http://www.sybolt.com"
	};

	public OnPluginStart()
	{
		RegAdminCmd("sm_unit1_teamguard", Command_UnitTest, ADMFLAG_ROOT);
		RegAdminCmd("sm_unit2_teamguard", Command_UnitTest2, ADMFLAG_ROOT);
		
		HookEvent("player_spawn", TeamGuard_HookPlayerSpawn, EventHookMode_Pre);  
		
		AddCommandListener(TeamGuard_HookJoinTeam, "jointeam");
		//AddCommandListener(TeamGuard_HookJoinClass, "joinclass");
	}

	public Action:Command_UnitTest(client, args)
	{
		PrintToChatAll("..... Storing Teams");
		TeamGuard_Enable(RED_TEAM);

		SetToClosedTeam(1);
		
		PrintToChatAll("..... Unit1_Juggle in 10 seconds");
		CreateTimer(10.0, Timer_Unit1_Juggle, INVALID_HANDLE);
		
		return Plugin_Handled;
	}

	SetToClosedTeam(count)
	{		
		PrintToChatAll("..... Forcing Teams (%d closed with %d slots)", TeamGuard_GetClosedTeam(), count);

		new c = 0;
		for (new i = 1; i <= MaxClients; ++i)
		{
			PrintToChatAll("..... Checking index %d", i);
			if (IsClientPlaying(i))
			{
				if (c < count)
					TeamGuard_MoveClientToTeam(i, TeamGuard_GetClosedTeam());
				else
					TeamGuard_MoveClientToTeam(i, TeamGuard_GetOpenTeam());
				
				c += 1;
			}
			else
			{
				PrintToChatAll("......... Ignoring index %d", i);
			}
		}
	}
	
	public OnClientDisconnect(client)
	{
		TeamGuard_OnClientDisconnect(client);
	}

	public Action:Timer_Unit1_Juggle(Handle:timer)
	{
		PrintToChatAll("..... Juggling Teams");
	
		// swap open team, fill locked BLU
		TeamGuard_SetOpenJoinTeam(BLU_TEAM);
		SetToClosedTeam(4);
	
		PrintToChatAll("..... Restoration in 10 seconds");
		CreateTimer(10.0, Timer_RestoreTeams, INVALID_HANDLE);
	
		return Plugin_Handled;
	}
	
	public Action:Command_UnitTest2(client, args)
	{
		PrintToChatAll("..... Storing Teams and forcing RED to Heavy");
		
		TeamGuard_Enable(RED_TEAM);
		TeamGuard_SetForcedClass(BLU_TEAM, TFClass_Heavy);
		TeamGuard_SetForcedClass(RED_TEAM, TFClass_Pyro);
		
		SetToClosedTeam(5); // force two players to BLU
		
		PrintToChatAll("..... Restoration in 5 seconds");
		CreateTimer(50.0, Timer_RestoreTeams, INVALID_HANDLE);
		
		return Plugin_Handled;
	}
	
	public Action:Timer_RestoreTeams(Handle:timer)
	{
		PrintToChatAll("..... Restoring Teams");
		TeamGuard_Disable();
	
		return Plugin_Handled;
	}
	
#endif

/**
 * Wrapper over ChangeClientTeam to flag players who are manually moved to the closed team
 */
TeamGuard_MoveClientToTeam(client, team)
{
	if (IsClientPlaying(client))
	{
	
#if defined UNIT_TEST
		PrintToChatAll("Moving %L to %d", client, team);
#endif

		if ((team == RED_TEAM && g_openJoinTeam == BLU_TEAM) 
			|| (team == BLU_TEAM && g_openJoinTeam == RED_TEAM))
		{
			g_bAllowedToClosedTeam[client] = true;
		}

		RespawnClient(client, team, TeamGuard_GetForcedClass(team));
	}
}

/**
 * Stores the current team and class of all connected clients, to be later restored
 */
TeamGuard_StoreTeams()
{
	new team;
	
	g_originalREDCount = 0;
	g_originalBLUCount = 0;
	
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) < 2)
		{
			g_originalTeam[i] = -1;
		}
		else
		{
			team = GetClientTeam(i);					
			g_originalTeam[i] = team;
			
			switch (team)
			{
				case RED_TEAM:
					g_originalREDCount += 1;
				case BLU_TEAM:
					g_originalBLUCount += 1;
			}
			
			if (team == RED_TEAM || team == BLU_TEAM)
				g_originalClass[i] = TF2_GetPlayerClass(i);
			else
				g_originalClass[i] = TFClassType:TFClass_Soldier; // spec, pick generic class
				
				
#if defined UNIT_TEST
			PrintToChatAll("(%i) %L stored Team %i, Class %i", 
							i, i, g_originalTeam[i], g_originalClass[i]);
#endif

		}

	}
	
}

/**
 * Go through stored teams/classes and re-assign players to their original state 
 */
TeamGuard_RestoreTeams()
{	
	for (new i = 1; i <= MaxClients; ++i)
	{
		// don't force specs/non-ingamers to rejoin old teams
		if (!IsClientInGame(i) || GetClientTeam(i) < 2)
			continue;

		// if we haven't been assigned a team/class yet, do so
		if (g_originalTeam[i] == -1)
		{
#if defined UNIT_TEST
		PrintToChatAll("%L getting auto assigned", i);
#endif
			AutoAssignStoredTeam(i);
			g_originalClass[i] = TFClassType:TFClass_Soldier;
		}

		// restore
		RespawnClient(i, g_originalTeam[i], g_originalClass[i]);
		
		//TF2_RespawnPlayer(i);

#if defined UNIT_TEST
		PrintToChatAll("(%d) %L restored Team %i, Class %i", 
							i, i, g_originalTeam[i], g_originalClass[i]);
#endif
		
	}
}

TeamGuard_SetOpenJoinTeam(team)
{
	g_openJoinTeam = team;
	
	for (new i = 0; i < MAXPLAYERS+1; ++i)
		g_bAllowedToClosedTeam[i] = false;
}

TeamGuard_Enable(openTeam)
{
	g_cvarAutoTeamBalance = FindConVar("mp_autoteambalance");

	if (g_cvarAutoTeamBalance != INVALID_HANDLE)
	{
		g_oldAutoTeamBalanceValue = GetConVarInt(g_cvarAutoTeamBalance);
		SetConVarInt(g_cvarAutoTeamBalance, 0);
	}

	TeamGuard_StoreTeams();
	g_bTeamGuardEnabled = true;
	
	TeamGuard_SetOpenJoinTeam(openTeam);
	TeamGuard_ResetForcedClasses();
}

TeamGuard_Disable()
{
	g_bTeamGuardEnabled = false;
	TeamGuard_ResetForcedClasses();
	TeamGuard_RestoreTeams();
	
	if (g_cvarAutoTeamBalance != INVALID_HANDLE)
	{
		SetConVarInt(g_cvarAutoTeamBalance, g_oldAutoTeamBalanceValue);
	}
}

public TeamGuard_OnClientDisconnect(client)
{
	if (g_bTeamGuardEnabled)
	{
		switch (g_originalTeam[client])
		{
			case RED_TEAM:
				g_originalREDCount -= 1;
			case BLU_TEAM:
				g_originalBLUCount -= 1;
		}
		
		g_originalTeam[client] = -1;
		g_bAllowedToClosedTeam[client] = false;
	}
}

/**
 * Determines which stored team has less players, and stores the new client as that team
 */
AutoAssignStoredTeam(client)
{
	if (g_originalREDCount < g_originalBLUCount)
	{
		g_originalTeam[client] = RED_TEAM;
		g_originalREDCount += 1;
	}
	else
	{	
		g_originalTeam[client] = BLU_TEAM;
		g_originalBLUCount += 1;
	}

}

/**
 * If we're running manual control over teams, check the clients team request. 
 * Allow spec or g_openJoinTeam. Otherwise, force them into g_openJoinTeam.
 */
public Action:TeamGuard_HookJoinTeam(client, const String:command[], argc)
{  
	decl String:team[32];
	decl String:openTeam[16];  
	decl String:closedTeam[16];
	decl String:openVGUI[16];
	
	// if this client isn't allowed to go wherever they please, prevent closed team join
	if (g_bTeamGuardEnabled && !g_bAllowedToClosedTeam[client] 
		/*&& roundstate >= roundgrace && allows grace round*/)
	{
	
#if defined UNIT_TEST
		PrintToChatAll("%L Join Team Hook %s", client, command);
#endif
	
		GetCmdArg(1, team, sizeof(team));

		if (g_openJoinTeam == RED_TEAM)
		{
			openTeam = "red";
			closedTeam = "blue";
			openVGUI = "class_red";
		}
		else
		{
			openTeam = "blue";
			closedTeam = "red";
			openVGUI = "class_blue";      
		}

		// if they try to join the closed team (or pick random), force them into open 
		if (StrEqual(team, closedTeam, false) || StrEqual(team, "auto", false))
		{
			ChangeClientTeam(client, g_openJoinTeam);
			ShowVGUIPanel(client, openVGUI);
			return Plugin_Handled;
		}
		// let them join open/spec on their own accord
		else if (StrEqual(team, openTeam, false) || StrEqual(team, "spectate", false))
		{
			return Plugin_Continue;
		}
		else
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

/**
 * If class restrictions are in effect, prevent client from changing class
 * (We assume they're already on the proper class once they enter that team)
 */
public Action:TeamGuard_HookJoinClass(client, const String:command[], argc)
{
	decl String:classname[32];

	/// @todo may or may not be necessary now that spawn is hooked. This is unused, for now. 
	
	if (g_bTeamGuardEnabled)
	{
		GetCmdArg(1, classname, sizeof(classname));
		
		new team = GetClientTeam(client);
		
		if (TeamGuard_GetForcedClass(team) != TFClass_Unknown)
			//&& StrEqualTFClassType(classname, g_forceClass[team-2]))
		{
			PrintToChat(client, "You can't switch class during this event!");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:TeamGuard_HookPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{   

	if (g_bTeamGuardEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new team = GetClientTeam(client);
		
		new TFClassType:classtype = TeamGuard_GetForcedClass(team);
	
		if (classtype != TFClass_Unknown && TF2_GetPlayerClass(client) != classtype)
		{
			// re-roll
			RespawnClient(client, team, classtype);
			//TF2_SetPlayerClass(client, classtype, false, true); 

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

TeamGuard_ResetForcedClasses()
{
	g_forceClass[0] = g_forceClass[1] = TFClass_Unknown;
}

TeamGuard_SetForcedClass(team, TFClassType:classtype)
{
	g_forceClass[team-2] = classtype;
}

TFClassType:TeamGuard_GetForcedClass(team)
{
	return g_forceClass[team-2];
}

stock bool:IsClientPlaying(client)
{ 
	return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && GetClientTeam(client) > 1; 
}

stock bool:StrEqualTFClassType(const String:classname[], TFClassType:classtype)
{
	switch (classtype)
	{
		case TFClass_Scout: return StrEqual(classname, "scout", false);
		case TFClass_Sniper: return StrEqual(classname, "sniper", false);
		case TFClass_Soldier: return StrEqual(classname, "soldier", false);
		case TFClass_DemoMan: return StrEqual(classname, "demoman", false);
		case TFClass_Medic: return StrEqual(classname, "medic", false);
		case TFClass_Heavy: return StrEqual(classname, "heavyweapons", false);
		case TFClass_Pyro: return StrEqual(classname, "pyro", false);
		case TFClass_Spy: return StrEqual(classname, "spy", false);
		case TFClass_Engineer: return StrEqual(classname, "engineer", false);
	}
	
	return false;
}

// @author dirtyminuth
stock RespawnClient(client, team, TFClassType:classtype = TFClass_Unknown)
{
	if (IsClientInGame(client) && GetClientTeam(client) > 1)
	{
		//new TFClassType:classtype = TF2_GetPlayerClass(client);
	
		// if no class is specified, use player's class
		if (classtype == TFClass_Unknown)
			classtype = TF2_GetPlayerClass(client);
	
		// if the target team has class restrictions in place, change their target class
		if (g_bTeamGuardEnabled && g_forceClass[team-2] != TFClass_Unknown)
		{
			classtype = g_forceClass[team-2];
		}

		// Use of m_lifeState here prevents:
		// 1. "[Player] Suicided" messages.
		// 2. Adding a death to player stats.
		SetEntProp(client, Prop_Send, "m_lifeState", 2); 
		ChangeClientTeam(client, team);
		TF2_SetPlayerClass(client, classtype, false, true); 
		SetEntProp(client, Prop_Send, "m_lifeState", 0);      
		TF2_RespawnPlayer(client);      
	}
}

