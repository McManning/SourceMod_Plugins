
/**
 *	@brief Generic Boss Battle framework
 *	@author Chase McManning
 */

#if defined _BOSS_BATTLE_INC_
#endinput
#endif
#define _BOSS_BATTLE_INC_

/// Win/Lose conditions for bosses and defenders (interchangeable)
enum BossCond 
{
	BossCond_Unknown = 0,
	BossCond_TimeUp, /**< Timer triggered boss or defenders win */
	BossCond_NoneRemain, /**< Boss defeated all defenders, or all bosses were defeated */
	BossCond_ObjectiveComplete /**< Boss or defenders completed a particular objective */
};

/// If a boss is killed, generic reason as to why
enum BossDeath
{
	BossDeath_Unknown = 0,
	BossDeath_Slayed,
	
	/// @todo Necessary? Let individual plugins handle this on case-by-case. 
	BossDeath_Idle /**< Boss player went idle too long */
};


new Handle:g_fwdOnBossSpawn = INVALID_HANDLE;
new Handle:g_fwdOnBossDeath = INVALID_HANDLE;
new Handle:g_fwdOnBossWin = INVALID_HANDLE;
new Handle:g_fwdOnBossLose = INVALID_HANDLE;

public CreateBossForwards()
{
	if ((g_fwdOnBossSpawn = CreateGlobalForward("OnBossSpawn", 
		ET_Ignore, Param_Cell)) == INVALID_HANDLE)
		PrintToServer("Failed to create OnBossSpawn forward");
		
	if ((g_fwdOnBossDeath = CreateGlobalForward("OnBossDeath", 
		ET_Ignore, Param_Cell, Param_Cell)) == INVALID_HANDLE)
		PrintToServer("Failed to create OnBossDeath forward");
		
	if ((g_fwdOnBossWin = CreateGlobalForward("OnBossWin", 
		ET_Ignore, Param_Cell)) == INVALID_HANDLE)
		PrintToServer("Failed to create OnBossWin forward");
		
	if ((g_fwdOnBossLose = CreateGlobalForward("OnBossLose", 
		ET_Ignore, Param_Cell)) == INVALID_HANDLE)
		PrintToServer("Failed to create OnBossLose forward");
}

/**
 * Executes forward OnBossSpawn(client)
 * @param client the client designated as a boss
 */
public ExecuteForward_OnBossSpawn(client)
{
	if (g_fwdOnBossSpawn != INVALID_HANDLE)
	{
		Call_StartForward(g_fwdOnBossSpawn);
		Call_PushCell(client);
		Call_Finish();	
	}
}

/**
 * Executes forward OnBossDeath(client, BossDeath:reason)
 * @param reason a BossDeath detailing why this particular boss has died
 */
public ExecuteForward_OnBossDeath(client, BossDeath:reason)
{
	if (g_fwdOnBossDeath != INVALID_HANDLE)
	{
		Call_StartForward(g_fwdOnBossDeath);
		Call_PushCell(client);
		Call_PushCell(reason);
		Call_Finish();	
	}
}

/**
 * Executes when bosses meet win conditions
 * Executes forward OnBossWin(BossCond:reason)
 * @param reason a BossCond detailing why the bosses have won
 */
public ExecuteForward_OnBossWin(BossCond:reason)
{
	if (g_fwdOnBossWin != INVALID_HANDLE)
	{
		Call_StartForward(g_fwdOnBossWin);
		Call_PushCell(reason);
		Call_Finish();	
	}
}

/**
 * Executes when no bosses remain. 
 * Executes forward OnBossLose(BossCond:reason)
 * @param reason a BossCond detailing why the bosses have lost
 */
public ExecuteForward_OnBossLose(BossCond:reason)
{
	if (g_fwdOnBossLose != INVALID_HANDLE)
	{
		Call_StartForward(g_fwdOnBossLose);
		Call_PushCell(reason);
		Call_Finish();	
	}
}


/// @todo Watch designated boss clients and force events based on their death/disconnection?








