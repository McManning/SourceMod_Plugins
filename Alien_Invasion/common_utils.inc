
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

// "HudMsg" message
stock SendHudMsg(client, channel, 
                    Float:x, Float:y, 
                    aRclr, aGclr, aBclr, aTclr, 
                    bRclr, bGclr, bBclr, bTclr, 
                    effect, 
                    Float:fadein, Float:fadeout, 
                    Float:holdtime, Float:fxtime, 
                    const String:szMsg[])
{
	new Handle:hBf;
	
	if (!client)
		hBf = StartMessageAll("HudMsg");
	else 
		hBf = StartMessageOne("HudMsg", client);
	
	if (hBf != INVALID_HANDLE)
	{
		BfWriteByte(hBf, channel); //channel
		BfWriteFloat(hBf, x); // x ( -1 = center )
		BfWriteFloat(hBf, y); // y ( -1 = center )
		// second color
		BfWriteByte(hBf, aRclr); //r1
		BfWriteByte(hBf, aGclr); //g1
		BfWriteByte(hBf, aBclr); //b1
		BfWriteByte(hBf, aTclr); //a1 // transparent?
		// init color
		BfWriteByte(hBf, bRclr); //r2
		BfWriteByte(hBf, bGclr); //g2
		BfWriteByte(hBf, bBclr); //b2
		BfWriteByte(hBf, bTclr); //a2
		BfWriteByte(hBf, effect); //effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
		BfWriteFloat(hBf, fadein); //fadeinTime (message fade in time - per character in effect 2)
		BfWriteFloat(hBf, fadeout); //fadeoutTime
		BfWriteFloat(hBf, holdtime); //holdtime
		BfWriteFloat(hBf, fxtime); //fxtime (effect type(2) used)
		BfWriteString(hBf, szMsg); //Message
		EndMessage();
	}
}

