
/**
 *	@brief Alien Invasion boss battle event
 *	@author Chase McManning
 */

#include <tf2items_giveweapon>
#include <sdkhooks>
#include "include/common_utils"
#include "teamguard.sp"

#include "ufo/ufo.sp"

#define PLUGIN_VERSION "1.0"
public Plugin:myinfo =
{
	name = "[TF2] Alien Invasion",
	author = "Chase",
	description = "Boss Battle - UFOs",
	version = PLUGIN_VERSION,
	url = "http://www.sybolt.com"
};

///////////////////// GLOBALS /////////////////////


#define SECONDS_PER_UFO (180.0) /**< Number of seconds predicted to defeat a UFO. Adjust for game balance */

new Handle:g_hInvadersWinTimer = INVALID_HANDLE;
new Handle:g_hMinuteRemaining = INVALID_HANDLE;


///////////////////// EVENTS /////////////////////


public OnPluginStart()
{
	RegAdminCmd("sm_testufo", Command_TestUFO, ADMFLAG_ROOT);
	
	RegAdminCmd("sm_invasion", Command_TestInvasion, ADMFLAG_ROOT);
	RegAdminCmd("sm_killinvasion", Command_KillInvasion, ADMFLAG_ROOT);
	
	InitializeUFOs();
}

public Action:Command_TestInvasion(client, args)
{
	SetupControlledInvasion(client);
	return Plugin_Handled;
}

public Action:Command_KillInvasion(client, args)
{
	PrintToChatAll("\x05%L force killed the invasion", client);
	
	CleanWreckage();
	
	return Plugin_Handled;
}

public OnMapStart()
{

}

public OnClientDisconnect(client)
{
	OnUFODisconnect(client);
}

public OnBossSpawn(client)
{
	PrintToChat(client, "BOSS SPAWN (%L)", client);
}

public OnBossDeath(client, BossDeath:reason)
{
	PrintToChat(client, "BOSS DEATH (%L Reason: %d)", client, reason);
}

public OnBossLose(BossCond:reason)
{
	/// @todo a real (appropriate) alert. Also announcer quotes
	PrintCenterTextAll("YOU HAVE SAVED HUMANITY!");
	PrintToChatAll("\x05The aliens have ran back home to Gallifrey. You've done it. You've saved mankind (for now)");
	
	/// @todo not immediate cleanup, let the defenders have fun for a sec or something
	CleanWreckage();
}

public OnBossWin(BossCond:reason)
{
	/// @todo a real (appropriate) alert. Also announcer quotes
	PrintCenterTextAll("YOU HAVE ALL DOOMED HUMANITY!");
	PrintToChatAll("\x05THE ALIENS HAVE WON. OUR CITIES ARE BURNING. HUMANITY IS ENSLAVED. ALL BECAUSE OF YOU. I hope you're happy.");

	/// @todo not immediate cleanup, let the bosses have fun for a sec or something
	CleanWreckage();
}

///////////////////// INVASION ENTRY POINT /////////////////////


/**
 * If the conditions are right to start an invasion; will reorganize teams, 
 * force players to UFO, and begin BOSS BATTLE!
 * @param count number of UFOs to invade
 */
SetupInvasion()
{
	new count = GetSuggestedUFOCount();
	
	// if there's enough players, start the invasion
	if (count > 0)
	{
		// set RED as defending team (open invite)
		TeamGuard_Enable(TFTeam:TFTeam_Red);

		ReorganizeTeams(count);
		
		StartInvasion(count);
	}
}

/**
 * Start an invasion, specifying the UFO client, for debugging purposes
 */
SetupControlledInvasion(client)
{
	TeamGuard_Enable(TFTeam:TFTeam_Red);
	
	ReorganizeTeamsForSinglePilot(client);
	
	StartInvasion(1);
}

/**
 * Will send proper messages to everyone and start the invasion timers 
 */
StartInvasion(count)
{
	SendInvasionAlert();
	
	/// @todo spawn secondary objectives
	
	g_hInvadersWinTimer = CreateTimer(SECONDS_PER_UFO * count, Timer_InvadersWin, 
									INVALID_HANDLE, 
									TIMER_FLAG_NO_MAPCHANGE); 
									
	g_hMinuteRemaining = CreateTimer((SECONDS_PER_UFO * count) - 60.0, Timer_MinuteRemaining, 
									INVALID_HANDLE, 
									TIMER_FLAG_NO_MAPCHANGE); 
}

/**
 * Calculate the number of UFOs based on the number of active players
 * Should be like UFOS=TOTALPLAYERS/5 (1 UFO for every 4 defenders)
 */
