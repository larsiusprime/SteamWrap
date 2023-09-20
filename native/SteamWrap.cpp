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

#pragma region Helpers
//Thanks to Sven Bergström for these two helper functions:
inline value bytes_to_hx( const unsigned char* bytes, int byteLength )
{
	buffer buf = alloc_buffer_len(byteLength);
	char* dest = buffer_data(buf);
	memcpy(dest, bytes, byteLength);
	return buffer_val(buf);
}

inline value bytes_to_hx( unsigned char* bytes, int byteLength )
{
	buffer buf = alloc_buffer_len(byteLength);
	char* dest = buffer_data(buf);
	memcpy(dest, bytes, byteLength);
	return buffer_val(buf);
}

//just splits a string
void split(const std::string &s, char delim, std::vector<std::string> &elems) {
	std::stringstream ss;
	ss.str(s);
	std::string item;
	while (std::getline(ss, item, delim)) {
		elems.push_back(item);
	}
}

//generates a parameter string array from comma-delimeted-values
SteamParamStringArray_t * getSteamParamStringArray(const char * str)
{
	std::string stdStr = str;
	
	//NOTE: this will probably fail if the string includes Unicode, but Steam tags probably don't support that?
	std::vector<std::string> v;
	split(stdStr, ',', v);
	
	SteamParamStringArray_t * params = new SteamParamStringArray_t;
	
	int count = v.size();
	
	params->m_nNumStrings = (int32) count;
	params->m_ppStrings = new const char *[count];
	
	for(int i = 0; i < count; i++) {
		params->m_ppStrings[i] = v[i].c_str();
	}
	
	return params;
}

//generates a uint64 array from comma-delimeted-values
uint64 * getUint64Array(const char * str, uint32 * numElements)
{
	std::string stdStr = str;
	
	//NOTE: this will probably fail if the string includes Unicode, but Steam tags probably don't support that?
	std::vector<std::string> v;
	split(stdStr, ',', v);
	
	int count = v.size();
	
	uint64 * values = new uint64[count];
	
	for(int i = 0; i < count; i++) {
		values[i] = strtoull(v[i].c_str(), NULL, 0);
	}
	
	*numElements = count;
	
	return values;
}

void deleteSteamParamStringArray(SteamParamStringArray_t * params)
{
	for(int i = 0; i < params->m_nNumStrings; i++){
		delete params->m_ppStrings[i];
	}
	delete[] params->m_ppStrings;
	delete params;
}

inline value id_to_hx(CSteamID id) {
	std::ostringstream r;
	r << id.ConvertToUint64();
	return alloc_string(r.str().c_str());
}

inline CSteamID hx_to_id(value hx) {
	return strtoull(val_string(hx), NULL, 0);
}
inline CSteamID hx_to_id(const char* hx) {
	return strtoull(hx, NULL, 0);
}

AutoGCRoot *g_eventHandler = 0;

#pragma endregion

#pragma region Macros
// Sets up a default return value and checks for init-exit.
#define swp_start(defValue)\
	value __defValue__ = defValue;\
	if (!CheckInit()) return __defValue__;
