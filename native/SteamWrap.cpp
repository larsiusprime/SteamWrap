#define IMPLEMENT_API
#include <hx/CFFI.h>
#include <hx/CFFIPrime.h>

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <vector>
#include <sstream>
#include <iostream>
#include <map>

#include <steam/steam_api.h>

AutoGCRoot *g_eventHandler = 0;

//-----------------------------------------------------------------------------------------------------------
// Event
//-----------------------------------------------------------------------------------------------------------
static const char* kEventTypeNone = "None";
static const char* kEventTypeOnUserStatsReceived = "UserStatsReceived";
static const char* kEventTypeOnUserStatsStored = "UserStatsStored";
static const char* kEventTypeOnUserAchievementStored = "UserAchievementStored";
static const char* kEventTypeOnLeaderboardFound = "LeaderboardFound";
static const char* kEventTypeOnScoreUploaded = "ScoreUploaded";
static const char* kEventTypeOnScoreDownloaded = "ScoreDownloaded";
static const char* kEventTypeOnGlobalStatsReceived = "GlobalStatsReceived";
static const char* kEventTypeUGCLegalAgreement = "UGCLegalAgreementStatus";
static const char* kEventTypeUGCItemCreated = "UGCItemCreated";
static const char* kEventTypeOnItemUpdateSubmitted = "UGCItemUpdateSubmitted";

//A simple data structure that holds on to the native 64-bit handles and maps them to regular ints.
//This is because it is cumbersome to pass back 64-bit values over CFFI, and strictly speaking, the haxe 
//side never needs to know the actual values. So we just store the full 64-bit values locally and pass back 
//0-based index values which easily fit into a regular int.
class steamHandleMap
{
	//TODO: figure out templating or whatever so I can make typed versions of this like in Haxe (steamHandleMap<ControllerHandle_t>)
	//      all the steam handle typedefs are just renamed uint64's, but this could always change so to be 100% super safe I should
	//      figure out the templating stuff.
	
	private:
		std::map<int, uint64> values;
		std::map<int, uint64>::iterator it;
		int maxKey;
		
	public:
		
		void init()
		{
			values.clear();
			maxKey = -1;
		}
		
		bool exists(uint64 val)
		{
			return find(val) >= 0;
		}
		
		int find(uint64 val)
		{
			for(int i = 0; i <= maxKey; i++)
			{
				if(values[i] == val)
				{
					return i;
				}
			}
			return -1;
		}
		
		uint64 get(int index)
		{
			return values[index];
		}
		
		//add a unique uint64 value to this data structure & return what index it was stored at
		int add(uint64 val)
		{
			int i = find(val);
			
			//if it already exists just return where it is stored
			if(i >= 0)
			{
				return i;
			}
			
			//if it is unique increase our maxKey count and return that
			maxKey++;
			values[maxKey] = val;
			
			return maxKey;
		}
};

static steamHandleMap mapControllers;
static ControllerAnalogActionData_t analogActionData;

struct Event
{
	const char* m_type;
	int m_success;
	std::string m_data;
	Event(const char* type, bool success=false, const std::string& data="") : m_type(type), m_success(success), m_data(data) {}
};

static void SendEvent(const Event& e)
{
	// http://code.google.com/p/nmex/source/browse/trunk/project/common/ExternalInterface.cpp
	if (!g_eventHandler) return;
    value obj = alloc_empty_object();
    alloc_field(obj, val_id("type"), alloc_string(e.m_type));
    alloc_field(obj, val_id("success"), alloc_int(e.m_success ? 1 : 0));
    alloc_field(obj, val_id("data"), alloc_string(e.m_data.c_str()));
    val_call1(g_eventHandler->get(), obj);
}

// This is not used and produces compilation error on Linux.

// static value handleToValStr(uint64 handle)
// {
	// std::ostringstream data;
	// data << handle;
	// return alloc_string(data.str().c_str());
// }

// static uint64 valStrToHandle(value str)
// {
	// ControllerHandle_t c_handle;
	// sscanf(val_string(str), "%I64x", &c_handle);
	// return c_handle;
// }

//-----------------------------------------------------------------------------------------------------------
// CallbackHandler
//-----------------------------------------------------------------------------------------------------------
class CallbackHandler
{
private:
	//SteamLeaderboard_t m_curLeaderboard;
	std::map<std::string, SteamLeaderboard_t> m_leaderboards;
public:

