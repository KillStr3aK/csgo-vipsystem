#include <sourcemod>
#include <viprendszer>
#include <nexd>

#define PLUGIN_NEV	"Viprendszer"
#define PLUGIN_LERIAS	"PRIVÁT:("
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0.0915"
#define PLUGIN_URL	"https://github.com/KillStr3aK"
#pragma tabsize 0

enum {
	CEnum_Config,
	CEnum_Extra,
	CEnum_Premium,
	CEnum_VipFlag,
	CEnum_PremFlag,
	CEnum_Count
}

int m_iCelpont[MAXPLAYERS+1] = 0;
int t_iIdo[MAXPLAYERS+1] = 0;

int g_iFlags[Jog][20];
int g_iFlagCount[Jog] = 0;

char cTarget[MAXPLAYERS+1][20];

bool b_iHosszabbit[MAXPLAYERS+1] = false;

Jog jog[MAXPLAYERS+1] = Semmi;
Jog m_iJogTipus[MAXPLAYERS+1] = Semmi;

Database g_DB;
ConVar g_vR[CEnum_Count];

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
	RegAdminCmd("sm_vipadmin", Command_VipAdmin, ADMFLAG_ROOT);
	RegConsoleCmd("sm_vip", Command_Vip);

	g_vR[CEnum_Config] = CreateConVar("vip_adatbazis", "viprendszer", "databases.cfg-ben a szekció neve");
	g_vR[CEnum_Extra] = CreateConVar("vip_extrak", "0", "Legyenek-e bekapcsolva az extra dolgok");
	g_vR[CEnum_Premium] = CreateConVar("vip_premium", "0", "A prémium jog bekapcsolása");
	g_vR[CEnum_VipFlag] = CreateConVar("vip_flag", "0 20", "Extra jogok");
	g_vR[CEnum_PremFlag] = CreateConVar("vip_prem_flag", "0 2 9 20", "Extra jogok");
	AutoExecConfig(true, "ks_viprendszer", "sourcemod");
}

public void OnConfigsExecuted()
{
	char cError[255];
	char cDatabase[32];
	g_vR[CEnum_Config].GetString(cDatabase, sizeof(cDatabase));
	g_DB = SQL_Connect(cDatabase, true, cError, sizeof(cError));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `viprendszer` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`hozzaadva` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \
  		`jatekosnev` varchar(36) COLLATE utf8_bin NOT NULL, \
  		`steamid` varchar(20) COLLATE utf8_bin NOT NULL, \
  		`lejar` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00', \
  		`adminnev` varchar(36) COLLATE utf8_bin NOT NULL, \
  		`adminsteamid` varchar(20) COLLATE utf8_bin NOT NULL, \
  		`jogosultsag` varchar(20) COLLATE utf8_bin NOT NULL, \
 		 PRIMARY KEY (`ID`), \
  		 UNIQUE KEY `steamid` (`steamid`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	for (int i = 0; i < 3; ++i)
	{
		g_iFlagCount[i] = 0;
	}

	char cVipFlags[256];
	char cPremFlags[256];

	g_vR[CEnum_VipFlag].GetString(cVipFlags, sizeof(cVipFlags));
	if(g_vR[CEnum_Premium].IntValue == 1) g_vR[CEnum_PremFlag].GetString(cPremFlags, sizeof(cPremFlags));

	char cJogok[Jog][20][6];

	for (int k = 1; k < 3; ++k)
	{
		for (int i = 0; i < sizeof(cJogok[]); i++){
			strcopy(cJogok[k][i], sizeof(cJogok[][]), "");
			if(view_as<Jog>(k) == VIP) ExplodeString(cVipFlags, " ", cJogok[k], sizeof(cJogok[]), sizeof(cJogok[][]));
			else if(view_as<Jog>(k) == PREMIUM && g_vR[CEnum_Premium].IntValue == 1) ExplodeString(cPremFlags, " ", cJogok[k], sizeof(cJogok[]), sizeof(cJogok[][]));
		}
	}

	for (int j = 1; j < 3; ++j)
	{
		for (int i = 0; i < sizeof(cJogok); i++) {
			if(StrEqual(cJogok[j][i], ""))
				continue;

			g_iFlags[j][g_iFlagCount[j]++] = StringToInt(cJogok[j][i]);
		}
	}

	Frissites();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("VR_Jogosultsag", Native_Jogosultsag);
	CreateNative("VR_Hozzaadas", Native_Hozzaadas);
	CreateNative("VR_Elvetel", Native_Elvetel);
	return APLRes_Success;
}

