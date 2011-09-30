
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

#if defined UNIT_TEST

	new g_unitTester = 0;

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
		
		AddCommandListener(TeamGuard_HookJoinTeam, "jointeam");
	}

	public Action:Command_UnitTest(client, args)
	{
		PrintToChatAll("..... Unit1_SaveSet in 3 seconds");
		CreateTimer(3.0, Timer_Unit1_SaveSet, INVALID_HANDLE);
		g_unitTester = client;

		return Plugin_Handled;
	}

	TestOpenTeam(team, count)
	{		
		PrintToChatAll("..... Forcing Teams (%d Open for %d slots)", team, count);
		
		TeamGuard_SetOpenJoinTeam(team);
		
		new otherteam = RED_TEAM;
		if (team == RED_TEAM)
			otherteam = BLU_TEAM;
		
		new c = 0;
		for (new i = 1; i <= MaxClients; i++)
		{
			PrintToChatAll("..... Checking index %d", i);
			if (IsClientPlaying(i))
			{
				if (c < count)
					TeamGuard_MoveClientToTeam(i, otherteam);
				else
					TeamGuard_MoveClientToTeam(i, team);
				
				c += 1;
			}
			else
			{
				PrintToChatAll("......... Ignoring index %d", i);
			}
		}
	}
	
	public Action:Timer_Unit1_SaveSet(Handle:timer)
	{
		PrintToChatAll("..... Storing Teams");
		TeamGuard_Enable(RED_TEAM);

		TestOpenTeam(RED_TEAM, 1);
		
		PrintToChatAll("..... Unit1_Juggle in 10 seconds");
		CreateTimer(10.0, Timer_Unit1_Juggle, INVALID_HANDLE);
		
		return Plugin_Handled;
	}
	
	public OnClientDisconnect(client)
	{
		TeamGuard_OnClientDisconnect(client);
	}

	public Action:Timer_Unit1_Juggle(Handle:timer)
	{
		PrintToChatAll("..... Juggling Teams");
	
		TestOpenTeam(BLU_TEAM, 4);
	
		PrintToChatAll("..... Unit1_Restore in 10 seconds");
		CreateTimer(10.0, Timer_Unit1_Restore, INVALID_HANDLE);
	
		return Plugin_Handled;
	}
	
	public Action:Timer_Unit1_Restore(Handle:timer)
	{
		PrintToChatAll("..... Restoring Teams");
		TeamGuard_Disable();
		
		

		return Plugin_Handled;
	}

#endif

/**
 * Stores the current team and class of all connected clients, to be later restored
 */
TeamGuard_StoreTeams()
{
	new team;
	
	g_originalREDCount = 0;
	g_originalBLUCount = 0;
	
	for (new i = 1; i <= MaxClients; i++)
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
		
		ChangeClientTeam(client, team);
		
		//if (team == RED_TEAM || team == BLU_TEAM)
		//	TF2_RespawnPlayer(team);
		
		CheckForClassAssignment(client, team);
	}
}

/**
 * If the team has a rule against certain classes, need to force the client to pick a valid class
 */
CheckForClassAssignment(client, team)
{
	/// @todo flexible class restrictions
}

/**
 * Go through stored teams/classes and re-assign players to their original state 
 */
TeamGuard_RestoreTeams()
{	
	for (new i = 1; i <= MaxClients; i++)
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
		ChangeClientTeam(i, g_originalTeam[i]);
		TF2_SetPlayerClass(i, g_originalClass[i]);
		
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
}

TeamGuard_Disable()
{
	g_bTeamGuardEnabled = false;
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

stock bool:IsClientPlaying(client)
{ 
	return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && GetClientTeam(client) > 1; 
}


