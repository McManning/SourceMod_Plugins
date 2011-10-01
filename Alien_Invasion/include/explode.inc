

#if defined _EXPLODE_INC_
#endinput
#endif
#define _EXPLODE_INC_

#include <tf2_stocks>

#define SOUND_EXPLOSION "items/cart_explode.wav"

#define EFFECT_EXPLODE_EMBERS "cinefx_goldrush_embers"
#define EFFECT_EXPLODE_DEBRIS "cinefx_goldrush_debris"
#define EFFECT_EXPLODE_INITIAL_SMOKE "cinefx_goldrush_initial_smoke"
#define EFFECT_EXPLODE_FLAMES "cinefx_goldrush_flames"
#define EFFECT_EXPLODE_FLASH "cinefx_goldrush_flash"
#define EFFECT_EXPLODE_BURNINGDEBIS "cinefx_goldrush_burningdebris"
#define EFFECT_EXPLODE_SMOKE "cinefx_goldrush_smoke"
#define EFFECT_EXPLODE_HUGEDUSTUP "cinefx_goldrush_hugedustup"

stock PrePlayParticle(String:particlename[])
{
	if (IsValidEntity(0))
	{
	    new particle = CreateEntityByName("info_particle_system");
	    if (IsValidEdict(particle))
	    {
			new String:tName[32];
			GetEntPropString(0, Prop_Data, "m_iName", tName, sizeof(tName));
			DispatchKeyValue(particle, "targetname", "tf2particle");
			DispatchKeyValue(particle, "parentname", tName);
			DispatchKeyValue(particle, "effect_name", particlename);
			DispatchSpawn(particle);
			SetVariantString(tName);
			AcceptEntityInput(particle, "SetParent", 0, particle, 0);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			CreateTimer(0.01, RemoveParticle, particle);
	    }
	}
}

stock ShowParticle(String:particlename[], Float:time, Float:pos[3], Float:ang[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
	}	
}


public Action:RemoveParticle( Handle:timer, any:particle )
{
    if ( IsValidEntity( particle) )
    {
        new String:classname[32];
        GetEdictClassname(particle, classname, sizeof(classname));
        if (StrEqual(classname, "info_particle_system", false))
        {
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "Kill");
			particle = -1;
        }
    }
}

stock ExplodeEffect(Float:vPos[3])
{
	EmitSoundToAll(SOUND_EXPLOSION, _, _, _, SND_CHANGEPITCH, 1.0, 200, -1, vPos);
	new Float:ang[3];
	ang[0] = -90.0;
	ang[1] = 0.0;
	ang[2] = 0.0;

	ShowParticle(EFFECT_EXPLODE_EMBERS, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_DEBRIS, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_INITIAL_SMOKE, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_FLAMES, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_FLASH, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_BURNINGDEBIS, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_SMOKE, 5.0, vPos, ang);
	ShowParticle(EFFECT_EXPLODE_HUGEDUSTUP, 5.0, vPos, ang);
}

public ExplodeEffectOnClient(client)
{
	new Float:vPos[3];
	GetClientAbsOrigin(client, vPos);
	ExplodeEffect(vPos);
}

public PreloadExplodeEffect()
{
	PrePlayParticle(EFFECT_EXPLODE_EMBERS);
	PrePlayParticle(EFFECT_EXPLODE_DEBRIS);
	PrePlayParticle(EFFECT_EXPLODE_INITIAL_SMOKE);
	PrePlayParticle(EFFECT_EXPLODE_FLAMES);
	PrePlayParticle(EFFECT_EXPLODE_FLASH);
	PrePlayParticle(EFFECT_EXPLODE_BURNINGDEBIS);
	PrePlayParticle(EFFECT_EXPLODE_SMOKE);
	PrePlayParticle(EFFECT_EXPLODE_HUGEDUSTUP);

	PrecacheSound(SOUND_EXPLOSION, true);
}


