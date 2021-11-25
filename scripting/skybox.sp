#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <vip_core>

#include <colors>
#include <shop>

#pragma newdecls required

char g_cFeature[] = "skybox";

ConVar g_CvarSkyName;
Handle g_hCookie_Sky;
Handle g_hCookie_Show;
KeyValues g_Kv;
Menu g_MenuChoose;
Menu g_MenuMain;

int g_bUseSB[MAXPLAYERS+1];
bool g_bShopLoaded[MAXPLAYERS+1];
bool g_bVIPLoaded[MAXPLAYERS+1];

int g_iBuyPrice, g_iSellPrice, g_iBuyTime;

bool g_bLateLoad;
bool g_bVIPCore, g_bShopCore;

ArrayList g_sSelSB;
ArrayList g_sSelected;

bool g_bDontShow[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[VIP+SHOP] Skybox",
	description = "Allow players to choose skyboxes",
	author = "NF & White Wolf",
	version = "1.1",
	url = "http://steamcommunity.com/id/doctor_white http://steamcommunity.com/id/Deathknife273/ https://vk.com/nf_dev"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	g_sSelSB = new ArrayList(ByteCountToCells(MAXPLAYERS+1));
	g_sSelected = new ArrayList(ByteCountToCells(MAXPLAYERS+1));
	
	for(int i = 0; i < MAXPLAYERS + 1; i++){
		g_sSelSB.PushString("");
		g_sSelected.PushString("");
	}
	
	return APLRes_Success;
}