	CallbackHandler() :
 		m_CallbackUserStatsReceived( this, &CallbackHandler::OnUserStatsReceived ),
 		m_CallbackUserStatsStored( this, &CallbackHandler::OnUserStatsStored ),
 		m_CallbackAchievementStored( this, &CallbackHandler::OnAchievementStored )
	{}

	STEAM_CALLBACK( CallbackHandler, OnUserStatsReceived, UserStatsReceived_t, m_CallbackUserStatsReceived );
	STEAM_CALLBACK( CallbackHandler, OnUserStatsStored, UserStatsStored_t, m_CallbackUserStatsStored );
	STEAM_CALLBACK( CallbackHandler, OnAchievementStored, UserAchievementStored_t, m_CallbackAchievementStored );

	void FindLeaderboard(const char* name);
	void OnLeaderboardFound( LeaderboardFindResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LeaderboardFindResult_t> m_callResultFindLeaderboard;

	bool UploadScore(const std::string& leaderboardId, int score, int detail);
	void OnScoreUploaded( LeaderboardScoreUploaded_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LeaderboardScoreUploaded_t> m_callResultUploadScore;

	bool DownloadScores(const std::string& leaderboardId, int numBefore, int numAfter);
	void OnScoreDownloaded( LeaderboardScoresDownloaded_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LeaderboardScoresDownloaded_t> m_callResultDownloadScore;

	void RequestGlobalStats();
	void OnGlobalStatsReceived(GlobalStatsReceived_t* pResult, bool bIOFailure);
	CCallResult<CallbackHandler, GlobalStatsReceived_t> m_callResultRequestGlobalStats;

	void CreateUGCItem(AppId_t nConsumerAppId, EWorkshopFileType eFileType);
	void OnUGCItemCreated( CreateItemResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, CreateItemResult_t> m_callResultCreateUGCItem;

	void SubmitUGCItemUpdate(UGCUpdateHandle_t handle, const char *pchChangeNote);
	void OnItemUpdateSubmitted( SubmitItemUpdateResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, SubmitItemUpdateResult_t> m_callResultSubmitUGCItemUpdate;
};

void CallbackHandler::OnUserStatsReceived( UserStatsReceived_t *pCallback )
{
 	if (pCallback->m_nGameID != SteamUtils()->GetAppID()) return;
	SendEvent(Event(kEventTypeOnUserStatsReceived, pCallback->m_eResult == k_EResultOK));
}

void CallbackHandler::OnUserStatsStored( UserStatsStored_t *pCallback )
{
 	if (pCallback->m_nGameID != SteamUtils()->GetAppID()) return;
	SendEvent(Event(kEventTypeOnUserStatsStored, pCallback->m_eResult == k_EResultOK));
}

void CallbackHandler::OnAchievementStored( UserAchievementStored_t *pCallback )
{
 	if (pCallback->m_nGameID != SteamUtils()->GetAppID()) return;
	SendEvent(Event(kEventTypeOnUserAchievementStored, true, pCallback->m_rgchAchievementName));
}

void CallbackHandler::SubmitUGCItemUpdate(UGCUpdateHandle_t handle, const char *pchChangeNote)
{
	SteamAPICall_t hSteamAPICall = SteamUGC()->SubmitItemUpdate(handle, pchChangeNote);
	m_callResultSubmitUGCItemUpdate.Set(hSteamAPICall, this, &CallbackHandler::OnItemUpdateSubmitted);
}

void CallbackHandler::OnItemUpdateSubmitted(SubmitItemUpdateResult_t *pCallback, bool bIOFailure)
{
	std::cout << std::endl << "eResult: " << pCallback->m_eResult << std::endl;
	if(	pCallback->m_eResult == k_EResultInsufficientPrivilege ||
		pCallback->m_eResult == k_EResultTimeout ||
		pCallback->m_eResult == k_EResultNotLoggedOn ||
		bIOFailure)
	{
		SendEvent(Event(kEventTypeOnItemUpdateSubmitted, false));
	}
	else{
		SendEvent(Event(kEventTypeOnItemUpdateSubmitted, true));
	}
}

void CallbackHandler::CreateUGCItem(AppId_t nConsumerAppId, EWorkshopFileType eFileType)
{
	SteamAPICall_t hSteamAPICall = SteamUGC()->CreateItem(nConsumerAppId, eFileType);
	m_callResultCreateUGCItem.Set(hSteamAPICall, this, &CallbackHandler::OnUGCItemCreated);
}

void CallbackHandler::OnUGCItemCreated(CreateItemResult_t *pCallback, bool bIOFailure)
{
	if (bIOFailure)
	{
		SendEvent(Event(kEventTypeUGCItemCreated, false));
		return;
	}

	PublishedFileId_t m_ugcFileID = pCallback->m_nPublishedFileId;

	/*
	*  k_EResultInsufficientPrivilege : The user creating the item is currently banned in the community.
	*  k_EResultTimeout : The operation took longer than expected, have the user retry the create process.
	*  k_EResultNotLoggedOn : The user is not currently logged into Steam.
	*/
	if(	pCallback->m_eResult == k_EResultInsufficientPrivilege ||
		pCallback->m_eResult == k_EResultTimeout ||
		pCallback->m_eResult == k_EResultNotLoggedOn)
	{
		SendEvent(Event(kEventTypeUGCItemCreated, false));
	}
	else{
		std::ostringstream fileIDStream;
		fileIDStream << m_ugcFileID;
		SendEvent(Event(kEventTypeUGCItemCreated, true, fileIDStream.str().c_str()));
	}

	SendEvent(Event(kEventTypeUGCLegalAgreement, !pCallback->m_bUserNeedsToAcceptWorkshopLegalAgreement));

	if(pCallback->m_bUserNeedsToAcceptWorkshopLegalAgreement){
		std::ostringstream urlStream;
		urlStream << "steam://url/CommunityFilePage/" << m_ugcFileID;

		// TODO: Separate this to it's own call through wrapper.
		SteamFriends()->ActivateGameOverlayToWebPage(urlStream.str().c_str());
	}
}

void CallbackHandler::FindLeaderboard(const char* name)
{
	m_leaderboards[name] = 0;
 	SteamAPICall_t hSteamAPICall = SteamUserStats()->FindLeaderboard(name);
 	m_callResultFindLeaderboard.Set(hSteamAPICall, this, &CallbackHandler::OnLeaderboardFound);
}

void CallbackHandler::OnLeaderboardFound(LeaderboardFindResult_t *pCallback, bool bIOFailure)
{
	// see if we encountered an error during the call
	if (pCallback->m_bLeaderboardFound && !bIOFailure)
	{
		std::string leaderboardId = SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard);
		m_leaderboards[leaderboardId] = pCallback->m_hSteamLeaderboard;
		SendEvent(Event(kEventTypeOnLeaderboardFound, true, leaderboardId));
	}
	else
	{
		SendEvent(Event(kEventTypeOnLeaderboardFound, false));
	}
}

bool CallbackHandler::UploadScore(const std::string& leaderboardId, int score, int detail)
{
   	if (m_leaderboards.find(leaderboardId) == m_leaderboards.end() || m_leaderboards[leaderboardId] == 0)
   		return false;

	SteamAPICall_t hSteamAPICall = SteamUserStats()->UploadLeaderboardScore(m_leaderboards[leaderboardId], k_ELeaderboardUploadScoreMethodKeepBest, score, &detail, 1);
	m_callResultUploadScore.Set(hSteamAPICall, this, &CallbackHandler::OnScoreUploaded);
 	return true;
}

static std::string toLeaderboardScore(const char* leaderboardName, int score, int detail, int rank)
{
	std::ostringstream data;
	data << leaderboardName << "," << score << "," << detail << "," << rank;
	return data.str();
}

void CallbackHandler::OnScoreUploaded(LeaderboardScoreUploaded_t *pCallback, bool bIOFailure)
{
	if (pCallback->m_bSuccess && !bIOFailure)
	{
		std::string leaderboardName = SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard);
		std::string data = toLeaderboardScore(SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard), pCallback->m_nScore, -1, pCallback->m_nGlobalRankNew);
		SendEvent(Event(kEventTypeOnScoreUploaded, true, data));
	}
	else if (pCallback != NULL && pCallback->m_hSteamLeaderboard != 0)
	{
		SendEvent(Event(kEventTypeOnScoreUploaded, false, SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard)));
	}
	else
	{
		SendEvent(Event(kEventTypeOnScoreUploaded, false));
	}
}

bool CallbackHandler::DownloadScores(const std::string& leaderboardId, int numBefore, int numAfter)
{
   	if (m_leaderboards.find(leaderboardId) == m_leaderboards.end() || m_leaderboards[leaderboardId] == 0)
   		return false;

 	// load the specified leaderboard data around the current user
 	SteamAPICall_t hSteamAPICall = SteamUserStats()->DownloadLeaderboardEntries(m_leaderboards[leaderboardId], k_ELeaderboardDataRequestGlobalAroundUser, -numBefore, numAfter);
	m_callResultDownloadScore.Set(hSteamAPICall, this, &CallbackHandler::OnScoreDownloaded);

 	return true;
}

void CallbackHandler::OnScoreDownloaded(LeaderboardScoresDownloaded_t *pCallback, bool bIOFailure)
{
	if (bIOFailure)
	{
		SendEvent(Event(kEventTypeOnScoreDownloaded, false));
		return;
	}

	std::string leaderboardId = SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard);