public Action Command_Vip(int client, int args)
{
	if(Jogosultsag(view_as<Jatekos>(client)) != Semmi) PreVipMenu(view_as<Jatekos>(client));
	else PrintToChat(client, "%s Nincs hozzáférésed ehhez a parancshoz!", PREFIX);
}

public Action Command_VipAdmin(int client, int args)
{
	AdminMenu(view_as<Jatekos>(client));
}

stock Action PreVipMenu(Jatekos jatekos)
{
	if (Jogosultsag(jatekos) != Semmi) {
		char steamid[20];
		GetClientAuthId(jatekos.index, AuthId_Steam2, steamid, sizeof(steamid));
		char Query[1024];
		Format(Query, sizeof(Query), "SELECT hozzaadva,lejar,DATEDIFF(lejar, NOW()) as timeleft,jogosultsag FROM viprendszer WHERE steamid = '%s';", steamid);
		SQL_TQuery(g_DB, VipMenu, Query, jatekos.index);
	} else {
		PrintToChat(jatekos.index, "%s Nem vagy VIP!", PREFIX);
	}

	return Plugin_Handled;
}

public void VipMenu(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	char cLejar[128];
	char cHozzaadva[128];
	char cETA[64];
	char cJog[10];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, cHozzaadva, sizeof(cHozzaadva));
		SQL_FetchString(hndl, 1, cLejar, sizeof(cLejar));
		SQL_FetchString(hndl, 2, cETA, sizeof(cETA));
		SQL_FetchString(hndl, 3, cJog, sizeof(cJog));
	}
	
	Menu menu = CreateMenu(VipMenuCallback);
	char sor[256];
	Format(sor, sizeof(sor), "Lejár: %s (%s nap múlva)", cLejar, cETA);
	SetMenuTitle(menu, "VIP MENÜ\n%s", sor);
	Format(sor, sizeof(sor), "Jogosultság: %s", cJog);
	menu.AddItem("", sor, ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("ugras", "Ugrások");
	menu.AddItem("aji", "Napi ajándék");
	menu.AddItem("ert", "Láda értesítések");
	menu.AddItem("chat", "Chat beállítások");
	menu.Display(jatekos.index, 60);
}

public int VipMenuCallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if(menuaction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		if (StrEqual(info, "ugras"))
		{
			ClientCommand(client, "sm_ugras");
		}
		if (StrEqual(info, "aji")) {
			ClientCommand(client, "sm_napi");
		}
		if (StrEqual(info, "ert")) {
			ClientCommand(client, "sm_vipertpari");
		}
		if (StrEqual(info, "chat")) {
			ClientCommand(client, "sm_elotag");
		}
	}
}

stock void AdminMenu(Jatekos jatekos)
{
	Menu menu = CreateMenu(AdminMenuCallback);
	menu.SetTitle("ADMIN MENÜ\nsteelclouds.clans.hu\n%s", PLUGIN_VERSION);
	menu.AddItem("hozz", "Hozzáadás");
	menu.AddItem("list", "Lista");
	menu.Display(jatekos.index, 20);
}

public int AdminMenuCallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if (menuaction == MenuAction_Select) {
		char info[10];
		GetMenuItem(menu, item, info, sizeof(info));
		JatekosAdminMenuCallback(view_as<Jatekos>(client), info);
	}
}

public void JatekosAdminMenuCallback(Jatekos jatekos, char[] menupont)
{
	if(StrEqual(menupont, "hozz"))
	{
		if(GetNotVipsCount() != 0)
		{
			m_iJogTipus[jatekos.index] = Semmi;
			HozzaadasMenu(jatekos);
		} else {
			PrintToChat(jatekos.index, "%s Vagy nincs fent senki, vagy mindenkinek van már jogosultsága.", PREFIX);
		}
	} else if(StrEqual(menupont, "list"))
	{
		PreJogosultLista(jatekos);
	}
}

