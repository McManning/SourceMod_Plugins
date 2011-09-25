
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include "rmf/tf2_codes" // bunch of useful stuff

#pragma semicolon 1

#define PLUGIN_NAME		"[TF2] Jar of Bees"
#define PLUGIN_AUTHOR		"Chase (Adapted from FlaminSarge)"
#define PLUGIN_VERSION		"1.0"
#define PLUGIN_CONTACT		"http://sybolt.com"
#define PLUGIN_DESCRIPTION	"Throw a Jar of Bees at people."

public Plugin:myinfo = {
	name			= PLUGIN_NAME,
	author			= PLUGIN_AUTHOR,
	description	= PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url				= PLUGIN_CONTACT
};

new Float:cvar_beejarduration;
new pBeeJar[MAXPLAYERS + 1];
new pJarated[MAXPLAYERS + 1];
new pBeesEntity[MAXPLAYERS + 1][5];

public OnPluginStart()
{
	new Handle:beejartime = CreateConVar("beejar_duration", "10.0", "Duration of the bleed effect", FCVAR_PLUGIN);
	RegAdminCmd("sm_beejar", Cmd_BeeJar, ADMFLAG_CHEATS, "sm_beejar <target> <0/1>");
	
	HookConVarChange(beejartime, cvhook_beejartime);
	cvar_beejarduration = GetConVarFloat(beejartime);
	
	LoadTranslations("common.phrases");
	
	HookUserMessage(GetUserMessageId("PlayerJarated"), Event_PlayerJarated);
	HookUserMessage(GetUserMessageId("PlayerJaratedFade"), Event_PlayerJaratedFade);
	
	HookEvent("player_hurt", Event_PlayerHurt);
	
	HookEvent("post_inventory_application", EventInventoryApplication,  EventHookMode_Post);
}

public EventInventoryApplication(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidEntity(client))
	{
		for (new t = 0; t < 5; t++)
		{
			if (pBeesEntity[client][t] != -1)
			{
				AcceptEntityInput(pBeesEntity[client][t], "stop");
				AcceptEntityInput(pBeesEntity[client][t], "Kill");

				pBeesEntity[client][t] = -1;
		//		RemoveEdict(particle);
			}
		}
	}
}

public cvhook_beejartime(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_beejarduration = GetConVarFloat(cvar); }
public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new weapon = GetEventInt(event, "weaponid");
	if (weapon == TF_WEAPON_SNIPERRIFLE && (TF2_GetPlayerConditionFlags(client) & TF_CONDFLAG_JARATED))
	{
		pJarated[client] = true;
	}
}
public Action:Event_PlayerJaratedFade(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	BfReadByte(bf); //client
	new victim = BfReadByte(bf);
	pJarated[victim] = false;
}
public Action:Event_PlayerJarated(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	new client = BfReadByte(bf);
	new victim = BfReadByte(bf);
	if (pBeeJar[client])
	{
		new jar = GetPlayerWeaponSlot(client, 1);
		if (jar != -1 && GetEntProp(jar, Prop_Send, "m_iItemDefinitionIndex") == 58)
		{
			if (!pJarated[victim]) CreateTimer(0.0, Timer_NoPiss, any:victim);	//TF2_RemoveCondition(victim, TFCond_Jarated);
//			if (!(TF2_GetPlayerConditionFlags(victim) & TF_CONDFLAG_JARATED)) CreateTimer(0.1, Timer_NoPiss, any:victim);
			TF2_MakeBleed(victim, client, cvar_beejarduration);
			
			for (new i = 0; i < 5; i++)
			{
				// if we don't already have bees, add them.
				if (pBeesEntity[victim][i] == -1)
					pBeesEntity[victim][i] = AttachLoopParticleBone(victim, "superrare_flies", "head");
			}
			
			CreateTimer(cvar_beejarduration, Timer_RemoveBees, any:victim);
		}
		else pJarated[victim] = true;
	}
	else pJarated[victim] = true;
	return Plugin_Continue;
}
public Action:Timer_NoPiss(Handle:timer, any:victim) 
{
	TF2_RemoveCondition(victim, TFCond_Jarated);
}

public Action:Timer_RemoveBees(Handle:timer, any:victim)
{
	for (new t = 0; t < 5; t++)
	{
		if (pBeesEntity[victim][t] != -1)
		{
			AcceptEntityInput(pBeesEntity[victim][t], "stop");
			AcceptEntityInput(pBeesEntity[victim][t], "Kill");

			pBeesEntity[victim][t] = -1;
	//		RemoveEdict(particle);
		}
	}
}

public OnMapStart()
{
	for (new i = 1; i < MaxClients; i++)
	{
		pBeeJar[i] = false;
		pJarated[i] = false;
		
		for (new t = 0; t < 5; t++)
			pBeesEntity[i][t] = -1;
	}
}
public OnClientPutInServer(client)
{
	pBeeJar[client] = false;
	pJarated[client] = false;
	
	for (new t = 0; t < 5; t++)
		pBeesEntity[client][t] = -1;
}
public OnClientDisconnect_Post(client)
{
	pBeeJar[client] = false;
	pJarated[client] = false;

	for (new t = 0; t < 5; t++)
		pBeesEntity[client][t] = -1;
}
public Action:Cmd_BeeJar(client, args)
{
	decl String:arg1[32];
	decl String:arg2[32];
	new beejaronoff = 0;

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	if (args != 2)
	{
		ReplyToCommand(client, "Usage: sm_beejar <target> <1/0>");
		return Plugin_Handled;
	}

	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;		
	if ((target_count = ProcessTargetString(
		arg1,
		client,
		target_list,
		MAXPLAYERS,
		COMMAND_FILTER_CONNECTED,
		target_name,
		sizeof(target_name),
		tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	beejaronoff = StringToInt(arg2);
	for (new i = 0; i < target_count; i++)
	{
		if(beejaronoff == 1)
		{
			pBeeJar[target_list[i]] = true;
		}
		if(beejaronoff == 0)
		{
			pBeeJar[target_list[i]] = false;
		}
		LogAction(client, target_list[i], "\"%L\" Set Bee Jar for  \"%L\" to (%i)", client, target_list[i], beejaronoff);	
	}

	if(tn_is_ml)
	{
		ShowActivity2(client, "[SM] ","Set Bee Jar For %t to %d", target_name, beejaronoff);
	}
	else
	{
		ShowActivity2(client, "[SM] ","Set Bee Jar For %s to %d", target_name, beejaronoff);
	}
	return Plugin_Handled;
}