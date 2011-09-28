
#include <tf2items_giveweapon>
#include <sdkhooks>
#include "common_utils"

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


public OnPluginStart()
{
	RegAdminCmd("sm_testufo", Command_TestUFO, ADMFLAG_ROOT);
	
	InitializeUFOs();
}


public OnMapStart()
{

}

public OnClientDisconnect(client)
{
	OnUFODisconnect(client);
}