stock void HozzaadasMenu(Jatekos jatekos)
{
	if(g_vR[CEnum_Premium].IntValue == 1)
	{
		Menu menu = CreateMenu(TipusCallback);
		menu.SetTitle("Válaszd ki milyen jogot szeretnél kiosztani");
		menu.AddItem("vip", "VIP");
		menu.AddItem("prem", "Prémium");
		menu.Display(jatekos.index, 20);
	} else {
		m_iJogTipus[jatekos.index] = VIP;
		JatekosLista(jatekos);
	}
}

public int TipusCallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if(menuaction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		if(StrEqual(info, "vip")) m_iJogTipus[client] = VIP;
		else if(StrEqual(info, "prem")) m_iJogTipus[client] = PREMIUM;

		JatekosLista(Jatekos(client));
	}
}

stock void JatekosLista(Jatekos jatekos)
{
	char jatekosnev[MAX_NAME_LENGTH+1];
	char jatekosid[10];
	Menu menu = CreateMenu(Jatekoslistacallback);
	menu.SetTitle("Válassz játékost");
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i)) continue;

		if(jog[i] != Semmi) continue;

		GetClientName(i, jatekosnev, sizeof(jatekosnev));
		IntToString(i, jatekosid, sizeof(jatekosid));
		menu.AddItem(jatekosid, jatekosnev);
	}

	menu.Display(jatekos.index, 60);
}

public int Jatekoslistacallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if(menuaction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		m_iCelpont[client] = StringToInt(info);
		t_iIdo[client] = m_iCelpont[client] - m_iCelpont[client];
		Idomenu(Jatekos(client));
	}
}

stock void Idomenu(Jatekos jatekos)
{
	Menu menu = CreateMenu(IdoMenuCallback);
	menu.SetTitle("Mennyi időre szeretnéd adni?");
	menu.AddItem("1", "1 hónap");
	menu.AddItem("2", "2 hónap");
	menu.AddItem("3", "3 hónap");
	menu.AddItem("4", "4 hónap");
	menu.AddItem("5", "5 hónap");
	menu.AddItem("6", "6 hónap");
	menu.AddItem("7", "7 hónap");
	menu.AddItem("8", "8 hónap");
	menu.AddItem("9", "9 hónap");
	menu.AddItem("10", "10 hónap");
	menu.AddItem("11", "11 hónap");
	menu.AddItem("12", "12 hónap");
	menu.Display(jatekos.index, 60);
}

public int IdoMenuCallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if(menuaction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		t_iIdo[client] = StringToInt(info);
		if(!b_iHosszabbit[client]) Biztosmenu(Jatekos(client));
		else {
			Hosszabbitas(view_as<Jatekos>(client), cTarget[client], t_iIdo[client]);
			b_iHosszabbit[client] = false;
		}
	}
}

public void Biztosmenu(Jatekos jatekos)
{
	char sor[256];
	Menu menu = CreateMenu(Biztosmenucallback);
	menu.SetTitle("Biztos hozzá szeretnéd adni?");
	Format(sor, sizeof(sor), "Játékos: %N", m_iCelpont[jatekos.index]);
	menu.AddItem("", sor, ITEMDRAW_DISABLED);
	Format(sor, sizeof(sor), "Jogosultság: %s", m_iJogTipus[jatekos.index] == VIP?"VIP":"Prémium");
	menu.AddItem("", sor, ITEMDRAW_DISABLED);
	Format(sor, sizeof(sor), "Időtartam: %i hónap", t_iIdo[jatekos.index]);
	menu.AddItem("", sor, ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("yup", "Igen");
	menu.AddItem("nope", "Mégse");
	menu.Display(jatekos.index, 60);
}

public int Biztosmenucallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if(menuaction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		if(StrEqual(info, "yup"))
		{
			JogAdas(view_as<Jatekos>(client), view_as<Jatekos>(m_iCelpont[client]), m_iJogTipus[client], t_iIdo[client]);
		} else if(StrEqual(info, "nope"))
		{
			Reset(view_as<Jatekos>(client));
			PrintToChat(client, "%s Megszakítottad a hozzáadást.", PREFIX);
		}
	}
}