// Requires condition to be met for function to proceed.
#define swp_req(expr) if (!(expr)) return __defValue__;
// Sets up and checks for an int parameter.
#define swp_int(name, value)\
	if (!val_is_int(value)) {\
		hx_failure("Expected " #name " to be an int.");\
		return __defValue__;\
	};\
	int name = val_int(value);
// Sets up and checks for a string parameter.
#define swp_string(name, value)\
	if (!val_is_string(value)) {\
		hx_failure("Expected " #name " to be a string.");\
		return __defValue__;\
	};\
	auto name = val_string(value);
// Default/blank Steam ID
#define val_noid alloc_string("0")

#pragma endregion

#pragma region Events & callbacks
//-----------------------------------------------------------------------------------------------------------
// Event
//-----------------------------------------------------------------------------------------------------------
static const char* kEventTypeNone = "None";
static const char* kEventTypeOnGamepadTextInputDismissed = "GamepadTextInputDismissed";
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
static const char* kEventTypeOnFileShared = "RemoteStorageFileShared";
static const char* kEventTypeOnEnumerateUserSharedWorkshopFiles = "UserSharedWorkshopFilesEnumerated";
static const char* kEventTypeOnEnumerateUserPublishedFiles = "UserPublishedFilesEnumerated";
static const char* kEventTypeOnEnumerateUserSubscribedFiles = "UserSubscribedFilesEnumerated";
static const char* kEventTypeOnUGCDownload = "UGCDownloaded";
static const char* kEventTypeOnGetPublishedFileDetails = "PublishedFileDetailsGotten";
static const char* kEventTypeOnDownloadItem = "ItemDownloaded";
static const char* kEventTypeOnItemInstalled = "ItemInstalled";
static const char* kEventTypeOnUGCQueryCompleted = "UGCQueryCompleted";
static const char* kEventTypeOnLobbyJoined = "LobbyJoined";
static const char* kEventTypeOnLobbyJoinRequested = "LobbyJoinRequested";
static const char* kEventTypeOnLobbyCreated = "LobbyCreated";
static const char* kEventTypeOnLobbyListReceived = "LobbyListReceived";

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
static ControllerMotionData_t motionData;

struct Event
{
	const char* m_type;
	int m_success;
	value m_data;
	Event(const char* type, bool success=false, const std::string& data="") :
		m_type(type), m_success(success), m_data(alloc_string(data.c_str())) {}
	Event(const char* type, bool success, value data) :
		m_type(type), m_success(success), m_data(data) {}
};

static void SendEvent(const Event& e)
{
	// http://code.google.com/p/nmex/source/browse/trunk/project/common/ExternalInterface.cpp
	if (!g_eventHandler) return;
    value obj = alloc_empty_object();
    alloc_field(obj, val_id("type"), alloc_string(e.m_type));
    alloc_field(obj, val_id("success"), alloc_int(e.m_success ? 1 : 0));
    alloc_field(obj, val_id("data"), e.m_data);
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
 		m_CallbackAchievementStored( this, &CallbackHandler::OnAchievementStored ),
		m_CallbackGamepadTextInputDismissed( this, &CallbackHandler::OnGamepadTextInputDismissed ),
		m_CallbackDownloadItemResult( this, &CallbackHandler::OnDownloadItem ),
		m_CallbackItemInstalled( this, &CallbackHandler::OnItemInstalled )
	{}

	STEAM_CALLBACK( CallbackHandler, OnUserStatsReceived, UserStatsReceived_t, m_CallbackUserStatsReceived );
	STEAM_CALLBACK( CallbackHandler, OnUserStatsStored, UserStatsStored_t, m_CallbackUserStatsStored );
	STEAM_CALLBACK( CallbackHandler, OnAchievementStored, UserAchievementStored_t, m_CallbackAchievementStored );
	STEAM_CALLBACK( CallbackHandler, OnGamepadTextInputDismissed, GamepadTextInputDismissed_t, m_CallbackGamepadTextInputDismissed );
	STEAM_CALLBACK( CallbackHandler, OnDownloadItem, DownloadItemResult_t, m_CallbackDownloadItemResult );
	STEAM_CALLBACK( CallbackHandler, OnItemInstalled, ItemInstalled_t, m_CallbackItemInstalled );
	STEAM_CALLBACK( CallbackHandler, OnLobbyJoinRequested, GameLobbyJoinRequested_t );
	
	void FindLeaderboard(const char* name);
	void OnLeaderboardFound( LeaderboardFindResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LeaderboardFindResult_t> m_callResultFindLeaderboard;

	bool UploadScore(const std::string& leaderboardId, int score, int detail);
	void OnScoreUploaded( LeaderboardScoreUploaded_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LeaderboardScoreUploaded_t> m_callResultUploadScore;

	bool DownloadScores(const std::string& leaderboardId, int downloadType, int numBefore, int numAfter);
	void OnScoreDownloaded( LeaderboardScoresDownloaded_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LeaderboardScoresDownloaded_t> m_callResultDownloadScore;

	void RequestGlobalStats();
	void OnGlobalStatsReceived(GlobalStatsReceived_t* pResult, bool bIOFailure);
	CCallResult<CallbackHandler, GlobalStatsReceived_t> m_callResultRequestGlobalStats;

	void CreateUGCItem(AppId_t nConsumerAppId, EWorkshopFileType eFileType);
	void OnUGCItemCreated( CreateItemResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, CreateItemResult_t> m_callResultCreateUGCItem;
	
	void SendQueryUGCRequest(UGCQueryHandle_t handle);
	void OnUGCQueryCompleted( SteamUGCQueryCompleted_t* pResult, bool bIOFailure); 
	CCallResult<CallbackHandler, SteamUGCQueryCompleted_t> m_callResultUGCQueryCompleted;
	
	void SubmitUGCItemUpdate(UGCUpdateHandle_t handle, const char *pchChangeNote);
	void OnItemUpdateSubmitted( SubmitItemUpdateResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, SubmitItemUpdateResult_t> m_callResultSubmitUGCItemUpdate;
	
	void EnumerateUserSharedWorkshopFiles( CSteamID steamId, uint32 unStartIndex, SteamParamStringArray_t *pRequiredTags, SteamParamStringArray_t *pExcludedTags );
	void OnEnumerateUserSharedWorkshopFiles( RemoteStorageEnumerateUserPublishedFilesResult_t * pResult, bool bIOFailure);
	CCallResult<CallbackHandler, RemoteStorageEnumerateUserPublishedFilesResult_t > m_callResultEnumerateUserSharedWorkshopFiles;
	
	void EnumerateUserSubscribedFiles ( uint32 unStartIndex );
	void OnEnumerateUserSubscribedFiles ( RemoteStorageEnumerateUserSubscribedFilesResult_t * pResult, bool bIOFailure);
	CCallResult<CallbackHandler, RemoteStorageEnumerateUserSubscribedFilesResult_t > m_callResultEnumerateUserSubscribedFiles;
	
	void EnumerateUserPublishedFiles ( uint32 unStartIndex );
	void OnEnumerateUserPublishedFiles ( RemoteStorageEnumerateUserPublishedFilesResult_t * pResult, bool bIOFailure);
	CCallResult<CallbackHandler, RemoteStorageEnumerateUserPublishedFilesResult_t > m_callResultEnumerateUserPublishedFiles;
	
	void UGCDownload ( UGCHandle_t hContent, uint32 unPriority );
	void OnUGCDownload ( RemoteStorageDownloadUGCResult_t * pResult, bool bIOFailure);
	CCallResult<CallbackHandler, RemoteStorageDownloadUGCResult_t  > m_callResultUGCDownload;
	
	void GetPublishedFileDetails ( PublishedFileId_t unPublishedFileId, uint32 unMaxSecondsOld );
	void OnGetPublishedFileDetails ( RemoteStorageGetPublishedFileDetailsResult_t * pResult, bool bIOFailure);
	CCallResult<CallbackHandler, RemoteStorageGetPublishedFileDetailsResult_t > m_callResultGetPublishedFileDetails;
	
	void FileShare(const char* fileName);
	void OnFileShared( RemoteStorageFileShareResult_t *pResult, bool bIOFailure);
	CCallResult<CallbackHandler, RemoteStorageFileShareResult_t> m_callResultFileShare;

	void LobbyJoin(CSteamID id);
	void OnLobbyJoined(LobbyEnter_t* pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LobbyEnter_t> m_callResultLobbyJoined;
	
	void LobbyCreate(int kind, int maxMembers);
	void OnLobbyCreated(LobbyCreated_t* pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LobbyCreated_t> m_callResultLobbyCreated;

	void LobbyListRequest();
	void OnLobbyListReceived(LobbyMatchList_t* pResult, bool bIOFailure);
	CCallResult<CallbackHandler, LobbyMatchList_t> m_callResultLobbyListReceived;
};

#pragma region Callback implementations

void CallbackHandler::OnGamepadTextInputDismissed( GamepadTextInputDismissed_t *pCallback )
{
	SendEvent(Event(kEventTypeOnGamepadTextInputDismissed, pCallback->m_bSubmitted));
}

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

void CallbackHandler::SendQueryUGCRequest(UGCQueryHandle_t handle)
{
	SteamAPICall_t hSteamAPICall = SteamUGC()->SendQueryUGCRequest(handle);
	m_callResultUGCQueryCompleted.Set(hSteamAPICall, this, &CallbackHandler::OnUGCQueryCompleted);
}

void CallbackHandler::OnUGCQueryCompleted(SteamUGCQueryCompleted_t *pCallback, bool biOFailure)
{
	if (pCallback->m_eResult == k_EResultOK)
	{
		std::ostringstream data;
		data << pCallback->m_handle << ",";
		data << pCallback->m_unNumResultsReturned << ",";
		data << pCallback->m_unTotalMatchingResults << ",";
		data << pCallback->m_bCachedData;
		
		SendEvent(Event(kEventTypeOnUGCQueryCompleted, true, data.str().c_str()));
	}
	else
	{
		SendEvent(Event(kEventTypeOnUGCQueryCompleted, false));
	}
}

void CallbackHandler::SubmitUGCItemUpdate(UGCUpdateHandle_t handle, const char *pchChangeNote)
{
	SteamAPICall_t hSteamAPICall = SteamUGC()->SubmitItemUpdate(handle, pchChangeNote);
	m_callResultSubmitUGCItemUpdate.Set(hSteamAPICall, this, &CallbackHandler::OnItemUpdateSubmitted);
}

void CallbackHandler::OnItemUpdateSubmitted(SubmitItemUpdateResult_t *pCallback, bool bIOFailure)
{
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

void CallbackHandler::FileShare(const char * fileName)
{
	SteamAPICall_t hSteamAPICall = SteamRemoteStorage()->FileShare(fileName);
	m_callResultFileShare.Set(hSteamAPICall, this, &CallbackHandler::OnFileShared);
}

static std::string toLeaderboardScore(const char* leaderboardName, const char* userName, int score, int detail, int rank)
{
	std::ostringstream data;
	data << leaderboardName << "," << userName << "," << score << "," << detail << "," << rank;
	return data.str();
}

void CallbackHandler::OnScoreUploaded(LeaderboardScoreUploaded_t *pCallback, bool bIOFailure)
{
	if (pCallback->m_bSuccess && !bIOFailure)
	{
		std::string leaderboardName = SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard);
		std::string data = toLeaderboardScore(SteamUserStats()->GetLeaderboardName(pCallback->m_hSteamLeaderboard), "Score Uploaded", pCallback->m_nScore, -1, pCallback->m_nGlobalRankNew);
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

void CallbackHandler::OnFileShared(RemoteStorageFileShareResult_t *pCallback, bool bIOFailure)
{
	if (pCallback->m_eResult == k_EResultOK && !bIOFailure)
	{
		UGCHandle_t rawHandle = pCallback->m_hFile;
		
		//convert uint64 handle to string
		std::ostringstream strHandle;
		strHandle << rawHandle;
		
		SendEvent(Event(kEventTypeOnFileShared, true, strHandle.str()));
	}
	else
	{
		SendEvent(Event(kEventTypeOnFileShared, false));
	}
}

bool CallbackHandler::DownloadScores(const std::string& leaderboardId, int downloadType, int numBefore, int numAfter)
{
   	if (m_leaderboards.find(leaderboardId) == m_leaderboards.end() || m_leaderboards[leaderboardId] == 0)
   		return false;

	SteamAPICall_t hSteamAPICall;

	// download user scores with the correct download type
	if (downloadType == 0) {
		hSteamAPICall = SteamUserStats()->DownloadLeaderboardEntries(m_leaderboards[leaderboardId], k_ELeaderboardDataRequestGlobal, -numBefore, numAfter);
	}
	else if (downloadType == 1) {
		hSteamAPICall = SteamUserStats()->DownloadLeaderboardEntries(m_leaderboards[leaderboardId], k_ELeaderboardDataRequestGlobalAroundUser, -numBefore, numAfter);
	}
	else if (downloadType == 2) {
		hSteamAPICall = SteamUserStats()->DownloadLeaderboardEntries(m_leaderboards[leaderboardId], k_ELeaderboardDataRequestFriends, -numBefore, numAfter);
	}

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
		data << toLeaderboardScore(leaderboardId.c_str(), SteamFriends()->GetFriendPersonaName(entry.m_steamIDUser), entry.m_nScore, details[0], entry.m_nGlobalRank).c_str();
		haveData = true;
	}

	if (haveData)
	{
		SendEvent(Event(kEventTypeOnScoreDownloaded, true, data.str()));
	}
	else
	{
		// ok but no scores
		SendEvent(Event(kEventTypeOnScoreDownloaded, true, toLeaderboardScore(leaderboardId.c_str(), "No Scores", -1, -1, -1)));
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

void CallbackHandler::EnumerateUserPublishedFiles( uint32 unStartIndex )
{
	SteamAPICall_t hSteamAPICall = SteamRemoteStorage()->EnumerateUserPublishedFiles(unStartIndex);
	m_callResultEnumerateUserPublishedFiles.Set(hSteamAPICall, this, &CallbackHandler::OnEnumerateUserPublishedFiles);
}

void CallbackHandler::OnEnumerateUserPublishedFiles(RemoteStorageEnumerateUserPublishedFilesResult_t* pResult, bool bIOFailure)
{
	if (!bIOFailure)
	{
		if(pResult->m_eResult == k_EResultOK)
		{
			std::ostringstream data;
			
			data << "result:";
			data << pResult->m_eResult;
			data << ",resultsReturned:";
			data << pResult->m_nResultsReturned;
			data << ",totalResults:";
			data << pResult->m_nTotalResultCount;
			data << ",publishedFileIds:";
			
			for(int32 i = 0; i < pResult->m_nResultsReturned; ++i) {
				
				data << pResult->m_rgPublishedFileId[i];
				if(i != pResult->m_nResultsReturned-1){
					data << ',';
				}
				
			}
			
			SendEvent(Event(kEventTypeOnEnumerateUserPublishedFiles, pResult->m_eResult == k_EResultOK, data.str()));
			return;
		}
	}
	SendEvent(Event(kEventTypeOnEnumerateUserSharedWorkshopFiles, false));
}

void CallbackHandler::EnumerateUserSharedWorkshopFiles( CSteamID steamId, uint32 unStartIndex, SteamParamStringArray_t *pRequiredTags, SteamParamStringArray_t *pExcludedTags )
{
	SteamAPICall_t hSteamAPICall = SteamRemoteStorage()->EnumerateUserSharedWorkshopFiles(steamId, unStartIndex, pRequiredTags, pExcludedTags);
	m_callResultEnumerateUserSharedWorkshopFiles.Set(hSteamAPICall, this, &CallbackHandler::OnEnumerateUserSharedWorkshopFiles);
}

void CallbackHandler::OnEnumerateUserSharedWorkshopFiles(RemoteStorageEnumerateUserPublishedFilesResult_t* pResult, bool bIOFailure)
{
	if(pResult->m_eResult == k_EResultOK)
	{
		std::ostringstream data;
		
		data << "result:";
		data << pResult->m_eResult;
		data << ",resultsReturned:";
		data << pResult->m_nResultsReturned;
		data << ",totalResults:";
		data << pResult->m_nTotalResultCount;
		data << ",publishedFileIds:";
		
		for(int32 i = 0; i < pResult->m_nResultsReturned; ++i) {
			
			data << pResult->m_rgPublishedFileId[i];
			if(i != pResult->m_nResultsReturned-1){
				data << ',';
			}
			
		}
		
		SendEvent(Event(kEventTypeOnEnumerateUserSharedWorkshopFiles, pResult->m_eResult == k_EResultOK, data.str()));
		return;
	}
	SendEvent(Event(kEventTypeOnEnumerateUserSharedWorkshopFiles, false));
}

void CallbackHandler::EnumerateUserSubscribedFiles( uint32 unStartIndex )
{
	SteamAPICall_t hSteamAPICall = SteamRemoteStorage()->EnumerateUserSubscribedFiles( unStartIndex );
	m_callResultEnumerateUserSubscribedFiles.Set(hSteamAPICall, this, &CallbackHandler::OnEnumerateUserSubscribedFiles);
}

void CallbackHandler::OnEnumerateUserSubscribedFiles(RemoteStorageEnumerateUserSubscribedFilesResult_t* pResult, bool bIOFailure)
{
	if(pResult->m_eResult == k_EResultOK)
	{
		std::ostringstream data;
		
		data << "result:";
		data << pResult->m_eResult;
		data << ",resultsReturned:";
		data << pResult->m_nResultsReturned;
		data << ",totalResults:";
		data << pResult->m_nTotalResultCount;
		data << ",publishedFileIds:";
		
		for(int32 i = 0; i < pResult->m_nResultsReturned; ++i) {
			
			data << pResult->m_rgPublishedFileId[i];
			if(i != pResult->m_nResultsReturned-1){
				data << ',';
			}
			
		}
		
		data << ",timeSubscribed:";
		
		for(int32 i = 0; i < pResult->m_nResultsReturned; ++i) {
			
			data << pResult->m_rgRTimeSubscribed[i];
			if(i != pResult->m_nResultsReturned-1){
				data << ',';
			}
			
		}
		
		SendEvent(Event(kEventTypeOnEnumerateUserSubscribedFiles, pResult->m_eResult == k_EResultOK, data.str()));
		return;
	}
	SendEvent(Event(kEventTypeOnEnumerateUserSubscribedFiles, false));
}

void CallbackHandler::GetPublishedFileDetails( PublishedFileId_t unPublishedFileId, uint32 unMaxSecondsOld )
{
	SteamAPICall_t hSteamAPICall = SteamRemoteStorage()->GetPublishedFileDetails( unPublishedFileId, unMaxSecondsOld);
	m_callResultGetPublishedFileDetails.Set(hSteamAPICall, this, &CallbackHandler::OnGetPublishedFileDetails);
}

void CallbackHandler::OnGetPublishedFileDetails(RemoteStorageGetPublishedFileDetailsResult_t* pResult, bool bIOFailure)
{
	if(pResult->m_eResult == k_EResultOK)
	{
		std::ostringstream data;
		
		data << "result:";
		data << pResult->m_eResult;
		data << ",publishedFileID:";
		data << pResult->m_nPublishedFileId;
		data << ",creatorAppID:";
		data << pResult->m_nCreatorAppID;
		data << ",consumerAppID:";
		data << pResult->m_nConsumerAppID;
		data << ",title:";
		data << pResult->m_rgchTitle;
		data << ",description:";
		data << pResult->m_rgchDescription;
		data << ",fileHandle:";
		data << pResult->m_hFile;
		data << ",previewFileHandle:";
		data << pResult->m_hPreviewFile;
		data << ",steamIDOwner:";
		data << pResult->m_ulSteamIDOwner;
		data << ",timeCreated:";
		data << pResult->m_rtimeCreated;
		data << ",timeUpdated";
		data << pResult->m_rtimeUpdated;
		data << ",visibility:";
		data << pResult->m_eVisibility;
		data << ",banned:";
		data << pResult->m_bBanned;
		data << ",tags:";
		data << pResult->m_rgchTags;
		data << ",tagsTruncated:";
		data << pResult->m_bTagsTruncated;
		data << ",fileName:";
		data << pResult->m_pchFileName;
		data << ",fileSize:";
		data << pResult->m_nFileSize;
		data << ",previewFileSize:";
		data << pResult->m_nPreviewFileSize;
		data << ",url:";
		data << pResult->m_rgchURL;
		data << ",fileType:",
		data << pResult->m_eFileType;
		data << ",acceptedForUse:",
		data << pResult->m_bAcceptedForUse;
		
		SendEvent(Event(kEventTypeOnGetPublishedFileDetails, pResult->m_eResult == k_EResultOK, data.str()));
		return;
	}
	SendEvent(Event(kEventTypeOnGetPublishedFileDetails, false));
}

void CallbackHandler::UGCDownload( UGCHandle_t hContent, uint32 unPriority )
{
	SteamAPICall_t hSteamAPICall = SteamRemoteStorage()->UGCDownload( hContent, unPriority );
	m_callResultUGCDownload.Set(hSteamAPICall, this, &CallbackHandler::OnUGCDownload);
}

void CallbackHandler::OnUGCDownload(RemoteStorageDownloadUGCResult_t* pResult, bool bIOFailure)
{
	if(pResult->m_eResult == k_EResultOK)
	{
		std::ostringstream data;
		
		data << "result:";
		data << pResult->m_eResult;
		data << ",fileHandle:";
		data << pResult->m_hFile;
		data << ",appID:";
		data << pResult->m_nAppID;
		data << ",sizeInBytes:";
		data << pResult->m_nSizeInBytes;
		data << ",fileName:";
		data << pResult->m_pchFileName;
		data << ",steamIDOwner:";
		data << pResult->m_ulSteamIDOwner;
		
		SendEvent(Event(kEventTypeOnUGCDownload, pResult->m_eResult == k_EResultOK, data.str()));
		return;
	}
	SendEvent(Event(kEventTypeOnUGCDownload, false));
}

void CallbackHandler::OnDownloadItem( DownloadItemResult_t *pCallback )
{
	if (pCallback->m_unAppID != SteamUtils()->GetAppID()) return;
	
	std::ostringstream fileIDStream;
	PublishedFileId_t m_ugcFileID = pCallback->m_nPublishedFileId;
	fileIDStream << m_ugcFileID;
	SendEvent(Event(kEventTypeOnDownloadItem, pCallback->m_eResult == k_EResultOK, fileIDStream.str().c_str()));
}

void CallbackHandler::OnItemInstalled( ItemInstalled_t *pCallback )
{
	if (pCallback->m_unAppID != SteamUtils()->GetAppID()) return;
	
	std::ostringstream fileIDStream;
	PublishedFileId_t m_ugcFileID = pCallback->m_nPublishedFileId;
	fileIDStream << m_ugcFileID;
	SendEvent(Event(kEventTypeOnDownloadItem, true, fileIDStream.str().c_str()));
}

#pragma endregion
//-----------------------------------------------------------------------------------------------------------
static CallbackHandler* s_callbackHandler = NULL;

#pragma endregion

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

#pragma region Stats
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
value SteamWrap_GetStatFloat(value name)
{
	if (!val_is_string(name)|| !CheckInit())
		return alloc_float(0.0);

	float val = 0.0;
	SteamUserStats()->GetStat(val_string(name), &val);
	return alloc_float(val);
}
DEFINE_PRIM(SteamWrap_GetStatFloat, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetStatInt(value name)
{
	if (!val_is_string(name)|| !CheckInit())
		return alloc_int(0);

	int val = 0;
	SteamUserStats()->GetStat(val_string(name), &val);
	return alloc_int(val);
}
DEFINE_PRIM(SteamWrap_GetStatInt, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetStat(value name, value val)
{
	if (!val_is_string(name) || !val_is_int(val) || !CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->SetStat(val_string(name), (int) val_int(val));

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetStat, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetStatFloat(value name, value val)
{
	if (!val_is_string(name) || !val_is_float(val) || !CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->SetStat(val_string(name), (float) val_float(val));

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetStatFloat, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_SetStatInt(value name, value val)
{
	if (!val_is_string(name) || !val_is_int(val) || !CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->SetStat(val_string(name), (int) val_int(val));

	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetStatInt, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_StoreStats()
{
	if (!CheckInit())
		return alloc_bool(false);

	bool result = SteamUserStats()->StoreStats();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_StoreStats, 0);

#pragma endregion

#pragma region UGC
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
value SteamWrap_SetUGCItemTags(value updateHandle, value tags)
{
	if (!val_is_string(updateHandle) || !val_is_string(tags) || !CheckInit())
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
	
	// Create tag array from the string.
	SteamParamStringArray_t *pTags = getSteamParamStringArray(val_string(tags));
	
	bool result = SteamUGC()->SetItemTags(updateHandle64, pTags);
	
	deleteSteamParamStringArray(pTags);
	
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_SetUGCItemTags, 2);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_AddUGCItemKeyValueTag(value updateHandle, value keyStr, value valueStr)
{
	if (!CheckInit()) return alloc_bool(false);
	if (!val_is_string(updateHandle)) return alloc_bool(false);
	if (!val_is_string(keyStr)) return alloc_bool(false);
	if (!val_is_string(valueStr)) return alloc_bool(false);
	
	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}
	
	bool result = SteamUGC()->AddItemKeyValueTag(updateHandle64, val_string(keyStr), val_string(valueStr));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_AddUGCItemKeyValueTag, 3);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_RemoveUGCItemKeyValueTags(value updateHandle, value keyStr)
{
	if (!CheckInit()) return alloc_bool(false);
	if (!val_is_string(updateHandle)) return alloc_bool(false);
	if (!val_is_string(keyStr)) return alloc_bool(false);
	
	// Create uint64 from the string.
	uint64 updateHandle64;
	std::istringstream handleStream(val_string(updateHandle));
	if (!(handleStream >> updateHandle64))
	{
		return alloc_bool(false);
	}
	
	bool result = SteamUGC()->RemoveItemKeyValueTags(updateHandle64, val_string(keyStr));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_RemoveUGCItemKeyValueTags, 2);

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
int SteamWrap_AddRequiredTag(const char * handle, const char * tagName)
{
	if (!CheckInit()) return 0;
	
	UGCQueryHandle_t u64Handle = strtoull(handle, NULL, 0);
	
	bool result = SteamUGC()->AddRequiredTag(u64Handle, tagName);
	return result;
}
DEFINE_PRIME2(SteamWrap_AddRequiredTag);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_AddRequiredKeyValueTag(const char * handle, const char * pKey, const char * pValue)
{
	if (!CheckInit()) return 0;
	
	UGCQueryHandle_t u64Handle = strtoull(handle, NULL, 0);
	
	bool result = SteamUGC()->AddRequiredKeyValueTag(u64Handle, pKey, pValue);
	return result;
}
DEFINE_PRIME3(SteamWrap_AddRequiredKeyValueTag);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_AddExcludedTag(const char * handle, const char * tagName)
{
	if (!CheckInit()) return 0;
	
	UGCQueryHandle_t u64Handle = strtoull(handle, NULL, 0);
	
	bool result = SteamUGC()->AddExcludedTag(u64Handle, tagName);
	return result;
}
DEFINE_PRIME2(SteamWrap_AddExcludedTag);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_SetReturnMetadata(const char * handle, int returnMetadata)
{
	if (!CheckInit()) return 0;
	
	UGCQueryHandle_t u64Handle = strtoull(handle, NULL, 0);
	
	bool result = SteamUGC()->SetReturnMetadata(u64Handle, returnMetadata == 1);
	return result;
}
DEFINE_PRIME2(SteamWrap_SetReturnMetadata);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_SetReturnKeyValueTags(const char * handle, int returnKeyValueTags)
{
	if (!CheckInit()) return 0;
	
	UGCQueryHandle_t u64Handle = strtoull(handle, NULL, 0);
	bool setValue = returnKeyValueTags == 1;
	
	bool result = SteamUGC()->SetReturnKeyValueTags(u64Handle, setValue);
	return result;
}
DEFINE_PRIME2(SteamWrap_SetReturnKeyValueTags);

#pragma endregion

#pragma region Scores/Achievements
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
value SteamWrap_DownloadScores(value name, value downloadType, value numBefore, value numAfter)
{
	if (!val_is_string(name) || !val_is_int(downloadType) || !val_is_int(numBefore) || !val_is_int(numAfter) || !CheckInit())
		return alloc_bool(false);

	bool result = s_callbackHandler->DownloadScores(val_string(name), val_int(downloadType), val_int(numBefore), val_int(numAfter));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_DownloadScores, 4);

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
value SteamWrap_GetPersonaName()
{
	if(!CheckInit())
		return alloc_string("unknown");
	
	const char * persona = SteamFriends()->GetPersonaName();
	
	return alloc_string(persona);
}
DEFINE_PRIM(SteamWrap_GetPersonaName, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_BIsAppInstalled(value appID)
{
	if(!val_is_int(appID) || !CheckInit()) return alloc_bool(false);
	bool result = SteamApps()->BIsAppInstalled(val_int(appID));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_BIsAppInstalled, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_BIsDlcInstalled(value appID)
{
	if(!val_is_int(appID) || !CheckInit()) return alloc_bool(false);
	bool result = SteamApps()->BIsDlcInstalled(val_int(appID));
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_BIsDlcInstalled, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetSteamID()
{
	if(!CheckInit())
		return alloc_string("0");
	
	CSteamID userId = SteamUser()->GetSteamID();
	
	std::ostringstream returnData;
	returnData << userId.ConvertToUint64();
	
	return alloc_string(returnData.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetSteamID, 0);

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
value SteamWrap_IsOverlayEnabled()
{
	bool result = SteamUtils()->IsOverlayEnabled();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_IsOverlayEnabled, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_BOverlayNeedsPresent()
{
	bool result = SteamUtils()->BOverlayNeedsPresent();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_BOverlayNeedsPresent, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_IsSteamInBigPictureMode()
{
	bool result = SteamUtils()->IsSteamInBigPictureMode();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_IsSteamInBigPictureMode, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_IsSteamRunning()
{
	bool result = SteamAPI_IsSteamRunning();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_IsSteamRunning, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_IsSteamRunningOnSteamDeck()
{
	bool result = SteamUtils()->IsSteamRunningOnSteamDeck();
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_IsSteamRunningOnSteamDeck, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetCurrentGameLanguage()
{
	const char* result = SteamApps()->GetCurrentGameLanguage();
	return alloc_string(result);
}
DEFINE_PRIM(SteamWrap_GetCurrentGameLanguage, 0);

//-----------------------------------------------------------------------------------------------------------

#pragma endregion

#pragma region New Workshop
//NEW STEAM WORKSHOP---------------------------------------------------------------------------------------------

int SteamWrap_GetNumSubscribedItems(int dummy)
{
	if (!CheckInit()) return 0;
	int numItems = SteamUGC()->GetNumSubscribedItems();
	return numItems;
}
DEFINE_PRIME1(SteamWrap_GetNumSubscribedItems);

value SteamWrap_GetSubscribedItems()
{
	if (!CheckInit()) return alloc_string("");
	
	int numSubscribed = SteamUGC()->GetNumSubscribedItems();
	if(numSubscribed <= 0) return alloc_string("");
	PublishedFileId_t* pvecPublishedFileID = new PublishedFileId_t[numSubscribed];
	
	int result = SteamUGC()->GetSubscribedItems(pvecPublishedFileID, numSubscribed);
	
	std::ostringstream data;
	for(int i = 0; i < result; i++){
		if(i != 0){
			data << ",";
		}
		data << pvecPublishedFileID[i];
	}
	delete pvecPublishedFileID;
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetSubscribedItems, 0);

int SteamWrap_GetItemState(const char * publishedFileID)
{
	if (!CheckInit()) return 0;
	PublishedFileId_t nPublishedFileID = (PublishedFileId_t) strtoll(publishedFileID, NULL, 10);
	return SteamUGC()->GetItemState(nPublishedFileID);
}
DEFINE_PRIME1(SteamWrap_GetItemState);

value SteamWrap_GetItemDownloadInfo(value publishedFileID)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(publishedFileID)) return alloc_string("");
	
	PublishedFileId_t nPublishedFileID = (PublishedFileId_t) strtoll(val_string(publishedFileID), NULL, 10);
	
	uint64 punBytesDownloaded;
	uint64 punBytesTotal;
	
	bool result = SteamUGC()->GetItemDownloadInfo(nPublishedFileID, &punBytesDownloaded, &punBytesTotal);
	
	if(result){
		std::ostringstream data;
		data << punBytesDownloaded;
		data << ",";
		data << punBytesTotal;
		return alloc_string(data.str().c_str());
	}
	
	return alloc_string("0,0");
}
DEFINE_PRIM(SteamWrap_GetItemDownloadInfo, 1);

int SteamWrap_DownloadItem(const char * publishedFileID, int highPriority)
{
	if (!CheckInit()) return false;
	PublishedFileId_t nPublishedFileID = (PublishedFileId_t) strtoll(publishedFileID, NULL, 10);
	
	bool bHighPriority = highPriority == 1;
	bool result = SteamUGC()->DownloadItem(nPublishedFileID, bHighPriority);
	return result;
}
DEFINE_PRIME2(SteamWrap_DownloadItem);

value SteamWrap_GetItemInstallInfo(value publishedFileID, value maxFolderPathLength)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(publishedFileID)) return alloc_string("");
	if (!val_is_int(maxFolderPathLength)) return alloc_string("");
	
	PublishedFileId_t nPublishedFileID = (PublishedFileId_t) strtoll(val_string(publishedFileID), NULL, 10);
	
	uint64 punSizeOnDisk;
	uint32 punTimeStamp;
	uint32 cchFolderSize = (uint32) val_int(maxFolderPathLength);
	char * pchFolder = new char[cchFolderSize];
	
	bool result = SteamUGC()->GetItemInstallInfo(nPublishedFileID, &punSizeOnDisk, pchFolder, cchFolderSize, &punTimeStamp);
	
	if(result){
		std::ostringstream data;
		data << punSizeOnDisk;
		data << "|";
		data << pchFolder;
		data << "|";
		data << cchFolderSize;
		data << "|";
		data << punTimeStamp;
		return alloc_string(data.str().c_str());
	}
	
	return alloc_string("0||0|");
}
DEFINE_PRIM(SteamWrap_GetItemInstallInfo, 2);

/*
value SteamWrap_CreateQueryUserUGCRequest(value accountID, value listType, value matchingUGCType, value sortOrder, value creatorAppID, value consumerAppID, value page)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_int(accountID)) return alloc_string("");
	if (!val_is_int(listType)) return alloc_string("");
	if (!val_is_int(matchingUGCType)) return alloc_string("");
	if (!val_is_int(sortOrder)) return alloc_string("");
	if (!val_is_int(creatorAppID)) return alloc_string("");
	if (!val_is_int(consumerAppID)) return alloc_string("");
	if (!val_is_int(page)) return alloc_string("");
	
	AccountID_t unAccountID = val_int(accountID);
	EUserUGCList eListType = val_int(listType);
	EUGCMatchingUGCType eMatchingUGCType = val_int(matchingUGCType);
	EUserUGCListSortOrder eSortOrder = val_int(sortOrder);
	AppID_t nCreatorAppID = val_int(creatorAppID);
	AppId_t nConsumerAppID = val_int(consumerAppID);
	uint32 page = val_int(page);
	
	UGCQueryHandle_t result = SteamUGC()->SteamWrap_CreateQueryUserUGCRequest(unAccountID, eListType, eMatchingUGCType, eSortOrder, nCreatorAppID, nConsumerAppId, unPage);
	
	std:ostringstream data;
	data << result;
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_CreateQueryUserUGCRequest, 7);
*/

value SteamWrap_CreateQueryAllUGCRequest(value queryType, value matchingUGCType, value creatorAppID, value consumerAppID, value page)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_int(queryType)) return alloc_string("");
	if (!val_is_int(matchingUGCType)) return alloc_string("");
	if (!val_is_int(creatorAppID)) return alloc_string("");
	if (!val_is_int(consumerAppID)) return alloc_string("");
	if (!val_is_int(page)) return alloc_string("");
	
	EUGCQuery eQueryType = (EUGCQuery) val_int(queryType);
	EUGCMatchingUGCType eMatchingUGCType = (EUGCMatchingUGCType) val_int(matchingUGCType);
	AppId_t nCreatorAppID = val_int(creatorAppID);
	AppId_t nConsumerAppID = val_int(consumerAppID);
	uint32 unPage = val_int(page);
	
	UGCQueryHandle_t result = SteamUGC()->CreateQueryAllUGCRequest(eQueryType, eMatchingUGCType, nCreatorAppID, nConsumerAppID, unPage);
	
	std::ostringstream data;
	data << result;
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_CreateQueryAllUGCRequest, 5);

value SteamWrap_CreateQueryUGCDetailsRequest(value fileIDs)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(fileIDs)) return alloc_string("");
	uint32 unNumPublishedFileIDs = 0;
	PublishedFileId_t * pvecPublishedFileID = getUint64Array(val_string(fileIDs), &unNumPublishedFileIDs);
	
	UGCQueryHandle_t result = SteamUGC()->CreateQueryUGCDetailsRequest(pvecPublishedFileID, unNumPublishedFileIDs);
	
	std::ostringstream data;
	data << result;
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_CreateQueryUGCDetailsRequest, 1);


void SteamWrap_SendQueryUGCRequest(const char * cHandle)
{
	if (!CheckInit()) return;
	
	UGCQueryHandle_t handle = strtoull(cHandle, NULL, 0);
	
	s_callbackHandler->SendQueryUGCRequest(handle);
}
DEFINE_PRIME1v(SteamWrap_SendQueryUGCRequest);


int SteamWrap_GetQueryUGCNumKeyValueTags(const char * cHandle, int iIndex)
{
	if (!CheckInit()) return 0;
	
	UGCQueryHandle_t handle = strtoull(cHandle, NULL, 0);
	uint32 index = iIndex;
	
	return SteamUGC()->GetQueryUGCNumKeyValueTags(handle, index);
}
DEFINE_PRIME2(SteamWrap_GetQueryUGCNumKeyValueTags);

int SteamWrap_ReleaseQueryUGCRequest(const char * cHandle)
{
	if (!CheckInit()) return false;
	UGCQueryHandle_t handle = strtoull(cHandle, NULL, 0);
	return SteamUGC()->ReleaseQueryUGCRequest(handle);
}
DEFINE_PRIME1v(SteamWrap_ReleaseQueryUGCRequest);

value SteamWrap_GetQueryUGCKeyValueTag(value cHandle, value iIndex, value iKeyValueTagIndex, value keySize, value valueSize)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(cHandle)) return alloc_string("");
	if (!val_is_int(iIndex)) return alloc_string("");
	if (!val_is_int(iKeyValueTagIndex)) return alloc_string("");
	if (!val_is_int(keySize)) return alloc_string("");
	if (!val_is_int(valueSize)) return alloc_string("");
	
	UGCQueryHandle_t handle = strtoull(val_string(cHandle), NULL, 0);
	uint32 index = val_int(iIndex);
	uint32 keyValueTagIndex = val_int(iKeyValueTagIndex);
	uint32 cchKeySize = val_int(keySize);
	uint32 cchValueSize = val_int(valueSize);
	
	char *pchKey = new char[cchKeySize];
	char *pchValue = new char[cchValueSize];
	
	SteamUGC()->GetQueryUGCKeyValueTag(handle, index, keyValueTagIndex, pchKey, cchKeySize, pchValue, cchValueSize);
	
	std::ostringstream data;
	data << pchKey << "=" << pchValue;
	
	delete pchKey;
	delete pchValue;
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetQueryUGCKeyValueTag, 5);

value SteamWrap_GetQueryUGCMetadata(value sHandle, value iIndex, value iMetaDataSize)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(sHandle)) return alloc_string("");
	if (!val_is_int(iIndex)) return alloc_string("");
	if (!val_is_int(iMetaDataSize)) return alloc_string("");
	
	UGCQueryHandle_t handle = strtoull(val_string(sHandle), NULL, 0);
	
	
	uint32 cchMetadatasize = val_int(iMetaDataSize);
	char * pchMetadata = new char[cchMetadatasize];
	
	uint32 index = val_int(iIndex);
	
	SteamUGC()->GetQueryUGCMetadata(handle, index, pchMetadata, cchMetadatasize);
	
	std::ostringstream data;
	data << pchMetadata;
	
	delete pchMetadata;
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetQueryUGCMetadata, 3);

value SteamWrap_GetQueryUGCResult(value sHandle, value iIndex)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(sHandle)) return alloc_string("");
	if (!val_is_int(iIndex)) return alloc_string("");
	
	UGCQueryHandle_t handle = strtoull(val_string(sHandle), NULL, 0);
	
	uint32 index = val_int(iIndex);
	
	SteamUGCDetails_t * d = new SteamUGCDetails_t;
	
	SteamUGC()->GetQueryUGCResult(handle, index, d);
	
	std::ostringstream data;
	
	data << "publishedFileID:" << d->m_nPublishedFileId << ",";
	data << "result:" << d->m_eResult << ",";
	data << "fileType:" << d->m_eFileType<< ",";
	data << "creatorAppID:" << d->m_nCreatorAppID<< ",";
	data << "consumerAppID:" << d->m_nConsumerAppID<< ",";
	data << "title:" << d->m_rgchTitle<< ",";
	data << "description:" << d->m_rgchDescription<< ",";
	data << "steamIDOwner:" << d->m_ulSteamIDOwner<< ",";
	data << "timeCreated:" << d->m_rtimeCreated<< ",";
	data << "timeUpdated:" << d->m_rtimeUpdated<< ",";
	data << "timeAddedToUserList:" << d->m_rtimeAddedToUserList<< ",";
	data << "visibility:" << d->m_eVisibility<< ",";
	data << "banned:" << d->m_bBanned<< ",";
	data << "acceptedForUse:" << d->m_bAcceptedForUse<< ",";
	data << "tagsTruncated:" << d->m_bTagsTruncated<< ",";
	data << "tags:" << d->m_rgchTags<< ",";
	data << "file:" << d->m_hFile<< ",";
	data << "previewFile:" << d->m_hPreviewFile<< ",";
	data << "fileName:" << d->m_pchFileName<< ",";
	data << "fileSize:" << d->m_nFileSize<< ",";
	data << "previewFileSize:" << d->m_nPreviewFileSize<< ",";
	data << "rgchURL:" << d->m_rgchURL<< ",";
	data << "votesup:" << d->m_unVotesUp<< ",";
	data << "votesDown:" << d->m_unVotesDown<< ",";
	data << "score:" << d->m_flScore<< ",";
	data << "numChildren:" << d->m_unNumChildren;
	
	delete d;
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetQueryUGCResult, 2);

#pragma endregion

#pragma region Old Workshop
//OLD STEAM WORKSHOP---------------------------------------------------------------------------------------------

value SteamWrap_GetUGCDownloadProgress(value contentHandle)
{
	if (!CheckInit()) return alloc_string("");
	if (!val_is_string(contentHandle)) return alloc_string("");
	
	uint64 u64Handle = strtoll(val_string(contentHandle), NULL, 10);
	
	int32 pnBytesDownloaded = 0;
	int32 pnBytesExpected = 0;
	
	SteamRemoteStorage()->GetUGCDownloadProgress(u64Handle, &pnBytesDownloaded, &pnBytesExpected);
	
	std::ostringstream data;
	data << pnBytesDownloaded << "," << pnBytesExpected;
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetUGCDownloadProgress,1);

void SteamWrap_EnumerateUserSharedWorkshopFiles(const char * steamIDStr, int startIndex, const char * requiredTagsStr, const char * excludedTagsStr)
{
	if(!CheckInit()) return;
	
	//Reconstruct the steamID from the string representation
	uint64 u64SteamID = strtoll(steamIDStr, NULL, 10);
	CSteamID steamID = u64SteamID;
	
	uint32 unStartIndex = (uint32) startIndex;
	
	//Construct the string arrays from the comma-delimited strings
	SteamParamStringArray_t * requiredTags = getSteamParamStringArray(requiredTagsStr);
	SteamParamStringArray_t * excludedTags = getSteamParamStringArray(excludedTagsStr);
	
	//make the actual call
	s_callbackHandler->EnumerateUserSharedWorkshopFiles(steamID, startIndex, requiredTags, excludedTags);
	
	//clean up requiredTags & excludedTags:
	deleteSteamParamStringArray(requiredTags);
	deleteSteamParamStringArray(excludedTags);
}
DEFINE_PRIME4v(SteamWrap_EnumerateUserSharedWorkshopFiles);

void SteamWrap_EnumerateUserPublishedFiles(int startIndex)
{
	if(!CheckInit()) return;
	uint32 unStartIndex = (uint32) startIndex;
	s_callbackHandler->EnumerateUserPublishedFiles(unStartIndex);
}
DEFINE_PRIME1v(SteamWrap_EnumerateUserPublishedFiles);

void SteamWrap_EnumerateUserSubscribedFiles(int startIndex)
{
	if(!CheckInit());
	uint32 unStartIndex = (uint32) startIndex;
	s_callbackHandler->EnumerateUserSubscribedFiles(unStartIndex);
}
DEFINE_PRIME1v(SteamWrap_EnumerateUserSubscribedFiles);

void SteamWrap_GetPublishedFileDetails(const char * fileId, int maxSecondsOld)
{
	if(!CheckInit());
	
	uint64 u64FileID = strtoull(fileId, NULL, 0);
	uint32 u32MaxSecondsOld = maxSecondsOld;
	
	s_callbackHandler->GetPublishedFileDetails(u64FileID, u32MaxSecondsOld);
}
DEFINE_PRIME2v(SteamWrap_GetPublishedFileDetails);

void SteamWrap_UGCDownload(const char * handle, int priority)
{
	if(!CheckInit());
	
	uint64 u64Handle = strtoull(handle, NULL, 0);
	uint32 u32Priority = (uint32) priority;
	
	s_callbackHandler->UGCDownload(u64Handle, u32Priority);
}
DEFINE_PRIME2v(SteamWrap_UGCDownload);

value SteamWrap_UGCRead(value handle, value bytesToRead, value offset, value readAction)
{
	if(!CheckInit()             ||
	   !val_is_string(handle)   ||
	   !val_is_int(bytesToRead) ||
	   !val_is_int(offset)      ||
	   !val_is_int(readAction)) return alloc_string("");
	
	uint64 u64Handle = strtoull(val_string(handle), NULL, 0);
	int32 cubDataToRead = (int32) val_int(bytesToRead);
	uint32 cOffset = (uint32) val_int(offset);
	EUGCReadAction eAction = (EUGCReadAction) val_int(readAction);
	
	if(u64Handle == 0 || cubDataToRead == 0) return alloc_string("");
	
	unsigned char *data = (unsigned char *)malloc(cubDataToRead);
	int result = SteamRemoteStorage()->UGCRead(u64Handle, data, cubDataToRead, cOffset, eAction);
	
	value returnValue = bytes_to_hx(data,result);
	
	free(data);
	
	return returnValue;
}
DEFINE_PRIM(SteamWrap_UGCRead,4);

#pragma endregion

#pragma region Steam Cloud
//-----------------------------------------------------------------------------------------------------------

//STEAM CLOUD------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetFileCount(int dummy)
{
	int fileCount = SteamRemoteStorage()->GetFileCount();
	return fileCount;
}
DEFINE_PRIME1(SteamWrap_GetFileCount);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetFileSize(const char * fileName)
{
	int fileSize = SteamRemoteStorage()->GetFileSize(fileName);
	return fileSize;
}
DEFINE_PRIME1(SteamWrap_GetFileSize);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_FileExists(const char * fileName)
{
	bool exists = SteamRemoteStorage()->FileExists(fileName);
	return exists;
}
DEFINE_PRIME1(SteamWrap_FileExists);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_FileRead(value fileName)
{
	if (!val_is_string(fileName) || !CheckInit())
		return alloc_null();
	
	const char * fName = val_string(fileName);
	
	bool exists = SteamRemoteStorage()->FileExists(fName);
	if(!exists) return alloc_int(0);
	
	int length = SteamRemoteStorage()->GetFileSize(fName);
	
	char *bytesData = (char *)malloc(length);
	int32 result = SteamRemoteStorage()->FileRead(fName, bytesData, length);
	
	value returnValue = alloc_string_len(bytesData, length);
	free(bytesData);
	return returnValue;
}
DEFINE_PRIM(SteamWrap_FileRead, 1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_FileWrite(value fileName, value haxeBytes)
{
	if (!val_is_string(fileName) || !CheckInit())
		return alloc_bool(false);
	
	CffiBytes bytes = getByteData(haxeBytes);
	if(bytes.data == 0)
		return alloc_bool(false);
	
	bool result = SteamRemoteStorage()->FileWrite(val_string(fileName), bytes.data, bytes.length);
	
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_FileWrite, 2);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_FileDelete(const char * fileName)
{
	bool result = SteamRemoteStorage()->FileDelete(fileName);
	return result;
}
DEFINE_PRIME1(SteamWrap_FileDelete);

//-----------------------------------------------------------------------------------------------------------
void SteamWrap_FileShare(const char * fileName)
{
	s_callbackHandler->FileShare(fileName);
}
DEFINE_PRIME1v(SteamWrap_FileShare);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_IsCloudEnabledForApp(int dummy)
{
	int result = SteamRemoteStorage()->IsCloudEnabledForApp();
	return result;
}
DEFINE_PRIME1(SteamWrap_IsCloudEnabledForApp);

//-----------------------------------------------------------------------------------------------------------
void SteamWrap_SetCloudEnabledForApp(int enabled)
{
	SteamRemoteStorage()->SetCloudEnabledForApp(enabled);
}
DEFINE_PRIME1v(SteamWrap_SetCloudEnabledForApp);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetQuota()
{
	uint64 total = 0;
	uint64 available = 0;
	
	//convert uint64 handle to string
	std::ostringstream data;
	data << total << "," << available;
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetQuota,0);

#pragma endregion

#pragma region Steam Networking
#define SteamNetworking SteamNetworking()
value SteamWrap_SendPacket(value handle, value haxeBytes, value size, value type) {
	if (!CheckInit() || !val_is_string(handle) || !val_is_int(size) || !val_is_int(type)) return alloc_bool(false);
	uint64 u64Handle = strtoull(val_string(handle), NULL, 0);
	CffiBytes bytes = getByteData(haxeBytes);
	EP2PSend etype = k_EP2PSendUnreliable;
	switch ((int32)val_int(type)) {
		case 1: etype = k_EP2PSendUnreliableNoDelay; break;
		case 2: etype = k_EP2PSendReliable; break;
		case 3: etype = k_EP2PSendReliableWithBuffering; break;
	}
	if (bytes.data == 0) return alloc_bool(false);
	return alloc_bool(SteamNetworking->SendP2PPacket(u64Handle, bytes.data, (int32)val_int(size), etype));
}
DEFINE_PRIM(SteamWrap_SendPacket, 4);

uint32 SteamWrap_PacketSize = 0;
value SteamWrap_GetPacketSize() {
	if (!CheckInit()) return alloc_int(0);
	return alloc_int(SteamWrap_PacketSize);
}
DEFINE_PRIM(SteamWrap_GetPacketSize, 0);

void* SteamWrap_PacketData = nullptr;
value SteamWrap_GetPacketData() {
	if (!CheckInit() || SteamWrap_PacketData == nullptr) return alloc_bool(false);
	return bytes_to_hx((unsigned char*)SteamWrap_PacketData, SteamWrap_PacketSize);
}
DEFINE_PRIM(SteamWrap_GetPacketData, 0);

CSteamID SteamWrap_PacketSender;
value SteamWrap_GetPacketSender() {
	if (!CheckInit()) return alloc_string("");
	return id_to_hx(SteamWrap_PacketSender);
}
DEFINE_PRIM(SteamWrap_GetPacketSender, 0);

value SteamWrap_ReceivePacket() {
	uint32 SteamWrap_PacketSizePre = 0;
	if (SteamNetworking && SteamNetworking->IsP2PPacketAvailable(&SteamWrap_PacketSizePre)) {
		// dealloc the current buffer if it's still around:
		if (SteamWrap_PacketData != nullptr) {
			free(SteamWrap_PacketData);
			SteamWrap_PacketData = nullptr;
		}
		//
		SteamWrap_PacketData = malloc(SteamWrap_PacketSizePre);
		if (SteamNetworking->ReadP2PPacket(
			SteamWrap_PacketData, SteamWrap_PacketSizePre,
			&SteamWrap_PacketSize, &SteamWrap_PacketSender)) {
			return alloc_bool(true);
		}
	}
	return alloc_bool(false);
}
DEFINE_PRIM(SteamWrap_ReceivePacket, 0);
/*int SteamWrap_SendP2PPacket(const char * handle, value haxeBytes, int size, int type) {
	printf("Bock!\n"); fflush(stdout);
	if (!CheckInit()) return (4);
	return (5);
	uint64 u64Handle = strtoull(handle, NULL, 0);
	CffiBytes bytes = getByteData(haxeBytes);
	EP2PSend etype = k_EP2PSendUnreliable;
	switch ((int32)type) {
		case 1: etype = k_EP2PSendUnreliableNoDelay; break;
		case 2: etype = k_EP2PSendReliable; break;
		case 3: etype = k_EP2PSendReliableWithBuffering; break;
	}
	if (bytes.data == 0) return alloc_bool(false);
	return true || SteamNetworking->SendP2PPacket(u64Handle, bytes.data, size, etype);
}
DEFINE_PRIME4(SteamWrap_SendP2PPacket);*/
#pragma endregion

#pragma region Steam Matchmaking

#pragma region Current lobby
CSteamID SteamWrap_LobbyID;

value SteamWrap_LeaveLobby() {
	swp_start(val_false);
	swp_req(SteamWrap_LobbyID.IsValid());
	SteamMatchmaking()->LeaveLobby(SteamWrap_LobbyID);
	SteamWrap_LobbyID.Clear();
	return val_true;
}
DEFINE_PRIM(SteamWrap_LeaveLobby, 0);

value SteamWrap_LobbyID_() {
	swp_start(val_noid);
	return id_to_hx(SteamWrap_LobbyID);
}
DEFINE_PRIM(SteamWrap_LobbyID_, 0);

value SteamWrap_LobbyOwnerID() {
	swp_start(val_noid); swp_req(SteamWrap_LobbyID.IsValid());
	return id_to_hx(SteamMatchmaking()->GetLobbyOwner(SteamWrap_LobbyID));
}
DEFINE_PRIM(SteamWrap_LobbyOwnerID, 0);

value SteamWrap_LobbyMemberCount() {
	swp_start(alloc_int(0)); swp_req(SteamWrap_LobbyID.IsValid());
	return alloc_int(SteamMatchmaking()->GetNumLobbyMembers(SteamWrap_LobbyID));
}
DEFINE_PRIM(SteamWrap_LobbyMemberCount, 0);

value SteamWrap_LobbyMemberID(value index) {
	swp_start(val_noid); swp_int(i, index);
	swp_req(SteamWrap_LobbyID.IsValid() && i >= 0 && i < SteamMatchmaking()->GetNumLobbyMembers(SteamWrap_LobbyID));
	return id_to_hx(SteamMatchmaking()->GetLobbyMemberByIndex(SteamWrap_LobbyID, i));
}
DEFINE_PRIM(SteamWrap_LobbyMemberID, 1);

value SteamWrap_LobbySetData(value field, value data) {
	if (CheckInit() && val_is_string(field) && val_is_string(data) && SteamWrap_LobbyID.IsValid()) {
		return alloc_bool(SteamMatchmaking()->SetLobbyData(SteamWrap_LobbyID, val_string(field), val_string(data)));
	} else return alloc_bool(false);
}
DEFINE_PRIM(SteamWrap_LobbySetData, 2);

value SteamWrap_ActivateInviteOverlay() {
	if (CheckInit() && SteamFriends() && SteamWrap_LobbyID.IsValid()) {
		SteamFriends()->ActivateGameOverlayInviteDialog(SteamWrap_LobbyID);
		return alloc_bool(true);
	} else return alloc_bool(false);
}
DEFINE_PRIM(SteamWrap_ActivateInviteOverlay, 0);
#pragma endregion

#pragma region Lobby list
std::vector<CSteamID> SteamWrap_LobbyList;

value SteamWrap_LobbyListLength() {
	return alloc_int(SteamWrap_LobbyList.size());
}
DEFINE_PRIM(SteamWrap_LobbyListLength, 0);

value SteamWrap_LobbyListGetID(value index) {
	swp_start(val_noid); swp_int(i, index);
	swp_req(i >= 0 && i < SteamWrap_LobbyList.size());
	return id_to_hx(SteamWrap_LobbyList[i]);
}
DEFINE_PRIM(SteamWrap_LobbyListGetID, 1);

value SteamWrap_LobbyListGetData(value index, value field) {
	swp_start(alloc_string("")); swp_int(i, index); swp_string(s, field);
	swp_req(i >= 0 && i < SteamWrap_LobbyList.size());
	return alloc_string(SteamMatchmaking()->GetLobbyData(SteamWrap_LobbyList[i], val_string(field)));
}
DEFINE_PRIM(SteamWrap_LobbyListGetData, 2);

bool SteamWrap_LobbyListLoading = false;
value SteamWrap_LobbyListIsLoading() {
	return alloc_bool(SteamWrap_LobbyListLoading);
}
DEFINE_PRIM(SteamWrap_LobbyListIsLoading, 0);

void CallbackHandler::LobbyListRequest() {
	SteamWrap_LobbyListLoading = true;
	SteamAPICall_t hSteamAPICall = SteamMatchmaking()->RequestLobbyList();
	m_callResultLobbyListReceived.Set(hSteamAPICall, this, &CallbackHandler::OnLobbyListReceived);
}

void CallbackHandler::OnLobbyListReceived(LobbyMatchList_t* pResult, bool bIOFailure) {
	auto found = pResult->m_nLobbiesMatching;
	SteamWrap_LobbyList.resize(found);
	for (uint32 i = 0; i < found; i++) {
		SteamWrap_LobbyList[i] = SteamMatchmaking()->GetLobbyByIndex(i);
	}
	SteamWrap_LobbyListLoading = false;
	SendEvent(Event(kEventTypeOnLobbyListReceived, !bIOFailure, alloc_int(found)));
}

value SteamWrap_RequestLobbyList() {
	swp_start(val_false); swp_req(SteamMatchmaking());
	s_callbackHandler->LobbyListRequest();
	return val_true;
}
DEFINE_PRIM(SteamWrap_RequestLobbyList, 0);

#pragma endregion

#pragma region Lobby list filters
ELobbyComparison SteamWrap_LobbyCmp(int32 filter) {
	switch (filter) {
		case -2: return k_ELobbyComparisonEqualToOrLessThan;
		case -1: return k_ELobbyComparisonLessThan;
		case  1: return k_ELobbyComparisonGreaterThan;
		case  2: return k_ELobbyComparisonEqualToOrGreaterThan;
		case  3: return k_ELobbyComparisonNotEqual;
		default: return k_ELobbyComparisonEqual;
	}
}

value SteamWrap_LobbyListAddStringFilter(value field, value data, value cmp) {
	swp_start(val_false); swp_string(s, field); swp_string(v, data); swp_int(c, cmp);
	swp_req(SteamMatchmaking());
	SteamMatchmaking()->AddRequestLobbyListStringFilter(s, v, SteamWrap_LobbyCmp(c));
	return val_true;
}
DEFINE_PRIM(SteamWrap_LobbyListAddStringFilter, 3);

value SteamWrap_LobbyListAddNumericalFilter(value field, value data, value cmp) {
	swp_start(val_false); swp_string(s, field); swp_int(v, data); swp_int(c, cmp);
	swp_req(SteamMatchmaking());
	SteamMatchmaking()->AddRequestLobbyListNumericalFilter(s, v, SteamWrap_LobbyCmp(c));
	return val_true;
}
DEFINE_PRIM(SteamWrap_LobbyListAddNumericalFilter, 3);

value SteamWrap_LobbyListAddNearFilter(value field, value data) {
	swp_start(val_false); swp_string(s, field); swp_int(v, data);
	swp_req(SteamMatchmaking());
	SteamMatchmaking()->AddRequestLobbyListNearValueFilter(s, v);
	return val_true;
}
DEFINE_PRIM(SteamWrap_LobbyListAddNearFilter, 2);

value SteamWrap_LobbyListAddDistanceFilter(value mode) {
	swp_start(val_false); swp_int(m, mode);
	swp_req(SteamMatchmaking());
	ELobbyDistanceFilter d = k_ELobbyDistanceFilterDefault;
	switch (m) {
		case 0: d = k_ELobbyDistanceFilterClose; break;
		case 1: d = k_ELobbyDistanceFilterDefault; break;
		case 2: d = k_ELobbyDistanceFilterFar; break;
		case 3: d = k_ELobbyDistanceFilterWorldwide; break;
	}
	SteamMatchmaking()->AddRequestLobbyListDistanceFilter(d);
	return val_true;
}
DEFINE_PRIM(SteamWrap_LobbyListAddDistanceFilter, 1);
#pragma endregion

#pragma region Joining lobbies

void CallbackHandler::LobbyJoin(CSteamID id) {
	SteamAPICall_t hSteamAPICall = SteamMatchmaking()->JoinLobby(id);
	m_callResultLobbyJoined.Set(hSteamAPICall, this, &CallbackHandler::OnLobbyJoined);
}

void CallbackHandler::OnLobbyJoined(LobbyEnter_t* pResult, bool bIOFailure) {
	SteamWrap_LobbyID.SetFromUint64(pResult->m_ulSteamIDLobby);
	SendEvent(Event(kEventTypeOnLobbyJoined, !bIOFailure, id_to_hx(pResult->m_ulSteamIDLobby)));
}

value SteamWrap_JoinLobby(value id) {
	swp_start(val_false); swp_string(q, id);
	swp_req(SteamMatchmaking());
	s_callbackHandler->LobbyJoin(hx_to_id(id));
	return val_true;
}
DEFINE_PRIME1(SteamWrap_JoinLobby);

void CallbackHandler::OnLobbyJoinRequested(GameLobbyJoinRequested_t* pResult) {
	value obj = alloc_empty_object();
	alloc_field(obj, val_id("lobbyID"), id_to_hx(pResult->m_steamIDLobby));
	alloc_field(obj, val_id("friendID"), id_to_hx(pResult->m_steamIDFriend));
	SendEvent(Event(kEventTypeOnLobbyJoinRequested, true, obj));
}

#pragma endregion

#pragma region Making lobbies
ELobbyType SteamWrap_LobbyType(int32 type) {
	switch (type) {
		case 1: return k_ELobbyTypeFriendsOnly;
		case 2: return k_ELobbyTypePublic;
		default: return k_ELobbyTypePrivate;
	}
}

void CallbackHandler::LobbyCreate(int kind, int maxMembers) {
	SteamAPICall_t hSteamAPICall = SteamMatchmaking()->CreateLobby(SteamWrap_LobbyType(kind), maxMembers);
	m_callResultLobbyCreated.Set(hSteamAPICall, this, &CallbackHandler::OnLobbyCreated);
}

void CallbackHandler::OnLobbyCreated(LobbyCreated_t* pResult, bool bIOFailure) {
	SteamWrap_LobbyID.SetFromUint64(pResult->m_ulSteamIDLobby);
	SendEvent(Event(kEventTypeOnLobbyCreated, pResult->m_eResult == k_EResultOK));
}

bool SteamWrap_CreateLobby(int kind, int maxMembers) {
	if (!CheckInit() || !SteamMatchmaking()) return false;
	s_callbackHandler->LobbyCreate(kind, maxMembers);
	return true;
}
DEFINE_PRIME2(SteamWrap_CreateLobby);

bool SteamWrap_SetLobbyType(int type) {
	if (CheckInit() && SteamWrap_LobbyID.IsValid()) {
		return SteamMatchmaking()->SetLobbyType(SteamWrap_LobbyID, SteamWrap_LobbyType(type));
	} else return false;
}
DEFINE_PRIME1(SteamWrap_SetLobbyType);

#pragma endregion

#pragma endregion

#pragma region Steam Controller
//-----------------------------------------------------------------------------------------------------------

//STEAM CONTROLLER-------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_InitControllers()
{
	if (!SteamInput()) return alloc_bool(false);

	bool result = SteamInput()->Init(true);
	
	if (result)
	{
		mapControllers.init();
		
		analogActionData.eMode = k_EInputSourceMode_None;
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
	bool result = SteamInput()->Shutdown();
	if (result)
	{
		mapControllers.init();
	}
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_ShutdownControllers,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_ShowBindingPanel(value controllerHandle)
{
	if(!val_is_int(controllerHandle)) 
		return alloc_bool(false);
	
	int i_handle = val_int(controllerHandle);
	
	ControllerHandle_t c_handle = i_handle != -1 ? mapControllers.get(i_handle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	
	bool result = SteamInput()->ShowBindingPanel(c_handle);
	
	return alloc_bool(result);
}
DEFINE_PRIM(SteamWrap_ShowBindingPanel, 1);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_ShowGamepadTextInput(int inputMode, int lineMode, const char * description, int charMax, const char * existingText)
{
	uint32 u_charMax = charMax;
	
	EGamepadTextInputMode eInputMode = static_cast<EGamepadTextInputMode>(inputMode);
	EGamepadTextInputLineMode eLineInputMode = static_cast<EGamepadTextInputLineMode>(lineMode);
	
	int result = SteamUtils()->ShowGamepadTextInput(eInputMode, eLineInputMode, description, u_charMax, existingText);
	return result;

}
DEFINE_PRIME5(SteamWrap_ShowGamepadTextInput);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetEnteredGamepadTextInput()
{
	uint32 length = SteamUtils()->GetEnteredGamepadTextLength();
	char *pchText = (char *)malloc(length);
	bool result = SteamUtils()->GetEnteredGamepadTextInput(pchText, length);
	if(result)
	{
		value returnValue = alloc_string(pchText);
		free(pchText);
		return returnValue;
	}
	free(pchText);
	return alloc_string("");

}
DEFINE_PRIM(SteamWrap_GetEnteredGamepadTextInput, 0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetConnectedControllers()
{
	SteamInput()->RunFrame();
	
	ControllerHandle_t handles[STEAM_INPUT_MAX_COUNT];
	int result = SteamInput()->GetConnectedControllers(handles);
	
	std::ostringstream returnData;
	
	//store the handles locally and pass back a string representing an int array of unique index lookup values
	
	for(int i = 0; i < result; i++)
	{
		int index = mapControllers.find(handles[i]);
		
		if(index < 0)
		{
			index = mapControllers.add(handles[i]);
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

	ControllerActionSetHandle_t handle = SteamInput()->GetActionSetHandle(actionSetName);
	return handle;
}
DEFINE_PRIME1(SteamWrap_GetActionSetHandle);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetDigitalActionHandle(const char * actionName)
{

	return SteamInput()->GetDigitalActionHandle(actionName);
}
DEFINE_PRIME1(SteamWrap_GetDigitalActionHandle);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetAnalogActionHandle(const char * actionName)
{

	ControllerAnalogActionHandle_t handle = SteamInput()->GetAnalogActionHandle(actionName);
	return handle;
}
DEFINE_PRIME1(SteamWrap_GetAnalogActionHandle);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetDigitalActionData(int controllerHandle, int actionHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	ControllerDigitalActionHandle_t a_handle = actionHandle;
	
	ControllerDigitalActionData_t data = SteamInput()->GetDigitalActionData(c_handle, a_handle);
	
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
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	ControllerAnalogActionHandle_t a_handle = actionHandle;
	
	analogActionData = SteamInput()->GetAnalogActionData(c_handle, a_handle);
	
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
	
	EInputActionOrigin origins[STEAM_INPUT_MAX_ORIGINS];
	
	//Initialize the whole thing to None to avoid garbage
	for(int i = 0; i < STEAM_INPUT_MAX_ORIGINS; i++) {
		origins[i] = k_EInputActionOrigin_None;
	}
	
	int result = SteamInput()->GetDigitalActionOrigins(c_handle, s_handle, a_handle, origins);
	
	std::ostringstream data;
	
	data << result << ",";
	
	for(int i = 0; i < STEAM_INPUT_MAX_ORIGINS; i++) {
		data << origins[i];
		if(i != STEAM_INPUT_MAX_ORIGINS-1){
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
	
	EInputActionOrigin origins[STEAM_INPUT_MAX_ORIGINS];
	
	//Initialize the whole thing to None to avoid garbage
	for(int i = 0; i < STEAM_INPUT_MAX_ORIGINS; i++) {
		origins[i] = k_EInputActionOrigin_None;
	}
	
	int result = SteamInput()->GetAnalogActionOrigins(c_handle, s_handle, a_handle, origins);
	
	std::ostringstream data;
	
	data << result << ",";
	
	for(int i = 0; i < STEAM_INPUT_MAX_ORIGINS; i++) {
		data << origins[i];
		if(i != STEAM_INPUT_MAX_ORIGINS-1){
			data << ",";
		}
	}
	
	return alloc_string(data.str().c_str());
}
DEFINE_PRIM(SteamWrap_GetAnalogActionOrigins,3);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetGlyphForActionOrigin(value origin)
{
	if (!val_is_int(origin) || !CheckInit())
	{
		return alloc_string("none");
	}
	
	int iOrigin = val_int(origin);
	if (iOrigin >= k_EInputActionOrigin_Count)
	{
		return alloc_string("none");
	}
	
	EInputActionOrigin eOrigin = static_cast<EInputActionOrigin>(iOrigin);
	
	const char * result = SteamInput()->GetGlyphPNGForActionOrigin(eOrigin, k_ESteamInputGlyphSize_Medium, 0);
	return alloc_string(result);
}
DEFINE_PRIM(SteamWrap_GetGlyphForActionOrigin,1);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetStringForActionOrigin(value origin)
{
	if (!val_is_int(origin) || !CheckInit())
	{
		return alloc_string("unknown");
	}
	
	int iOrigin = val_int(origin);
	if (iOrigin >= k_EInputActionOrigin_Count)
	{
		return alloc_string("unknown");
	}
	
	EInputActionOrigin eOrigin = static_cast<EInputActionOrigin>(iOrigin);
	
	const char * result = SteamInput()->GetStringForActionOrigin(eOrigin);
	return alloc_string(result);
}
DEFINE_PRIM(SteamWrap_GetStringForActionOrigin,1);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_ActivateActionSet(int controllerHandle, int actionSetHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	ControllerActionSetHandle_t a_handle = actionSetHandle;
	
	SteamInput()->ActivateActionSet(c_handle, a_handle);
	
	return true;
}
DEFINE_PRIME2(SteamWrap_ActivateActionSet);

//-----------------------------------------------------------------------------------------------------------
int SteamWrap_GetCurrentActionSet(int controllerHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	ControllerActionSetHandle_t a_handle = SteamInput()->GetCurrentActionSet(c_handle);
	
	return a_handle;
}
DEFINE_PRIME1(SteamWrap_GetCurrentActionSet);

void SteamWrap_TriggerHapticPulse(int controllerHandle, int targetPad, int durationMicroSec)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	ESteamControllerPad eTargetPad;
	switch(targetPad)
	{
		case 0:  eTargetPad = k_ESteamControllerPad_Left;
		case 1:  eTargetPad = k_ESteamControllerPad_Right;
		default: eTargetPad = k_ESteamControllerPad_Left;
	}
	unsigned short usDurationMicroSec = durationMicroSec;
	
	SteamInput()->Legacy_TriggerHapticPulse(c_handle, eTargetPad, usDurationMicroSec);
}
DEFINE_PRIME3v(SteamWrap_TriggerHapticPulse);

void SteamWrap_TriggerRepeatedHapticPulse(int controllerHandle, int targetPad, int durationMicroSec, int offMicroSec, int repeat, int flags)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
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
	
	SteamInput()->Legacy_TriggerRepeatedHapticPulse(c_handle, eTargetPad, usDurationMicroSec, usOffMicroSec, unRepeat, nFlags);
}
DEFINE_PRIME6v(SteamWrap_TriggerRepeatedHapticPulse);

void SteamWrap_TriggerVibration(int controllerHandle, int leftSpeed, int rightSpeed)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	SteamInput()->TriggerVibration(c_handle, (unsigned short)leftSpeed, (unsigned short)rightSpeed);
}
DEFINE_PRIME3v(SteamWrap_TriggerVibration);

void SteamWrap_SetLEDColor(int controllerHandle, int r, int g, int b, int flags)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	SteamInput()->SetLEDColor(c_handle, (uint8)r, (uint8)g, (uint8)b, (unsigned int) flags);
}
DEFINE_PRIME5v(SteamWrap_SetLEDColor);

//-----------------------------------------------------------------------------------------------------------
//stashes the requested motion data in local state
//you need to immediately call _rotQuatX/Y/Z/W, _posAccelX/Y/Z, _rotVelX/Y/Z to get the rest

void SteamWrap_GetMotionData(int controllerHandle)
{
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	motionData = SteamInput()->GetMotionData(c_handle);
}
DEFINE_PRIME1v(SteamWrap_GetMotionData);

int SteamWrap_GetMotionData_rotQuatX(int dummy)
{
	return motionData.rotQuatX;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotQuatX);

int SteamWrap_GetMotionData_rotQuatY(int dummy)
{
	return motionData.rotQuatY;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotQuatY);

int SteamWrap_GetMotionData_rotQuatZ(int dummy)
{
	return motionData.rotQuatZ;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotQuatZ);

int SteamWrap_GetMotionData_rotQuatW(int dummy)
{
	return motionData.rotQuatW;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotQuatW);

int SteamWrap_GetMotionData_posAccelX(int dummy)
{
	return motionData.posAccelX;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_posAccelX);

int SteamWrap_GetMotionData_posAccelY(int dummy)
{
	return motionData.posAccelY;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_posAccelY);

int SteamWrap_GetMotionData_posAccelZ(int dummy)
{
	return motionData.posAccelZ;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_posAccelZ);

int SteamWrap_GetMotionData_rotVelX(int dummy)
{
	return motionData.rotVelX;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotVelX);

int SteamWrap_GetMotionData_rotVelY(int dummy)
{
	return motionData.rotVelY;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotVelY);

int SteamWrap_GetMotionData_rotVelZ(int dummy)
{
	return motionData.rotVelZ;
}
DEFINE_PRIME1(SteamWrap_GetMotionData_rotVelZ);

int SteamWrap_ShowDigitalActionOrigins(int controllerHandle, int digitalActionHandle, float scale, float xPosition, float yPosition)
{
	//Deprecated for now until I refactor the API to fix according to Valve's changes	
	/*
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	return SteamInput()->ShowDigitalActionOrigins(c_handle, digitalActionHandle, scale, xPosition, yPosition);
	*/
	return 0;
}
DEFINE_PRIME5(SteamWrap_ShowDigitalActionOrigins);

int SteamWrap_ShowAnalogActionOrigins(int controllerHandle, int analogActionHandle, float scale, float xPosition, float yPosition)
{
	//Deprecated for now until I refactor the API to fix according to Valve's changes
	/*
	ControllerHandle_t c_handle = controllerHandle != -1 ? mapControllers.get(controllerHandle) : STEAM_INPUT_HANDLE_ALL_CONTROLLERS;
	return SteamInput()->ShowAnalogActionOrigins(c_handle, analogActionHandle, scale, xPosition, yPosition);
	*/
	return 0;
}
DEFINE_PRIME5(SteamWrap_ShowAnalogActionOrigins);



//---getters for constants----------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxCount()
{
	return alloc_int(STEAM_INPUT_MAX_COUNT);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxCount,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxAnalogActions()
{
	return alloc_int(STEAM_INPUT_MAX_ANALOG_ACTIONS);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxAnalogActions,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxDigitalActions()
{
	return alloc_int(STEAM_INPUT_MAX_DIGITAL_ACTIONS);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxDigitalActions,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxOrigins()
{
	return alloc_int(STEAM_INPUT_MAX_ORIGINS);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxOrigins,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMinAnalogActionData()
{
	return alloc_float(STEAM_INPUT_MIN_ANALOG_ACTION_DATA);
}
DEFINE_PRIM(SteamWrap_GetControllerMinAnalogActionData,0);

//-----------------------------------------------------------------------------------------------------------
value SteamWrap_GetControllerMaxAnalogActionData()
{
	return alloc_float(STEAM_INPUT_MAX_ANALOG_ACTION_DATA);
}
DEFINE_PRIM(SteamWrap_GetControllerMaxAnalogActionData,0);

//-----------------------------------------------------------------------------------------------------------

#pragma endregion

void mylib_main()
{
    // Initialization code goes here
}
DEFINE_ENTRY_POINT(mylib_main);


} // extern "C"