int GetSpectatorTarget(int client)
{
	int target;

	if(IsClientObserver(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if (iObserverMode >= 3 && iObserverMode <= 7)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (IsValidEntity(iTarget))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

ItemId g_iID;
ConVar CVARB, CVARS, CVART, CVARShop, CVARVIP;
public void OnPluginStart()
{
	g_hCookie_Sky = RegClientCookie("skybox", "Selected Skybox", CookieAccess_Public);
	g_hCookie_Show = RegClientCookie("skybox_show", "Show others' Skybox", CookieAccess_Public);
	
	// Find sv_skyname for clients
	g_CvarSkyName = FindConVar("sv_skyname");
	
	if (VIP_IsVIPLoaded())
		VIP_OnVIPLoaded();
	
	
	
	RegConsoleCmd("sm_skybox",CmdSB);
	
	if (Shop_IsStarted()) Shop_Started();
	
	
	
	(CVARB = CreateConVar("sm_skybox_shop_price", "20000", "Цена покупки SkyBox.", _, true, 0.0)).AddChangeHook(ChangeCvar_Buy);
	(CVARS = CreateConVar("sm_skybox_shop_sellprice", "10000", "Цена продажи SkyBox.", _, true, 0.0)).AddChangeHook(ChangeCvar_Sell);
	(CVART = CreateConVar("sm_skybox_shop_time", "604800", "Время действия покупки SkyBox в секундах.", _, true, 0.0)).AddChangeHook(ChangeCvar_Time);
	
	(CVARShop = CreateConVar("sm_skybox_shop_use", "1", "Использовать ядро Shop.", _, true, 0.0, true, 1.0)).AddChangeHook(ChangeCvar_ShopCore);
	(CVARVIP = CreateConVar("sm_skybox_vip_use", "1", "Использовать ядро VIP.", _, true, 0.0, true, 1.0)).AddChangeHook(ChangeCvar_VIPCore);
	
	AutoExecConfig(true, "skybox", "sourcemod");	
	
	Autoexec();	
	
	if(g_bLateLoad) CreateTimer(0.5, Timer_DelayReload);
	
	
}

Action Timer_DelayReload(Handle hTimer){

	for(int i = 1;i < MAXPLAYERS + 1; i++) if(IsValidClient(i)) OnPlayerJoin(i);

}

int g_iFrameCount;
public void OnGameFrame(){
	
	//PrintToChatAll("DA");
	int spec;
	g_iFrameCount++;
	if(g_iFrameCount>MAXPLAYERS) g_iFrameCount = 1;
	
	
	
	
	if(IsValidClient(g_iFrameCount)){
	
		char s_Buffer[64];
		g_sSelSB.GetString(g_iFrameCount, s_Buffer, sizeof(s_Buffer));		
	
		if(!IsPlayerAlive(g_iFrameCount)&&!g_bDontShow[g_iFrameCount]){
			spec = GetSpectatorTarget(g_iFrameCount);
			
			if(IsValidClient(spec)){			
				
				//PrintToChat(g_iFrameCount,"Spec: %N",spec);
				g_sSelSB.GetString(spec, s_Buffer, sizeof(s_Buffer));
				//SetSkybox(g_iFrameCount,s_Buffer, true);
			
				//if(spec) PrintToChat(g_iFrameCount, "Spec: %N", spec);
			}
			//else SetSkybox(g_iFrameCount,s_Buffer, true);
		}
		
		SetSkybox(g_iFrameCount,s_Buffer, true);
	}
	
}

void Autoexec(){

	g_iBuyPrice = CVARB.IntValue;
	g_iSellPrice = CVARS.IntValue;
	g_iBuyTime = CVART.IntValue;

	if(CVARShop.IntValue==0) UnloadShopCore();
	if(CVARVIP.IntValue==0) UnloadVIPCore();
}

void LoadVIPCore(){
	if(g_bVIPCore||!VIP_IsVIPLoaded()) return;

	VIP_RegisterFeature(g_cFeature, BOOL, SELECTABLE, OnSkyboxItemSelect);
	
	if(g_bLateLoad){
	
		for(int i = 1; i<MAXPLAYERS+1;i++) if(IsValidClient(i)) VIP_OnClientLoaded(i,true);
	
	}
	

	g_bVIPCore = true;

}

void UnloadVIPCore(){
	if(!g_bVIPCore||!VIP_IsVIPLoaded()) return;

	VIP_UnregisterFeature(g_cFeature);

	g_bVIPCore = false;

}

void LoadShopCore(){

	if(g_bShopCore||!Shop_IsStarted()) return;

	CategoryId category_id = Shop_RegisterCategory("skyboxes", "Скайбоксы", "");
		
	if (Shop_StartItem(category_id, "shop_skybox"))
	{		
		Shop_SetInfo("Небо [!SkyBox]", "Смена скайбокса",0, 0, Item_Togglable, 1);
		Shop_SetCallbacks(OnItemRegistered, OnEquipItem);
		Shop_EndItem();
	}
		
	if(g_bLateLoad){
	
		for(int i = 1; i<MAXPLAYERS+1;i++) if(IsValidClient(i)) Shop_OnAuthorized(i);
	
	}
	
	g_bShopCore = true;

}

void UnloadShopCore(){

	if(!g_bShopCore||!Shop_IsStarted()) return;
	Shop_UnregisterMe();
	g_bShopCore = false;

}

public void ChangeCvar_ShopCore(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar.IntValue==1) LoadShopCore();
	else UnloadShopCore();
	
}

public void ChangeCvar_VIPCore(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar.IntValue==1) LoadVIPCore();
	else UnloadVIPCore();
	
}

public void ChangeCvar_Buy(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iBuyPrice = convar.IntValue;
	if(g_bShopCore) Shop_SetItemPrice(g_iID, g_iBuyPrice);
}

public void ChangeCvar_Sell(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iSellPrice = convar.IntValue;
	if(g_bShopCore) Shop_SetItemSellPrice(g_iID, g_iSellPrice);	
}

public void ChangeCvar_Time(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iBuyTime = convar.IntValue
	if(g_bShopCore) Shop_SetItemValue(g_iID, g_iBuyTime);
}

public Action CmdSB(int client, int args)
{	
	DisplayMainMenu(client);
	
	return Plugin_Handled;
}

public void OnPluginEnd(){

	UnloadShopCore();
	UnloadVIPCore();
	
}

bool IsValidClient(int client){

	if(client>1&&client<65&&IsClientInGame(client)&&!IsFakeClient(client)) return true;
	else return false;

}

public void Shop_Started()
{
	LoadShopCore();
}

public void OnItemRegistered(CategoryId category_id, const char[] sCategory, const char[] sItem, ItemId item_id)
{
	g_iID = item_id;	
	
	Shop_SetItemPrice(g_iID, g_iBuyPrice);
	Shop_SetItemSellPrice(g_iID, g_iSellPrice);	
	Shop_SetItemValue(g_iID, g_iBuyTime);	
}

public ShopAction OnEquipItem(int iClient, CategoryId category_id, const char[] sCategory, ItemId item_id, const char[] sItem, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bUseSB[iClient] = false;
		return Shop_UseOff;
	}

	g_bUseSB[iClient] = true;

	return Shop_UseOn;	
}

