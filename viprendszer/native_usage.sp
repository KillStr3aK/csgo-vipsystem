#include <sourcemod>
#include <viprendszer>
#include <nexd>

#define PLUGIN_NEV	"Vipsystem natives usage"
#define PLUGIN_LERIAS	"-"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0"
#define PLUGIN_URL	"https://github.com/KillStr3aK"
#pragma tabsize 0

public Plugin myinfo = 
{
	name = PLUGIN_NEV,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_LERIAS,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vip", Command_Vip);
	RegConsoleCmd("sm_addvip", Command_AddVip);
	RegConsoleCmd("sm_delvip", Command_DelVip);
}

public Action Command_Vip(int client, int args)
{
	if(VR_Jogosultsag(view_as<Jatekos>(client)) == VIP)
	{
		PrintToChat(client, "You've got vip");
	}
}

public Action Command_AddVip(int client, int args)
{
	if(args != 3)
	{
		PrintToChat(client, "Usage: !addvip targetname | 1 or 2 (1 vip, 2 premium) | months");
		return Plugin_Handled;
	}

	char cArgs[4][32];
	for (int i = 1; i <= 3; ++i)
	{
		GetCmdArg(i, cArgs[i], sizeof(cArgs[]));
	}

	Jatekos target = view_as<Jatekos>(FindTarget(client, cArgs[1], true));

	if(!target.IsValid || !IsValidClient(client)) return Plugin_Handled;

	VR_Hozzaadas(view_as<Jatekos>(client), target, view_as<Jog>(StringToInt(cArgs[2])), StringToInt(cArgs[3]));

	return Plugin_Handled;
}

public Action Command_DelVip(int client, int args)
{
	if(args != 1)
	{
		PrintToChat(client, "Usage: !delvip targetname");
		return Plugin_Handled;
	}

	char cArgs[MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs, sizeof(cArgs));

	char cSteamID[20];
	GetClientAuthId(FindTarget(client, cArgs, true), AuthId_Steam2, cSteamID, sizeof(cSteamID));
	VR_Elvetel(cSteamID);

	return Plugin_Handled;
}