public void Hosszabbitas(Jatekos admin, char[] steamid, int honap) {
	if(view_as<Jatekos>(GetClientFromSteamID(steamid)).IsValid)
	{
		char jatekosnev[MAX_NAME_LENGTH + 8];
		view_as<Jatekos>(GetClientFromSteamID(steamid)).GetName(jatekosnev, sizeof(jatekosnev));

		char cEscapedJatekosnev[MAX_NAME_LENGTH * 2 + 16];
		SQL_EscapeString(g_DB, jatekosnev, cEscapedJatekosnev, sizeof(cEscapedJatekosnev));
		
		char Query[1024];
		Format(Query, sizeof(Query), "UPDATE viprendszer SET lejar = DATE_ADD(lejar, INTERVAL %i MONTH) WHERE steamid = '%s';", honap, steamid);
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
		
		Format(Query, sizeof(Query), "UPDATE viprendszer SET jatekosnev = '%s' WHERE steamid = '%s';", cEscapedJatekosnev, steamid);
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
		
		PrintToChat(admin.index, "%s Meghosszabbítottad \x03%s \x01jogosultságát  <\x03%i \x01hónappal>", PREFIX, jatekosnev, honap);
		PrintToChat(view_as<Jatekos>(GetClientFromSteamID(steamid)).index, "%s Meghosszabbították a jogosultságodat %i hónappal!", PREFIX, honap);
	} else {
		char Query[1024];
		Format(Query, sizeof(Query), "UPDATE viprendszer SET lejar = DATE_ADD(lejar, INTERVAL %i MONTH) WHERE steamid = '%s';", honap, steamid);
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
		
		PrintToChat(admin.index, "%s Meghosszabbítottad \x03%s \x01jogosultságát  <\x03%i \x01hónappal>", PREFIX, steamid, honap);
	}
}

public void JogAdas(Jatekos admin, Jatekos celpont, Jog jogosultsag, int honap)
{
	char cAdminSteamID[20];
	if(admin.index != 0) admin.GetAuthId(AuthId_Steam2, cAdminSteamID, sizeof(cAdminSteamID));
	else strcopy(cAdminSteamID, sizeof(cAdminSteamID), "Rendszer");
	char cAdminNev[MAX_NAME_LENGTH+1];
	if(admin.index != 0) admin.GetName(cAdminNev, sizeof(cAdminNev));
	else strcopy(cAdminNev, sizeof(cAdminNev), "Rendszer");
	char cEscapedAdminName[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, cAdminNev, cEscapedAdminName, sizeof(cEscapedAdminName));
	
	char cSteamID[20];
	celpont.GetAuthId(AuthId_Steam2, cSteamID, sizeof(cSteamID));
	char jatekosnev[MAX_NAME_LENGTH + 8];
	celpont.GetName(jatekosnev, sizeof(jatekosnev));
	char cEscapedJatekosnev[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, jatekosnev, cEscapedJatekosnev, sizeof(cEscapedJatekosnev));
	
	char Query[4096];
	Format(Query, sizeof(Query), "INSERT IGNORE INTO `viprendszer` (`ID`, `hozzaadva`, `jatekosnev`, `steamid`, `lejar`, `adminnev`, `adminsteamid`, `jogosultsag`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', CURRENT_TIMESTAMP, '%s', '%s', '%s');", cEscapedJatekosnev, cSteamID, cEscapedAdminName, cAdminSteamID, jogosultsag == VIP?"VIP":"Prémium");
	SQL_TQuery(g_DB, SQLHibaKereso, Query);
	
	char Idofrissites[1024];
	Format(Idofrissites, sizeof(Idofrissites), "UPDATE viprendszer SET lejar = DATE_ADD(lejar, INTERVAL %i MONTH) WHERE steamid = '%s';", honap, cSteamID);
	SQL_TQuery(g_DB, SQLHibaKereso, Idofrissites);
	
	if(admin.index != 0) PrintToChat(admin.index, "%s Hozzáadtál egy új %s <\x03%s \x01| \x03%i \x03hónap\x01>", PREFIX, jogosultsag == VIP?"VIP-t":"Prémiumot", jatekosnev, honap);
	PrintToChat(celpont.index, "%s %s jogokat kaptál \x01 <\x03%i \x03 hónap\x01>", PREFIX, jogosultsag == VIP?"VIP":"Prémium", honap);
	Flagadas(celpont, jogosultsag);
}

