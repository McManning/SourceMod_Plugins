
#if defined _COMMON_UTILS_INC_
#endinput
#endif
#define _COMMON_UTILS_INC_

#include <tf2_stocks>

#define COLORIZE_INVIS {255,255,255,0}
#define COLORIZE_NORMAL {255,255,255,255}

#pragma semicolon 1

/*
Credit to pheadxdll for invisibility code.
*/
public ColorizeEquipment(client, color[4])
{
	//Colorize the weapons
	new m_hMyWeapons = FindSendPropOffs("CBasePlayer", "m_hMyWeapons");	
	decl String:classname[64];
	//new TFClassType:class = TF2_GetPlayerClass(client);
	
	for(new i = 0, weapon; i < 47; i += 4) // Where are these numbers from?
	{
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);
		
		if (weapon > 0 && IsValidEdict(weapon))
		{
			if (GetEdictClassname(weapon, classname, sizeof(classname)) && StrContains(classname, "weapon", false) != 0)
			{
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, color[0], color[1], color[2], color[3]);
			}
		}
	}
	
	//Colorize the wearables, such as hats
	SetWearablesRGBA_Impl( client, RENDER_TRANSCOLOR, "tf_wearable", "CTFWearable",color );
	SetWearablesRGBA_Impl( client, RENDER_TRANSCOLOR, "tf_wearable_demoshield", "CTFWearableDemoShield", color);

	/*
	if(color[3] > 0)
	type = 1;
	
	InvisibleHideFixes(client, class, type);*/
	
	return;
}

SetWearablesRGBA_Impl( client, RenderMode:mode, const String:entClass[], const String:serverClass[], color[4])
{
	new ent = -1;
	while( (ent = FindEntityByClassname(ent, entClass)) != -1 )
	{
		if ( IsValidEntity(ent) )
		{		
			if (GetEntDataEnt2(ent, FindSendPropOffs(serverClass, "m_hOwnerEntity")) == client)
			{
				SetEntityRenderMode(ent, mode);
				SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);
			}
		}
	}
}

/*
InvisibleHideFixes(client, TFClassType:classtype, type)
{
	if(classtype == TFClass_DemoMan)
	{
		new decapitations = GetEntProp(client, Prop_Send, "m_iDecapitations");
		if(decapitations >= 1)
		{
			if(!type)
			{
				//Removes Glowing Eye
				//TF2_RemoveCondition(client, 18);
			}
			else
			{
				//Add Glowing Eye
				//TF2_AddCondition(client, 18);
			}
		}
	}
	else if(classtype == TFClass_Spy)
	{
		new disguiseWeapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
		if(IsValidEntity(disguiseWeapon))
		{
			if(!type)
			{
				SetEntityRenderMode(disguiseWeapon , RENDER_TRANSCOLOR);
				new color[4] = COLORIZE_INVIS;
				SetEntityRenderColor(disguiseWeapon , color[0], color[1], color[2], color[3]);
			}
			else
			{
				SetEntityRenderMode(disguiseWeapon , RENDER_TRANSCOLOR);
				new color[4] = COLORIZE_NORMAL;
				SetEntityRenderColor(disguiseWeapon , color[0], color[1], color[2], color[3]);
			}
		}
	}
}
*/
