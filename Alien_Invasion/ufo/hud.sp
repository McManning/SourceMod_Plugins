
// Notification codes for UFO players
enum UFONotification
{
	UFO_NOTIFY_NONE = 0,
	UFO_NOTIFY_LOOKDOWN, /**< Triggered when they try to fire a weapon in an invalid direction **/
	UFO_NOTIFY_TOOLOW /**< When the UFO has gotten too close to the ground and has to pull up */
};

new UFONotification:g_UFONotifyCode[MAXPLAYERS+1];

SetUFONotification(client, UFONotification:notifycode)
{
	g_UFONotifyCode[client] = notifycode;
}

/**
 * If there's any pending notifications for UFOs, print them out 
 */
CheckUFONotifications(client)
{
	/// @todo Better alerts
	switch (g_UFONotifyCode[client])
	{
		case UFO_NOTIFY_LOOKDOWN:
			PrintUFONoticeHud(client, "You need to look down to fire that weapon!"); 
		case UFO_NOTIFY_TOOLOW:
			PrintUFONoticeHud(client, "WARNING: Too low! Pull UP!"); 
	}
	
	g_UFONotifyCode[client] = UFO_NOTIFY_NONE;
}

/**
 * Updates the HUD display of the client's UFO 
 * @param client 
 * @param health The new health (health <= maxhealth)
 */
PrintUFOHealthHud(client, health, maxhealth)
{
	decl String:buffer[64];
	Format(buffer, sizeof(buffer), "Health: %d/%d", health, maxhealth);
	
	SendHudMsg(client, 1, 0.01, 0.5, 
                    255, 0, 0, 255, 
                    255, 0, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    65535.0, 0.0, /// @todo proper "forever" display time 
                    buffer
			);
}

PrintUFOHelpHud(client)
{
	decl String:buffer[64];
	Format(buffer, sizeof(buffer), "[w] Accelerate, [a] Ascend, [d] Descend");
	
	SendHudMsg(client, 2, 0.01, 0.45, 
                    0, 255, 0, 255, 
                    0, 255, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    120.0, 0.0, 
                    buffer
			);
}

/// @todo after a while, this just stops working?
PrintUFONoticeHud(client, String:notice[])
{
	PrintToChat(client, notice);
	SendHudMsg(client, 3, -1.0, -1.0, 
                    255, 0, 0, 255, 
                    255, 0, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    5.0, 0.0, 
                    notice
			);
}

PrintInvasionCountdown(client, Float:timeleft)
{
	decl String:buffer[64];
	Format(buffer, sizeof(buffer), "UFO Conquest In: %.0f", timeleft);
	
	SendHudMsg(client, 4, 0.01, 0.03, 
                    255, 0, 0, 255, 
                    255, 0, 0, 255, 
                    0, 
                    0.0, 1.0, 
                    2.0, 0.0,
                    buffer
			);
}