public void Flagadas(Jatekos jatekos, Jog jogosultsag) {
	jog[jatekos.index] = jogosultsag;
	for (int i = 0; i < g_iFlagCount[jogosultsag]; i++) SetUserFlagBits(jatekos.index, GetUserFlagBits(jatekos.index) | (1 << g_iFlags[jogosultsag][i]));
}

public Action PreJogosultLista(Jatekos jatekos)
{
	char Query[1024];
	Format(Query, sizeof(Query), "SELECT jatekosnev,steamid FROM viprendszer WHERE NOW() < lejar;");
	SQL_TQuery(g_DB, JogosultLista, Query, jatekos.index);
}

public void JogosultLista(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	Menu menu = CreateMenu(JogListaCallback);
	menu.SetTitle("Jogosultságok");
	while (SQL_FetchRow(hndl)) {
		char steamid[20];
		char jatekosnev[MAX_NAME_LENGTH + 8];

		SQL_FetchString(hndl, 0, jatekosnev, sizeof(jatekosnev));
		SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

		menu.AddItem(steamid, jatekosnev);
	}

	menu.Display(jatekos.index, 60);
}

public int JogListaCallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if (menuaction == MenuAction_Select) {
		char info[20];
		GetMenuItem(menu, item, info, sizeof(info));
		JogAdminMenuCallback(view_as<Jatekos>(client), info);
		cTarget[client] = info;
	}
}

public void JogAdminMenuCallback(Jatekos jatekos, char[] valasztott)
{
	char Query[1024];
	Format(Query, sizeof(Query), "SELECT jatekosnev,steamid,jogosultsag,hozzaadva,lejar,DATEDIFF(lejar, NOW()) as timeleft,adminnev,adminsteamid FROM viprendszer WHERE steamid = '%s';", valasztott);
	SQL_TQuery(g_DB, JatekosReszlet, Query, jatekos.index);
}

public void JatekosReszlet(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	char sor[256];
	Menu menu = CreateMenu(JatekosReszletCallback);
	while(SQL_FetchRow(hndl)) {
		char steamid[20];
		char adminsteamid[20];

		char jatekosnev[MAX_NAME_LENGTH+1];
		char adminnev[MAX_NAME_LENGTH+1];

		char cJog[10];
		char cLejar[128];

		char cHozzaadva[128];
		char cETA[64];

		SQL_FetchString(hndl, 0, jatekosnev, sizeof(jatekosnev));
		SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

		SQL_FetchString(hndl, 2, cJog, sizeof(cJog));
		SQL_FetchString(hndl, 3, cHozzaadva, sizeof(cHozzaadva));

		SQL_FetchString(hndl, 4, cLejar, sizeof(cLejar));
		SQL_FetchString(hndl, 5, cETA, sizeof(cETA));

		SQL_FetchString(hndl, 6, adminnev, sizeof(adminnev));
		SQL_FetchString(hndl, 7, adminsteamid, sizeof(adminsteamid));

		Format(sor, sizeof(sor), "%s [ %s ]", jatekosnev, steamid);
		menu.SetTitle(sor);
		Format(sor, sizeof(sor), "Jogosultság: %s", cJog);
		menu.AddItem("", sor, ITEMDRAW_DISABLED);
		Format(sor, sizeof(sor), "Hozzáadta: %s [ %s ]", adminnev, adminsteamid);
		menu.AddItem("", sor, ITEMDRAW_DISABLED);
		Format(sor, sizeof(sor), "Hozzáadva: %s", cHozzaadva);
		menu.AddItem("", sor, ITEMDRAW_DISABLED);
		Format(sor, sizeof(sor), "Lejár: %s (%s nap múlva)", cLejar, cETA);
		menu.AddItem("", sor, ITEMDRAW_DISABLED);
	}

	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("elv", "Elvétel");
	menu.AddItem("hossz", "Hosszabbítás");
	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;
	menu.Display(jatekos.index, 60);
}

