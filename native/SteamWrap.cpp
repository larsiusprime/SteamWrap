#define IMPLEMENT_API
#include <hx/CFFI.h>

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <vector>
#include <sstream>
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
value SteamWrap_Init(value onEvent)
{
	bool result = SteamAPI_Init();
	if (result)
	{
		g_eventHandler = new AutoGCRoot(onEvent);
		s_callbackHandler = new CallbackHandler();
		SteamUtils()->SetOverlayNotificationPosition( k_EPositionTopLeft );
	}
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_Init, 1);

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
value SteamWrap_SetAchievement(value name)
{
	if (!val_is_string(name) || !CheckInit())
		return alloc_bool(false);

	SteamUserStats()->SetAchievement(val_string(name));
	bool result = SteamUserStats()->StoreStats();

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetAchievement, 1);

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
void mylib_main()
{
    // Initialization code goes here
}
DEFINE_ENTRY_POINT(mylib_main);


} // extern "C"