	int numEntries = pCallback->m_cEntryCount;
	if (numEntries > 10) numEntries = 10;

	std::ostringstream data;
	bool haveData = false;

	for (int i=0; i<numEntries; i++)
	{
		int score = 0;
		int details[1];
		LeaderboardEntry_t entry;
		SteamUserStats()->GetDownloadedLeaderboardEntry(pCallback->m_hSteamLeaderboardEntries, i, &entry, details, 1);
		if (entry.m_cDetails != 1) continue;

		if (haveData) data << ";";
		data << toLeaderboardScore(leaderboardId.c_str(), entry.m_nScore, details[0], entry.m_nGlobalRank).c_str();
		haveData = true;
	}

	if (haveData)
	{
		SendEvent(Event(kEventTypeOnScoreDownloaded, true, data.str()));
	}
	else
	{
		// ok but no scores
		SendEvent(Event(kEventTypeOnScoreDownloaded, true, toLeaderboardScore(leaderboardId.c_str(), -1, -1, -1)));
	}
}

void CallbackHandler::RequestGlobalStats()
{
 	SteamAPICall_t hSteamAPICall = SteamUserStats()->RequestGlobalStats(0);
 	m_callResultRequestGlobalStats.Set(hSteamAPICall, this, &CallbackHandler::OnGlobalStatsReceived);
}