public void PrintMes(int client){

	CPrintToChat(client,"{darkred}[{lime}SkyBox{darkred}]{default} Для использования данной функции купите её в !shop в разделе Скайбоксы, либо же приобретите VIP-статус");	

}

public int hasRights(int client){
	if(VIP_GetClientFeatureStatus(client, g_cFeature) == ENABLED) return 1;
	if(g_bUseSB[client]) return 2;
	if(Shop_IsClientItemToggled(client, g_iID)) return 2;	
	return 0;
}

public void OnMapStart()
{
	g_MenuChoose = new Menu(MenuChoose_Handler, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem);
	g_MenuChoose.SetTitle("Выберите небо");
	// Add "default skybox" item
	g_MenuChoose.AddItem("", "Стандартный");
	g_MenuChoose.ExitBackButton = true;
	LoadSkybox();
}

public void OnMapEnd()
{
	delete g_MenuChoose;
}

public Action Timer_Check(Handle timer, any client){

	if((g_bShopLoaded[client]||!g_bShopCore)&&(g_bVIPLoaded[client]||!g_bVIPCore)) OnPlayerJoin(client);
	
	else CreateTimer(2.0,Timer_Check,client);
	
	return Plugin_Handled;

}

public void OnClientPostAdminCheck(int client){
	CreateTimer(2.0,Timer_Check,client);
}

public void OnClientDisconnect(int client){

	g_bUseSB[client] = 0;
	g_bShopLoaded[client] = false;
	g_bVIPLoaded[client] = false;

}


public void OnPlayerJoin(int client)
{	
	char cInfo[64];
	// Get cookie value
	GetClientCookie(client, g_hCookie_Sky, cInfo, sizeof(cInfo));
	//PrintToConsole(client,"SkyBox: %s", cInfo);
	if (cInfo[0] != NULL_STRING[0])
	{
		char cBuffer[64];
		if (IsSkyboxExistInKV(cInfo, cBuffer, sizeof(cBuffer)))
		{
			if (cBuffer[0] != NULL_STRING[0] && hasRights(client)) SetSkybox(client, cBuffer, false);
		}
	}	
	
	// Get cookie value
	GetClientCookie(client, g_hCookie_Show, cInfo, sizeof(cInfo));
	
	g_bDontShow[client] = view_as<bool>(StringToInt(cInfo));
}


public void Shop_OnAuthorized(int client){
	
	g_bUseSB[client] = Shop_IsClientItemToggled(client, g_iID);

	g_bShopLoaded[client] = true;
	
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP){

	g_bVIPLoaded[iClient] = true;


}

public void VIP_OnVIPLoaded()
{
	LoadTranslations("vip_modules.phrases");
	LoadVIPCore();
}

void DisplayChooseMenu(int client){
	g_MenuChoose.Display(client, MENU_TIME_FOREVER);
}

void DisplayMainMenu(int client){

	g_MenuMain = new Menu(MenuMain_Handler); // Прикрепляем обработчик при выборе в категории
	
	char sSelect[128];
	GetClientCookie(client, g_hCookie_Sky, sSelect, sizeof(sSelect));	
	//g_sSelected.GetString(client, sSelect, sizeof(sSelect));
	
	if(sSelect[0] == NULL_STRING[0]) sSelect = "Стандарт";
	if(!hasRights(client)) sSelect = "нет доступа";
	Format(sSelect,sizeof(sSelect),"Меню SkyBox\n \nТекущее:\n%s\n ",sSelect);
	
	g_MenuMain.SetTitle(sSelect);
	
	if(hasRights(client)) g_MenuMain.AddItem("select", "Выбор неба\n ");
	else{
		g_MenuMain.AddItem("buy", "Выбор неба\n	нет доступа\n ");
	}
	
	char sShow[64];
	
	if(!g_bDontShow[client]) sShow = "✔"; else sShow = "✘";
	Format(sShow,sizeof(sShow),"Показывать чужое небо [%s]",sShow);
	
	g_MenuMain.AddItem("show", sShow);

	g_MenuMain.Display(client, MENU_TIME_FOREVER);
}



public bool OnSkyboxItemSelect(int client, const char[] cFeature)
{
	DisplayMainMenu(client);
	
	return false;
}