public void Elvetel(char[] steamid) {
	char Query[512];
	Format(Query, sizeof(Query), "DELETE FROM viprendszer WHERE steamid = '%s';", steamid);
	SQL_TQuery(g_DB, SQLHibaKereso, Query);
	Frissites();
}

public void Frissites() {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i))
			continue;

		Reset(view_as<Jatekos>(i));
		Ellenorzes(view_as<Jatekos>(i));
	}
}

public int JatekosReszletCallback(Menu menu, MenuAction menuaction, int client, int item)
{
	if (menuaction == MenuAction_Select) {
		char info[10];
		GetMenuItem(menu, item, info, sizeof(info));
		JatekosReszletMenuCallback(view_as<Jatekos>(client), info);
	}
}

public void JatekosReszletMenuCallback(Jatekos jatekos, char[] menupont)
{
	if(StrEqual(menupont, "elv"))
	{
		Elvetel(cTarget[jatekos.index]);
		PrintToChat(jatekos.index, "%s Sikeresen elvetted a játékos jogosultságát.", PREFIX);
	} else if(StrEqual(menupont, "hossz"))
	{
		b_iHosszabbit[jatekos.index] = true;
		Idomenu(jatekos);
	}
}

public void Reset(Jatekos jatekos)
{
	jog[jatekos.index] = Semmi;
	m_iJogTipus[jatekos.index] = Semmi;
	cTarget[jatekos.index] = "\0";
	m_iCelpont[jatekos.index] = 0;
	t_iIdo[jatekos.index] = 0;
	b_iHosszabbit[jatekos.index] = false;
}

public void OnClientPostAdminCheck(int client) {
	Reset(view_as<Jatekos>(client));
	char Query[256];
	Format(Query, sizeof(Query), "DELETE FROM viprendszer WHERE lejar < NOW();");
	SQL_TQuery(g_DB, SQLHibaKereso, Query);
	Ellenorzes(view_as<Jatekos>(client));
}

public void OnRebuildAdminCache(AdminCachePart APart) {
	if (APart == AdminCache_Admins)
		Frissites();
}

public void Ellenorzes(Jatekos jatekos) {
	char cSteamID[20];
	jatekos.GetAuthId(AuthId_Steam2, cSteamID, sizeof(cSteamID));
	char Query[1024];
	Format(Query, sizeof(Query), "SELECT jogosultsag FROM viprendszer WHERE steamid = '%s';", cSteamID);
	SQL_TQuery(g_DB, SQLEllenorzes, Query, jatekos.index);
}

public void SQLEllenorzes(Handle owner, Handle hndl, const char[] error, Jatekos jatekos) {
	if (jatekos.IsValid) {
		char cJog[10];
		Jog jogosultsag = Semmi;
		while (SQL_FetchRow(hndl)) {
			SQL_FetchString(hndl, 0, cJog, sizeof(cJog));
			if(StrEqual(cJog, "VIP")) jogosultsag = VIP;
			else if(StrEqual(cJog, "Prémium")) jogosultsag = PREMIUM;

			Flagadas(jatekos, jogosultsag);
		}
	}
}

public void SQLHibaKereso(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

stock int GetNotVipsCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i)) continue;

		if(Jogosultsag(Jatekos(i)) != Semmi) continue;

		count++;
	}

	return count;
}

stock Jog Jogosultsag(Jatekos jatekos)
{
	return jog[jatekos.index];
}

public int Native_Hozzaadas(Handle myplugin, int argc)
{
	JogAdas(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
}

public int Native_Elvetel(Handle myplugin, int argc)
{
	char cSteamID[20];
	GetNativeString(1, cSteamID, sizeof(cSteamID));
	
	Elvetel(cSteamID);
}

public int Native_Jogosultsag(Handle myplugin, int argc)
{
	return view_as<int>(Jogosultsag(GetNativeCell(1)));
} 