GetSuggestedUFOCount()
{
	new Float:players = 0;
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
			players += 1;
	}
	
	return RoundToFloor(players * 0.2); 
}

/**
 * Defenders couldn't defeat the UFOs in time, start an invasion
 */
public Action:Timer_InvadersWin(Handle:timer)
{
	if (g_hInvadersWinTimer == timer)
	{
		g_hInvadersWinTimer = INVALID_HANDLE;

		/// @todo somehow trigger an alien win!
		
		
		// Trigger OnBossWin(BossCond:reason)
		// reset everything
	}
	
	return Plugin_Continue;
}

/**
 * Tell everyone the invaders will win in a minute
 */
public Action:Timer_MinuteRemaining(Handle:timer)
{
	if (g_hMinuteRemaining == timer)
	{
		g_hMinuteRemaining = INVALID_HANDLE;

		SendMinuteRemainingAlert();
	}
	
	return Plugin_Continue;
}


/**
 * The specified client will become BLU, while the rest are on RED
 */
ReorganizeTeamsForSinglePilot(client)
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (i == client)
		{
			TeamGuard_MoveClientToTeam(i, TeamGuard_GetClosedTeam());
			BecomeUFO(i);
		} 
		else
		{
			TeamGuard_MoveClientToTeam(i, TeamGuard_GetOpenTeam());
		}
	}
}

/**
 * Determines which players should be invaders/defenders using an incredibly
 * complex algorithm involving psuedo randomization.
 * @param pilots quota of UFO pilots we need to meet
 */
ReorganizeTeams(pilots)
{
	new assignment[MAXPLAYERS+1];
	
	new c = 0;
	
	// go through clients, check for valid ones, assign to either defender/ufo randomly
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (IsClientPlaying(i))
		{
			// give them a random chance of being a UFO
			if (c < pilots && GetRandomInt(0, 3) == 0)
			{
				assignment[i] = 1;
				c += 1;
			}
			else
			{
				assignment[i] = 2; 
			}
		}
		else
		{
			assignment[i] = 0;
		}
	}
	
	// move clients to teams. If the random selection still hasn't filled up
	// UFO slots, then first clients encountered to be defenders will be UFO
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (assignment[i] == 1)
		{
			// if we still need UFO, and they're defender, turn to UFO
			if (c < pilots)
			{
				TeamGuard_MoveClientToTeam(i, TeamGuard_GetClosedTeam());
				BecomeUFO(i);
				c += 1;
			}
			else // defender
			{
				TeamGuard_MoveClientToTeam(i, TeamGuard_GetOpenTeam());
			}
		}
		else if (assignment[i] == 2)
		{
			// ufo
			TeamGuard_MoveClientToTeam(i, TeamGuard_GetClosedTeam());
			BecomeUFO(i);
		}
	}
	
}

/**
 * Tell players the invasion has begun, how much time they have to win, etc
 */
SendInvasionAlert()
{
	/// @todo a real (appropriate) alert. Also announcer quotes
	PrintCenterTextAll("HOLY SHITTING DICK NIPPLES! ALIENS!!!!");
	PrintToChatAll("\x05MOTHERFUGGIN ALIENS!!! QUICK, BAND TOGETHER AND KILL THEM!");
	PrintToChatAll("\x05Oh, by the way, you only have a few minutes before their main forces arrive and enslave humanity. Enjoy.");
}

/**
 * Tell players the invaders will win in a minute if not defeated
 */
SendMinuteRemainingAlert()
{
	/// @todo a real (appropriate) alert. Also announcer quotes
	PrintCenterTextAll("ONE MINUTE REMAINING");
	PrintToChatAll("\x05HURRY UP! YOU ONLY HAVE A MINUTE BEFORE HUMANITY IS ENSLAVED! FFFFFUUUU");
}

/**
 * Restore players, kill timers, reactivate whatever. Basically go back to normal.
 */
CleanWreckage()
{
	// close timers
	if (g_hInvadersWinTimer != INVALID_HANDLE)
	{	
		CloseHandle(g_hInvadersWinTimer);
		g_hInvadersWinTimer = INVALID_HANDLE;
	}
	
	if (g_hMinuteRemaining != INVALID_HANDLE)
	{	
		CloseHandle(g_hMinuteRemaining);
		g_hMinuteRemaining = INVALID_HANDLE;
	}
	
	// clean UFO players
	ResetAllUFOs();
	
	// restore teams
	TeamGuard_Disable();
}

/**
 * Remove UFO status from all players, without triggering any forwards
 */
ResetAllUFOs()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		// let RemoveUFO determine if they should be cleaned or not
		if (IsClientInGame(i))
		{
			RemoveUFO(i);
		}
	}
}