public int MenuChoose_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack) DisplayMainMenu(param1)
		}
		case MenuAction_Select:
		{
			char cInfo[64], cPath[64];
			menu.GetItem(param2, cInfo, sizeof(cInfo));
			if (IsSkyboxExistInKV(cInfo, cPath, sizeof(cPath)))
			{
				SetClientCookie(param1, g_hCookie_Sky, cInfo);
				//Set skybox for client (param1)
				SetSkybox(param1, cPath, false);
			}
			
			menu.DisplayAt(param1, menu.Selection, MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem:
		{
			char cClientCookie[64], cInfo[64], cDisplay[64];
			menu.GetItem(param2, cInfo, sizeof(cInfo), _, cDisplay, sizeof(cDisplay));
			GetClientCookie(param1, g_hCookie_Sky, cClientCookie, sizeof(cClientCookie));
			
			if (StrEqual(cClientCookie, cInfo, false))
			{
				StrCat(cDisplay, sizeof(cDisplay), "[X]");
				return RedrawMenuItem(cDisplay);
			}
			
			return 0;
		}
	}
	
	return 0;
}

public int MenuMain_Handler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_Select:
		{
			char cInfo[64];
			bool bShow = true;
			menu.GetItem(param2, cInfo, sizeof(cInfo));
			if(StrEqual(cInfo,"show")){
				g_bDontShow[client] = !g_bDontShow[client];
				
				if(g_bDontShow[client]) SetClientCookie(client, g_hCookie_Show, "1");
				else SetClientCookie(client, g_hCookie_Show, "0");
				
				
			}
			if(StrEqual(cInfo,"select")){ 
				bShow = false;
				DisplayChooseMenu(client);
				}
			if(StrEqual(cInfo,"buy")) PrintMes(client);
			
			if(bShow) DisplayMainMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

void SetSkybox(int client, const char[] cSkybox, bool spec)
{
	char sSelected[32];
	g_sSelected.GetString(client, sSelected, sizeof(sSelected));
	if(!StrEqual(sSelected,cSkybox)){
		// If skybox is default
		if (cSkybox[0] == NULL_STRING[0])
		{
			char cBuffer[32];
			SetEntProp(client, Prop_Send, "m_skybox3d.area", 0);
			g_CvarSkyName.GetString(cBuffer, sizeof(cBuffer));
			g_CvarSkyName.ReplicateToClient(client, cBuffer);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_skybox3d.area", 255);
			g_CvarSkyName.ReplicateToClient(client, cSkybox);
		}
		
		if(!spec) g_sSelSB.SetString(client, cSkybox);		
		
		g_sSelected.SetString(client, cSkybox);
	}
}

void LoadSkybox()
{
	g_Kv = new KeyValues("Skybox");
	char cBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cBuffer, sizeof(cBuffer), "configs/skybox.ini");
	
	if (!g_Kv.ImportFromFile(cBuffer))
	{
		delete g_Kv;
		SetFailState("Failed to read from file \"%s\"", cBuffer);
	}
	g_Kv.Rewind();
	
	//Skybox suffixes.
	static char suffix[][] = {
		"bk",
		"Bk",
		"dn",
		"Dn",
		"ft",
		"Ft",
		"lf",
		"Lf",
		"rt",
		"Rt",
		"up",
		"Up",
	};
	
	if (g_Kv.GotoFirstSubKey())
	{
		char cPath[64];
		do
		{
			g_Kv.GetSectionName(cBuffer, sizeof(cBuffer));
			g_MenuChoose.AddItem(cBuffer, cBuffer);
			// Get path
			g_Kv.GetString("path", cPath, sizeof(cPath));
			
			for (int i = 0; i < sizeof(suffix); ++i)
			{
				FormatEx(cBuffer, sizeof(cBuffer), "materials/skybox/%s%s.vtf", cPath, suffix[i]);
				if (FileExists(cBuffer, false)) AddFileToDownloadsTable(cBuffer);
				
				FormatEx(cBuffer, sizeof(cBuffer), "materials/skybox/%s%s.vmt", cPath, suffix[i]);
				if (FileExists(cBuffer, false)) AddFileToDownloadsTable(cBuffer);
			}			
		} while (g_Kv.GotoNextKey());
	}
	
	g_Kv.Rewind();
}

bool IsSkyboxExistInKV(const char[] cInfo, char[] cPath, int maxlength)
{
	// if `default` checked
	if (cInfo[0] == NULL_STRING[0])
		return true;
	
	KeyValues kv = new KeyValues("skybox_copy");
	KvCopySubkeys(g_Kv, kv);
	
	if (kv.JumpToKey(cInfo))
	{
		kv.GetString("path", cPath, maxlength);
		delete kv;
		return true;
	}
	
	delete kv;
	return false;
}
