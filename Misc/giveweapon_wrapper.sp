
/*

command:
	sm_singleweapon ID
	
	Explode all, sm_giveweapon_ex @all ID 
	on join, sm_giveweapon_ex joiner 
	Disable resupplies
	delete all items
	on respawn, keep deleting all loadout cept the specific one.. ?
	OR, replace the other slots with useless items. W/e they may be
	
	
*/

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include "tf2items_giveweapon"

#pragma semicolon 1

#define PLUGIN_VERSION "0.1.0"


new g_iWeaponIndex = 0;

public Plugin:myinfo =
{
	name = "[TF2] GiveWeapon Wrapper",
	author = "Chase",
	description = "Wrapper around GiveWeapon to enforce single weapon rounds",
	version = PLUGIN_VERSION,
	url = "http://www.sybolt.com"
};

public OnPluginStart()
{
	//HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PostInventoryApplication,  EventHookMode_Post);
	
	RegAdminCmd("sm_singleweapon", Command_SingleWeapon, ADMFLAG_CHEATS);
}

public OnMapStart()
{
	g_iWeaponIndex = 0;
}

public Action:Command_SingleWeapon(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_singleweapon <index>");
		return Plugin_Handled;	
	}
	
	decl String:sIndex[16];
	GetCmdArg(1,sIndex,sizeof(sIndex));
	g_iWeaponIndex = StringToInt(sIndex);

	if (g_iWeaponIndex == 0)
		PrintCenterTextAll("Single Weapon Mode Disabled!");
	else
		PrintCenterTextAll("Single Weapon Mode Enabled!");
	
	// I'm lazy, let respawn handle it 
	new maxplayers = GetMaxClients();
	for (new i = 1; i <= maxplayers; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
			TF2_RespawnPlayer(i);
	}
	
	return Plugin_Handled;
}

public Event_PostInventoryApplication(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_iWeaponIndex != 0)
		CreateTimer(0.1, Timer_SetWeapon, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SetWeapon(Handle:timer, any:client)
{
	SetWeapon(client);
}

stock SetWeaponForAll()
{
	new maxplayers = GetMaxClients();
	for (new i = 1; i <= maxplayers; i++)
		SetWeapon(i);
}

stock SetWeapon(client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		//for (new i = 0; i <= 5; i++)
		//	TF2_RemoveWeaponSlot(client, i);
		//ClientCommand(client, "slot3");
		
		TF2_RemoveAllWeapons(client);
		TF2Items_GiveWeapon(client, g_iWeaponIndex);
		
		// TODO: Set slot?
	}
}

stock EnableResupply()
{
	new iRegenerate = -1;
	while ((iRegenerate = FindEntityByClassname(iRegenerate, "func_regenerate")) != -1)
		AcceptEntityInput(iRegenerate, "Enable");
}

stock DisableResupply() 
{
	new iRegenerate = -1;
	while ((iRegenerate = FindEntityByClassname(iRegenerate, "func_regenerate")) != -1)
		AcceptEntityInput(iRegenerate, "Disable");
}