void CallbackHandler::OnGlobalStatsReceived(GlobalStatsReceived_t* pResult, bool bIOFailure)
{
	if (!bIOFailure)
	{
		if (pResult->m_nGameID != SteamUtils()->GetAppID()) return;
		SendEvent(Event(kEventTypeOnGlobalStatsReceived, pResult->m_eResult == k_EResultOK));
	}
	else
	{
		SendEvent(Event(kEventTypeOnGlobalStatsReceived, false));
	}
}

//-----------------------------------------------------------------------------------------------------------
static CallbackHandler* s_callbackHandler = NULL;

extern "C"
{

//-----------------------------------------------------------------------------------------------------------
static bool CheckInit()
{
	return SteamUser() && SteamUser()->BLoggedOn() && SteamUserStats() && (s_callbackHandler != 0) && (g_eventHandler != 0);
}

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_Init(value onEvent, value notificationPosition)
{
	bool result = SteamAPI_Init();
	if (result)
	{
		g_eventHandler = new AutoGCRoot(onEvent);
		s_callbackHandler = new CallbackHandler();

		switch (val_int(notificationPosition))
		{
			case 0:
				SteamUtils()->SetOverlayNotificationPosition(k_EPositionTopLeft);
				break;
			case 1:
				SteamUtils()->SetOverlayNotificationPosition(k_EPositionTopRight);
				break;
			case 2:
				SteamUtils()->SetOverlayNotificationPosition(k_EPositionBottomRight);
				break;
			case 3:
				SteamUtils()->SetOverlayNotificationPosition(k_EPositionBottomLeft);
				break;
			default:
				SteamUtils()->SetOverlayNotificationPosition(k_EPositionBottomRight);
				break;
		}
	}
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_Init, 2);

//-----------------------------------------------------------------------------------------------------------
void SteamWrap_Shutdown()
{
	SteamAPI_Shutdown();
	delete g_eventHandler;
	g_eventHandler = NULL;
	delete s_callbackHandler;
	s_callbackHandler = NULL;
}
DEFINE_PRIM(SteamWrap_Shutdown, 0);

//-----------------------------------------------------------------------------------------------------------
void SteamWrap_RunCallbacks()
{
	SteamAPI_RunCallbacks();
}
DEFINE_PRIM(SteamWrap_RunCallbacks, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_RequestStats()
{
	if (!CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->RequestCurrentStats();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_RequestStats, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetStat(value name)
{
	if (!val_is_string(name)|| !CheckInit())
		return alloc_int(0);

	int val = 0;
	SteamUserStats()->GetStat(val_string(name), &val);
	return alloc_int(val);
}
DEFINE_PRIM(SteamWrap_GetStat, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetStat(value name, value val)
{
	if (!val_is_string(name) || !val_is_int(val) || !CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->SetStat(val_string(name), val_int(val));

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetStat, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_StoreStats()
{
	if (!CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->StoreStats();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_StoreStats, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SubmitUGCItemUpdate(value updateHandle, value changeNotes)
{
	if (!val_is_string(updateHandle)  || !val_is_string(changeNotes) || !CheckInit())
	{
		return alloc_bool(false);
	}

	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}

	s_callbackHandler->SubmitUGCItemUpdate(updateHandle64, val_string(changeNotes));
 	return alloc_bool(true);
}
DEFINE_PRIM(SteamWrap_SubmitUGCItemUpdate, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_OpenOverlay(value url)
{
	if (!val_is_string(url) || !CheckInit())
	{
		return alloc_bool(false);
	}

	SteamFriends()->ActivateGameOverlayToWebPage(val_string(url));
	return alloc_bool(true);
}
DEFINE_PRIM(SteamWrap_OpenOverlay, 1);
//-----------------------------------------------------------------------------------------------------------
value SteamWrap_StartUpdateUGCItem(value id, value itemID)
{
	if (!val_is_int(id)  || !val_is_int(itemID) || !CheckInit())
	{
		return alloc_string("0");
	}

	UGCUpdateHandle_t ugcUpdateHandle = SteamUGC()->StartItemUpdate(val_int(id), val_int(itemID));

	//Change the uint64 to string, easier to handle between haxe & cpp.
	std::ostringstream updateHandleStream;
	updateHandleStream << ugcUpdateHandle;

 	return alloc_string(updateHandleStream.str().c_str());
}
DEFINE_PRIM(SteamWrap_StartUpdateUGCItem, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetUGCItemTitle(value updateHandle, value title)
{
	if (!val_is_string(updateHandle) || !val_is_string(title) || !CheckInit())
	{
		return alloc_bool(false);
	}

	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}
	bool result = SteamUGC()->SetItemTitle(updateHandle64, val_string(title));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetUGCItemTitle, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetUGCItemDescription(value updateHandle, value description)
{
	if (!val_is_string(updateHandle) || !val_is_string(description) || !CheckInit())
	{
		return alloc_bool(false);
	}

	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}

	bool result = SteamUGC()->SetItemDescription(updateHandle64, val_string(description));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetUGCItemDescription, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetUGCItemVisibility(value updateHandle, value visibility)
{
	if (!val_is_string(updateHandle) || !val_is_int(visibility) || !CheckInit())
	{
		return alloc_bool(false);
	}

	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}

	ERemoteStoragePublishedFileVisibility visibilityEnum = static_cast<ERemoteStoragePublishedFileVisibility>(val_int(visibility));

	bool result = SteamUGC()->SetItemVisibility(updateHandle64, visibilityEnum);
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetUGCItemVisibility, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetUGCItemContent(value updateHandle, value path)
{
	if (!val_is_string(updateHandle) || !val_is_string(path) || !CheckInit())
	{
		return alloc_bool(false);
	}

	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}

	bool result = SteamUGC()->SetItemContent(updateHandle64, val_string(path));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetUGCItemContent, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetUGCItemPreviewImage(value updateHandle, value path)
{
	if (!val_is_string(updateHandle) || !val_is_string(path) || !CheckInit())
	{
		return alloc_bool(false);
	}

	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}

	bool result = SteamUGC()->SetItemPreview(updateHandle64, val_string(path));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetUGCItemPreviewImage, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_CreateUGCItem(value id)
{
	if (!val_is_int(id) || !CheckInit())
		return alloc_bool(false);

	s_callbackHandler->CreateUGCItem(val_int(id), k_EWorkshopFileTypeCommunity);

 	return alloc_bool(true);
}
DEFINE_PRIM(SteamWrap_CreateUGCItem, 1);


//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetAchievement(value name)
{
	if (!val_is_string(name) || !CheckInit())
		return alloc_bool(false);

	SteamUserStats()->SetAchievement(val_string(name));
	bool result = SteamUserStats()->StoreStats();

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetAchievement, 1);

value SteamWrap_GetAchievement(value name)
{
  if (!val_is_string(name) || !CheckInit()) return alloc_bool(false);
  bool achieved = false;
  SteamUserStats()->GetAchievement(val_string(name), &achieved);
  return alloc_bool(achieved);
}
DEFINE_PRIM(SteamWrap_GetAchievement, 1);

value SteamWrap_GetAchievementDisplayAttribute(value name, value key)
{
  if (!val_is_string(name) || !val_is_string(key) || !CheckInit()) return alloc_string("");
  
  const char* result = SteamUserStats()->GetAchievementDisplayAttribute(val_string(name), val_string(key));
  return alloc_string(result);
}
DEFINE_PRIM(SteamWrap_GetAchievementDisplayAttribute, 2);

value SteamWrap_GetNumAchievements()
{
  if (!CheckInit()) return alloc_int(0);
  
  uint32 count = SteamUserStats()->GetNumAchievements();
  return alloc_int((int)count);
}
DEFINE_PRIM(SteamWrap_GetNumAchievements, 0);

value SteamWrap_GetAchievementName(value index)
{
  if (!val_is_int(index) && !CheckInit()) return alloc_string("");
  const char* name = SteamUserStats()->GetAchievementName(val_int(index));
  return alloc_string(name);
}
DEFINE_PRIM(SteamWrap_GetAchievementName, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_ClearAchievement(value name)
{
	if (!val_is_string(name) || !CheckInit())
		return alloc_bool(false);

	SteamUserStats()->ClearAchievement(val_string(name));
	bool result = SteamUserStats()->StoreStats();

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_ClearAchievement, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_IndicateAchievementProgress(value name, value numCurProgres, value numMaxProgress)
{
	if (!val_is_string(name) || !val_is_int(numCurProgres) || !val_is_int(numMaxProgress) || !CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->IndicateAchievementProgress(val_string(name), val_int(numCurProgres), val_int(numMaxProgress));

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_IndicateAchievementProgress, 3);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_FindLeaderboard(value name)
{
	if (!val_is_string(name) || !CheckInit())
		return alloc_bool(false);

	s_callbackHandler->FindLeaderboard(val_string(name));

 	return alloc_bool(true);
}
DEFINE_PRIM(SteamWrap_FindLeaderboard, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_UploadScore(value name, value score, value detail)
{
	if (!val_is_string(name) || !val_is_int(score) || !val_is_int(detail) || !CheckInit())
		return alloc_bool(false);

	bool result = s_callbackHandler->UploadScore(val_string(name), val_int(score), val_int(detail));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_UploadScore, 3);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_DownloadScores(value name, value numBefore, value numAfter)
{
	if (!val_is_string(name) || !val_is_int(numBefore) || !val_is_int(numAfter) || !CheckInit())
		return alloc_bool(false);

	bool result = s_callbackHandler->DownloadScores(val_string(name), val_int(numBefore), val_int(numAfter));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_DownloadScores, 3);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_RequestGlobalStats()
{
	if (!CheckInit())
		return alloc_bool(false);

	s_callbackHandler->RequestGlobalStats();
	return alloc_bool(true);
}
DEFINE_PRIM(SteamWrap_RequestGlobalStats, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetGlobalStat(value name)
{
	if (!val_is_string(name) || !CheckInit())
		return alloc_int(0);

	int64 val;
	SteamUserStats()->GetGlobalStat(val_string(name), &val);

	return alloc_int((int)val);
}
DEFINE_PRIM(SteamWrap_GetGlobalStat, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_RestartAppIfNecessary(value appId)
{
	if (!val_is_int(appId))
		return alloc_bool(false);

	bool result = SteamAPI_RestartAppIfNecessary(val_int(appId));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_RestartAppIfNecessary, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_IsSteamRunning()
{
	bool result = SteamAPI_IsSteamRunning();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_IsSteamRunning, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetCurrentGameLanguage()
{
	const char* result = SteamApps()->GetCurrentGameLanguage();
	return alloc_string(result);
}
DEFINE_PRIM(SteamWrap_GetCurrentGameLanguage, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_InitControllers()
{
	bool result = SteamController()->Init();
	
	if (result)
	{
		mapControllers.init();
		
		analogActionData.eMode = k_EControllerSourceMode_None;
		analogActionData.x = 0.0;
		analogActionData.y = 0.0;
		analogActionData.bActive = false;
	}
	
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_InitControllers,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_ShutdownControllers()
{
	bool result = SteamController()->Shutdown();
	if (result)
	{
		mapControllers.init();
	}
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_ShutdownControllers,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetConnectedControllers()
{
	SteamController()->RunFrame();
	
	ControllerHandle_t handles[STEAM_CONTROLLER_MAX_COUNT];
	int result = SteamController()->GetConnectedControllers(handles);
	
	std::ostringstream returnData;
	
	//store the handles locally and pass back a string representing an int array of unique index lookup values
	
	for(int i = 0; i < result; i++)
	{
		int index = -1;
		
		if(false == mapControllers.exists(handles[i]))
		{
			index = mapControllers.add(handles[i]);
		}
		else
		{
			index = mapControllers.get(handles[i]);
		}
		
		if(index != -1)
		{
			returnData << index;
			if(i != result-1)
			{
				returnData << ",";
			}
		}
	}
	
	return alloc_string(returnData.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetConnectedControllers,0);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetActionSetHandle(const char * actionSetName)
{

	ControllerActionSetHandle_t handle = SteamController()->GetActionSetHandle(actionSetName);
	return handle;
}
DEFINE_PRIME1(SteamWrap_GetActionSetHandle);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetDigitalActionHandle(const char * actionName)
{

	return SteamController()->GetDigitalActionHandle(actionName);
}
DEFINE_PRIME1(SteamWrap_GetDigitalActionHandle);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetAnalogActionHandle(const char * actionName)
{

	ControllerAnalogActionHandle_t handle = SteamController()->GetAnalogActionHandle(actionName);
	return handle;
}
DEFINE_PRIME1(SteamWrap_GetAnalogActionHandle);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetDigitalActionData(int controllerHandle, int actionHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_CONTROLLER_HANDLE_ALL_CONTROLLERS;
	ControllerDigitalActionHandle_t a_handle = actionHandle;
	
	ControllerDigitalActionData_t data = SteamController()->GetDigitalActionData(c_handle, a_handle);
	
	int result = 0;
	
	//Take both bools and pack them into an int
	
	if(data.bState) {
		result |= 0x1;
	}
	
	if(data.bActive) {
		result |= 0x10;
	}
	
	return result;
}
DEFINE_PRIME2(SteamWrap_GetDigitalActionData);


//-----------------------------------------------------------------------------------------------------------
//stashes the requested analog action data in local state and returns the bActive member value
//you need to immediately call _eMode(), _x(), and _y() to get the rest

int SteamWrap_GetAnalogActionData(int controllerHandle, int actionHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_CONTROLLER_HANDLE_ALL_CONTROLLERS;
	ControllerAnalogActionHandle_t a_handle = actionHandle;
	
	analogActionData = SteamController()->GetAnalogActionData(c_handle, a_handle);
	
	return analogActionData.bActive;
}
DEFINE_PRIME2(SteamWrap_GetAnalogActionData);

int SteamWrap_GetAnalogActionData_eMode(int dummy)
{
	return analogActionData.eMode;
}
DEFINE_PRIME1(SteamWrap_GetAnalogActionData_eMode);

float SteamWrap_GetAnalogActionData_x(int dummy)
{
	return analogActionData.x;
}
DEFINE_PRIME1(SteamWrap_GetAnalogActionData_x);

float SteamWrap_GetAnalogActionData_y(int dummy)
{
	return analogActionData.y;
}
DEFINE_PRIME1(SteamWrap_GetAnalogActionData_y);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetDigitalActionOrigins(value controllerHandle, value actionSetHandle, value digitalActionHandle)
{
	ControllerHandle_t c_handle              = mapControllers.get(val_int(controllerHandle));
	ControllerActionSetHandle_t s_handle     = val_int(actionSetHandle);
	ControllerDigitalActionHandle_t a_handle = val_int(digitalActionHandle);
	
	EControllerActionOrigin origins[STEAM_CONTROLLER_MAX_ORIGINS];
	
	//Initialize the whole thing to None to avoid garbage
	for(int i = 0; i < STEAM_CONTROLLER_MAX_ORIGINS; i++) {
		origins[i] = k_EControllerActionOrigin_None;
	}
	
	int result = SteamController()->GetDigitalActionOrigins(c_handle, s_handle, a_handle, origins);
	
	std::ostringstream data;
	
	data << result << ",";
	
	for(int i = 0; i < STEAM_CONTROLLER_MAX_ORIGINS; i++) {
		data << origins[i];
		if(i != STEAM_CONTROLLER_MAX_ORIGINS-1){
			data << ",";
		}
	}
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetDigitalActionOrigins,3);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetAnalogActionOrigins(value controllerHandle, value actionSetHandle, value analogActionHandle)
{
	ControllerHandle_t c_handle              = mapControllers.get(val_int(controllerHandle));
	ControllerActionSetHandle_t s_handle     = val_int(actionSetHandle);
	ControllerAnalogActionHandle_t a_handle  = val_int(analogActionHandle);
	
	EControllerActionOrigin origins[STEAM_CONTROLLER_MAX_ORIGINS];
	
	//Initialize the whole thing to None to avoid garbage
	for(int i = 0; i < STEAM_CONTROLLER_MAX_ORIGINS; i++) {
		origins[i] = k_EControllerActionOrigin_None;
	}
	
	int result = SteamController()->GetAnalogActionOrigins(c_handle, s_handle, a_handle, origins);
	
	std::ostringstream data;
	
	data << result << ",";
	
	for(int i = 0; i < STEAM_CONTROLLER_MAX_ORIGINS; i++) {
		data << origins[i];
		if(i != STEAM_CONTROLLER_MAX_ORIGINS-1){
			data << ",";
		}
	}
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetAnalogActionOrigins,3);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_ActivateActionSet(int controllerHandle, int actionSetHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_CONTROLLER_HANDLE_ALL_CONTROLLERS;
	ControllerActionSetHandle_t a_handle = actionSetHandle;
	
	SteamController()->ActivateActionSet(c_handle, a_handle);
	
	return true;
}
DEFINE_PRIME2(SteamWrap_ActivateActionSet);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetCurrentActionSet(int controllerHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_CONTROLLER_HANDLE_ALL_CONTROLLERS;
	ControllerActionSetHandle_t a_handle = SteamController()->GetCurrentActionSet(c_handle);
	
	return a_handle;
}
DEFINE_PRIME1(SteamWrap_GetCurrentActionSet);

void SteamWrap_TriggerHapticPulse(int controllerHandle, int targetPad, int durationMicroSec)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_CONTROLLER_HANDLE_ALL_CONTROLLERS;
	ESteamControllerPad eTargetPad;
	switch(targetPad)
	{
		case 0:  eTargetPad = k_ESteamControllerPad_Left;
		case 1:  eTargetPad = k_ESteamControllerPad_Right;
		default: eTargetPad = k_ESteamControllerPad_Left;
	}
	unsigned short usDurationMicroSec = durationMicroSec;
	
	SteamController()->TriggerHapticPulse(c_handle, eTargetPad, usDurationMicroSec);
}
DEFINE_PRIME3v(SteamWrap_TriggerHapticPulse);

void SteamWrap_TriggerRepeatedHapticPulse(int controllerHandle, int targetPad, int durationMicroSec, int offMicroSec, int repeat, int flags)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_CONTROLLER_HANDLE_ALL_CONTROLLERS;
	ESteamControllerPad eTargetPad;
	switch(targetPad)
	{
		case 0:  eTargetPad = k_ESteamControllerPad_Left;
		case 1:  eTargetPad = k_ESteamControllerPad_Right;
		default: eTargetPad = k_ESteamControllerPad_Left;
	}
	unsigned short usDurationMicroSec = durationMicroSec;
	unsigned short usOffMicroSec = offMicroSec;
	unsigned short unRepeat = repeat;
	unsigned short nFlags = flags;
	
	SteamController()->TriggerRepeatedHapticPulse(c_handle, eTargetPad, usDurationMicroSec, usOffMicroSec, unRepeat, nFlags);
}
DEFINE_PRIME6v(SteamWrap_TriggerRepeatedHapticPulse);

//---getters for constants----------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxCount()
{
	return alloc_int(STEAM_CONTROLLER_MAX_COUNT);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxCount,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxAnalogActions()
{
	return alloc_int(STEAM_CONTROLLER_MAX_ANALOG_ACTIONS);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxAnalogActions,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxDigitalActions()
{
	return alloc_int(STEAM_CONTROLLER_MAX_DIGITAL_ACTIONS);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxDigitalActions,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxOrigins()
{
	return alloc_int(STEAM_CONTROLLER_MAX_ORIGINS);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxOrigins,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMinAnalogActionData()
{
	return alloc_float(STEAM_CONTROLLER_MIN_ANALOG_ACTION_DATA);
}
DEFINE_PRIM(SteamWrap_GetControllerMinAnalogActionData,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxAnalogActionData()
{
	return alloc_float(STEAM_CONTROLLER_MAX_ANALOG_ACTION_DATA);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxAnalogActionData,0);

//-----------------------------------------------------------------------------------------------------------

void mylib_main()
{
    // Initialization code goes here
}
DEFINE_ENTRY_POINT(mylib_main);


} // extern "C"

