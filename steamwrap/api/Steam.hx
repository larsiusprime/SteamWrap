package steamwrap.api;

import cpp.Lib;
import haxe.Int64;
import steamwrap.api.Steam.EnumerateWorkshopFilesResult;
import steamwrap.api.Steam.DownloadUGCResult;
import steamwrap.api.Steam.GetItemInstallInfoResult;
import steamwrap.api.Steam.GetPublishedFileDetailsResult;
import steamwrap.api.Steam.SteamUGCDetails;
import steamwrap.api.Steam.SteamUGCQueryCompleted;
import steamwrap.helpers.Loader;
import steamwrap.helpers.Util;

private enum LeaderboardOp
{
	FIND(id:String);
	UPLOAD(score:LeaderboardScore);
	DOWNLOAD(id:String);
}

@:enum
abstract SteamNotificationPosition(Int) to Int 
{
	var TopLeft = 0;
	var TopRight = 1;
	var BottomRight = 2;
	var BottomLeft = 3;
}

typedef ControllerHandle = Int64;
typedef ControllerActionSetHandle = Int;
typedef ControllerDigitalActionHandle = Int;
typedef ControllerAnalogActionHandle = Int;

class Steam
{
	/*************PUBLIC***************/
	
	/**
	 * Whether the Steam API is detected & initialized or not. If false, all calls will fail
	 */
	public static var active(default, null):Bool = false;
	
	/**
	 * If true, Steam was detected but did not initialize properly, and you should restart under Steam
	 */
	public static var wantQuit(default, null):Bool = false;
	
	/**
	 * The Steam Controller API
	 */
	public static var controllers(default, null):Controller;
	
	/**
	 * The Steam UGC API
	 */
	public static var ugc(default, null):UGC;
	
	/**
	 * The Steam Cloud API
	 */
	public static var cloud(default, null):Cloud;
	
	/**
	 * The Steam Networking API
	 */
	public static var networking(default, null):Networking;
	
	/**
	 * DEPRECATED: The Steam Workshop API, provided here for legacy support. The UGC API supercedes it and is generally preferred.
	 */
	public static var workshop(default, null):Workshop;
	
	//User-settable callbacks:

	public static var whenGamepadTextInputDismissed:String->Void;
	public static var whenAchievementStored:String->Void;
	public static var whenLeaderboardScoreDownloaded:LeaderboardScore->Void;
	public static var whenLeaderboardScoreUploaded:LeaderboardScore->Void;
	public static var whenTrace:String->Void;
	public static var whenUGCItemIdReceived:String->Void;
	public static var whenUGCItemUpdateComplete:Bool->String->Void;
	
	public static var whenRemoteStorageFileShared:Bool->String->Void;
	public static var whenUserSharedWorkshopFilesEnumerated:Bool->EnumerateUserPublishedFilesResult->Void;
	public static var whenPublishedWorkshopFilesEnumerated:Bool->EnumerateWorkshopFilesResult->Void;
	public static var whenUserSubscribedFilesEnumerated:Bool->EnumerateUserSubscribedFilesResult->Void;
	public static var whenUserPublishedFilesEnumerated:Bool->EnumerateUserPublishedFilesResult->Void;
	public static var whenUGCDownloaded:Bool->DownloadUGCResult->Void;
	public static var whenPublishedFileDetailsGotten:Bool->GetPublishedFileDetailsResult->Void;
	
	public static var whenItemInstalled:String->Void;
	public static var whenItemDownloaded:Bool->String->Void;
	public static var whenQueryUGCRequestSent:SteamUGCQueryCompleted->Void;
	
	/**
	 * @param appId_	Your Steam APP ID (the numbers on the end of your store page URL - store.steampowered.com/app/XYZ)
	 * @param notificationPosition	The position of the Steam Overlay Notification box.
	 */
	public static function init(appId_:Int, notificationPosition:SteamNotificationPosition = SteamNotificationPosition.BottomRight) {
		#if sys //TODO: figure out what targets this will & won't work with and upate this guard
		if (active) return;
		
		appId = appId_;
		leaderboardIds = new Array<String>();
		leaderboardOps = new List<LeaderboardOp>();
		
		try {
			SteamWrap_ClearAchievement = cpp.Lib.load("steamwrap", "SteamWrap_ClearAchievement", 1);
			SteamWrap_DownloadScores = cpp.Lib.load("steamwrap", "SteamWrap_DownloadScores", 3);
			SteamWrap_FindLeaderboard = cpp.Lib.load("steamwrap", "SteamWrap_FindLeaderboard", 1);
			SteamWrap_GetCurrentGameLanguage = cpp.Lib.load("steamwrap", "SteamWrap_GetCurrentGameLanguage", 0);
			SteamWrap_GetGlobalStat = cpp.Lib.load("steamwrap", "SteamWrap_GetGlobalStat", 1);
			SteamWrap_GetStat = cpp.Lib.load("steamwrap", "SteamWrap_GetStat", 1);
			SteamWrap_GetStatFloat = cpp.Lib.load("steamwrap", "SteamWrap_GetStatFloat", 1);
			SteamWrap_GetStatInt = cpp.Lib.load("steamwrap", "SteamWrap_GetStatInt", 1);
			SteamWrap_IndicateAchievementProgress = cpp.Lib.load("steamwrap", "SteamWrap_IndicateAchievementProgress", 3);
			SteamWrap_Init = cpp.Lib.load("steamwrap", "SteamWrap_Init", 2);
			SteamWrap_IsSteamInBigPictureMode = cpp.Lib.load("steamwrap", "SteamWrap_IsSteamInBigPictureMode", 0);
			SteamWrap_IsSteamRunning = cpp.Lib.load("steamwrap", "SteamWrap_IsSteamRunning", 0);
			SteamWrap_IsOverlayEnabled = cpp.Lib.load("steamwrap", "SteamWrap_IsOverlayEnabled", 0);
			SteamWrap_BOverlayNeedsPresent = cpp.Lib.load("steamwrap", "SteamWrap_BOverlayNeedsPresent", 0);
			SteamWrap_RequestStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestStats", 0);
			SteamWrap_RunCallbacks = cpp.Lib.load("steamwrap", "SteamWrap_RunCallbacks", 0);
			SteamWrap_SetAchievement = cpp.Lib.load("steamwrap", "SteamWrap_SetAchievement", 1);
			SteamWrap_GetAchievement = cpp.Lib.load("steamwrap", "SteamWrap_GetAchievement", 1);
			SteamWrap_GetAchievementDisplayAttribute = cpp.Lib.load("steamwrap", "SteamWrap_GetAchievementDisplayAttribute", 2);
			SteamWrap_GetNumAchievements = cpp.Lib.load("steamwrap", "SteamWrap_GetNumAchievements", 0);
			SteamWrap_GetAchievementName = cpp.Lib.load("steamwrap", "SteamWrap_GetAchievementName", 1);
			SteamWrap_GetSteamID = cpp.Lib.load("steamwrap", "SteamWrap_GetSteamID", 0);
			SteamWrap_GetPersonaName = cpp.Lib.load("steamwrap", "SteamWrap_GetPersonaName", 0);
			SteamWrap_SetStat = cpp.Lib.load("steamwrap", "SteamWrap_SetStat", 2);
			SteamWrap_SetStatFloat = cpp.Lib.load("steamwrap", "SteamWrap_SetStatFloat", 2);
			SteamWrap_SetStatInt = cpp.Lib.load("steamwrap", "SteamWrap_SetStatInt", 2);
			SteamWrap_Shutdown = cpp.Lib.load("steamwrap", "SteamWrap_Shutdown", 0);
			SteamWrap_StoreStats = cpp.Lib.load("steamwrap", "SteamWrap_StoreStats", 0);
			SteamWrap_UploadScore = cpp.Lib.load("steamwrap", "SteamWrap_UploadScore", 3);
			SteamWrap_RequestGlobalStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestGlobalStats", 0);
			SteamWrap_RestartAppIfNecessary = cpp.Lib.load("steamwrap", "SteamWrap_RestartAppIfNecessary", 1);
			SteamWrap_OpenOverlay = cpp.Lib.load("steamwrap", "SteamWrap_OpenOverlay", 1);
		}
		catch (e:Dynamic) {
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}
		
		// if we get this far, the dlls loaded ok and we need Steam to init.
		// otherwise, we're trying to run the Steam version without the Steam client
		active = SteamWrap_Init(steamWrap_onEvent, notificationPosition);
		
		if (active) {
			customTrace("Steam active");
			SteamWrap_RequestStats();
			SteamWrap_RequestGlobalStats();
			
			//initialize other API's:
			ugc = new UGC(appId, customTrace);
			controllers = new Controller(customTrace);
			cloud = new Cloud(appId, customTrace);
			workshop = new Workshop(appId, customTrace);
			networking = new Networking(appId, customTrace);
		}
		else {
			customTrace("Steam failed to activate");
			// restart under Steam
			wantQuit = true;
		}
		
		#end
	}
	
	/*************PUBLIC***************/

	/**
	 * Clear an achievement
	 * @param	id	achievement identifier
	 * @return
	 */
	public static function clearAchievement(id:String):Bool {
		return active && report("clearAchievement", [id], SteamWrap_ClearAchievement(id));
	}
	
	public static function downloadLeaderboardScore(id:String):Bool {
		if (!active) return false;
		var startProcessingNow = (leaderboardOps.length == 0);
		findLeaderboardIfNecessary(id);
		leaderboardOps.add(LeaderboardOp.DOWNLOAD(id));
		if (startProcessingNow) processNextLeaderboardOp();
		return true;
	}
	
	private static function findLeaderboardIfNecessary(id:String) {
		if (!Lambda.has(leaderboardIds, id) && !Lambda.exists(leaderboardOps, function(op) { return Type.enumEq(op, FIND(id)); }))
		{
			leaderboardOps.add(LeaderboardOp.FIND(id));
		}
	}
	
	/**
	 * Returns achievement status.
	 * @param id Achievement API name.
	 * @return true, if achievement already achieved, false otherwise.
	 */
	public static function getAchievement(id:String):Bool {
		return active && SteamWrap_GetAchievement(id);
	}
	
	/**
	 * Returns human-readable achievement description.
	 * @param id Achievement API name.
	 * @return UTF-8 string with achievement description.
	 */
	public static function getAchievementDescription(id:String):String {
		if (!active) return null;
		return SteamWrap_GetAchievementDisplayAttribute(id, "desc");
	}
	
	/**
	 * Returns human-readable achievement name.
	 * @param id Achievement API name.
	 * @return UTF-8 string with achievement name.
	 */
	public static function getAchievementName(id:String):String {
		if (!active) return null;
		return SteamWrap_GetAchievementDisplayAttribute(id, "name");
	}
	
	public static function getCurrentGameLanguage() {
		return SteamWrap_GetCurrentGameLanguage();
	}
	
	
	
	public static function getPersonaName():String {
		if (!active)
			return "unknown";
		return SteamWrap_GetPersonaName();
	}
	
	/**
	 * Get a stat from steam as a float
	 * Kinda awkwardly returns 0 on errors and uses 0 for checking success
	 * @param	id
	 * @return
	 */
	public static function getStatFloat(id:String):Float {
		if (!active)
			return 0;
		var val = SteamWrap_GetStatFloat(id);
		report("getStat", [id], val != 0);
		return val;
	}
	
	/**
	 * Get a stat from steam as an integer
	 * Kinda awkwardly returns 0 on errors and uses 0 for checking success
	 * @param	id
	 * @return
	 */
	public static function getStatInt(id:String):Int {
		if (!active)
			return 0;
		var val = SteamWrap_GetStatInt(id);
		report("getStat", [id], val != 0);
		return val;
	}
	
	/**
	 * DEPRECATED: use getStatInt() instead!
	 * 
	 * Get a stat from steam as an integer
	 * Kinda awkwardly returns 0 on errors and uses 0 for checking success
	 * @param	id
	 * @return
	 */
	public static function getStat(id:String):Int {
		if (!active)
			return 0;
		var val = SteamWrap_GetStat(id);
		report("getStat", [id], val != 0);
		return val;
	}
	
	public static function getSteamID():String {
		if (!active)
			return "0";
		return SteamWrap_GetSteamID();
	}
	
	public static function indicateAchievementProgress(id:String, curProgress:Int, maxProgress:Int):Bool {
		return active && report("indicateAchivevementProgress", [id, Std.string(curProgress), Std.string(maxProgress)], SteamWrap_IndicateAchievementProgress(id, curProgress, maxProgress));
	}
	
	public static function isOverlayEnabled():Bool {
		if (!active)
			return false;
		return SteamWrap_IsOverlayEnabled();
	}
	
	public static function BOverlayNeedsPresent() {
		if (!active)
			return false;
		return SteamWrap_BOverlayNeedsPresent();
	}
	
	public static function isSteamInBigPictureMode() {
		if (!active)
			return false;
		return SteamWrap_IsSteamInBigPictureMode();
	}
	
	public static function isSteamRunning() {
		if (!active)
			return false;
		try{
			return SteamWrap_IsSteamRunning();
		}
		catch (msg:Dynamic)
		{
			trace("error running steam: " + msg);
		}
		return false;
	}
	
	public static function onEnterFrame() {
		if (!active) return;
		SteamWrap_RunCallbacks();

		if (wantStoreStats) {
			wantStoreStats = false;
			SteamWrap_StoreStats();
		}
	}
	
	public static function openOverlay(url:String) {
		if (!active) return;
		SteamWrap_OpenOverlay(url);
	}
	
	public static function restartAppInSteam():Bool {
		if (!active) return false;
		return SteamWrap_RestartAppIfNecessary(appId);
	}
	
	public static function shutdown() {
		if (!active) return;
		SteamWrap_Shutdown();
	}
	
	public static function setAchievement(id:String):Bool {
		return active && report("setAchievement", [id], SteamWrap_SetAchievement(id));
	}
	
	/**
	 * Returns achievement "hidden" flag.
	 * @param id Achievement API name.
	 * @return true, if achievement is flagged as hidden, false otherwise.
	 */
	public static function isAchievementHidden(id:String):Bool {
		return active && SteamWrap_GetAchievementDisplayAttribute(id, "hidden") == "1";
	}
	
	/**
	 * Returns amount of achievements.
	 * Used for iterating achievements. In general games should not need these functions because they should have a
	 * list of existing achievements compiled into them.
	 */
	public static function getNumAchievements():Int {
		if (!active) return 0;
		return SteamWrap_GetNumAchievements();
	}
	
	/**
	 * Returns achievement API name from its index in achievement list.
	 * @param index Achievement index in range [0,getNumAchievements].
	 * @return Achievement API name.
	 */
	public static function getAchievementAPIName(index:Int):String {
		if (!active) return null;
		return SteamWrap_GetAchievementName(index);
	}
	
	/**
	 * DEPRECATED: use setStatInt() instead!
	 * 
	 * Sets a steam stat as an int
	 * @param	id Stat API name
	 * @param	val
	 * @return
	 */
	public static function setStat(id:String, val:Int):Bool {
		return active && report("setStat", [id, Std.string(val)], SteamWrap_SetStat(id, val));
	}
	
	/**
	 * Sets a steam stat as a float
	 * @param	id Stat API name
	 * @param	val
	 * @return
	 */
	public static function setStatFloat(id:String, val:Float):Bool {
		return active && report("setStatFloat", [id, Std.string(val)], SteamWrap_SetStatFloat(id, val));
	}
	
	/**
	 * Sets a steam stat as an int
	 * @param	id Stat API name
	 * @param	val
	 * @return
	 */
	public static function setStatInt(id:String, val:Int):Bool {
		return active && report("setStatInt", [id, Std.string(val)], SteamWrap_SetStatInt(id, val));
	}
	
	public static function storeStats():Bool {
		return active && report("storeStats", [], SteamWrap_StoreStats());
	}
	
	public static function uploadLeaderboardScore(score:LeaderboardScore):Bool {
		if (!active) return false;
		var startProcessingNow = (leaderboardOps.length == 0);
		findLeaderboardIfNecessary(score.leaderboardId);
		leaderboardOps.add(LeaderboardOp.UPLOAD(score));
		if (startProcessingNow) processNextLeaderboardOp();
		return true;
	}

	//PRIVATE:

	private static var haveGlobalStats:Bool;
	private static var haveReceivedUserStats:Bool;
	private static var wantStoreStats:Bool;
	private static var appId:Int;

	private static var leaderboardIds:Array<String>;
	private static var leaderboardOps:List<LeaderboardOp>;
	
	private static inline function customTrace(str:String) {
		if (whenTrace != null)
			whenTrace(str);
		else
			trace(str);
	}
	
	private static function processNextLeaderboardOp() {
		var op = leaderboardOps.pop();
		if (op == null) return;
		
		switch (op) {
			case FIND(id):
				if (!report("Leaderboard.FIND", [id], SteamWrap_FindLeaderboard(id)))
					processNextLeaderboardOp();
			case UPLOAD(score):
				if (!report("Leaderboard.UPLOAD", [score.toString()], SteamWrap_UploadScore(score.leaderboardId, score.score, score.detail)))
					processNextLeaderboardOp();
			case DOWNLOAD(id):
				if (!report("Leaderboard.DOWNLOAD", [id], SteamWrap_DownloadScores(id, 0, 0)))
					processNextLeaderboardOp();
		}
	}
	
	private static inline function report(func:String, params:Array<String>, result:Bool):Bool {
		var str = "[STEAM] " + func + "(" + params.join(",") + ") " + (result ? " SUCCEEDED" : " FAILED");
		customTrace(str);
		return result;
	}

	private static function steamWrap_onEvent(e:Dynamic) {
		var type:String = Std.string(Reflect.field(e, "type"));
		var success:Bool = (Std.int(Reflect.field(e, "success")) != 0);
		var data:String = Std.string(Reflect.field(e, "data"));
		
		customTrace("[STEAM] " + type + (success ? " SUCCESS" : " FAIL") + " (" + data + ")");
		
		switch (type) {
			case "UserStatsReceived":
				haveReceivedUserStats = success;
				
			case "UserStatsStored":
				// retry next frame if failed
				wantStoreStats = !success;
				
			case "UserAchievementStored":
				if (whenAchievementStored != null) whenAchievementStored(data);
			
			case "GamepadTextInputDismissed":
				if (whenGamepadTextInputDismissed != null) {
					if (success) {
						whenGamepadTextInputDismissed(controllers.getEnteredGamepadTextInput());
					}
					else {
						whenGamepadTextInputDismissed(null);
					}
				}
			
			case "GlobalStatsReceived":
				haveGlobalStats = success;
				
			case "LeaderboardFound":
				if (success) {
					leaderboardIds.push(data);
				}
				processNextLeaderboardOp();
			case "ScoreDownloaded":
				if (success) {
					var scores = data.split(";");
					for (score in scores) {
						var score = LeaderboardScore.fromString(data);
						if (score != null && whenLeaderboardScoreDownloaded != null) whenLeaderboardScoreDownloaded(score);
					}
				}
				processNextLeaderboardOp();
			case "ScoreUploaded":
				if (success) {
					var score = LeaderboardScore.fromString(data);
					if (score != null && whenLeaderboardScoreUploaded != null) whenLeaderboardScoreUploaded(score);
				}
				processNextLeaderboardOp();
			case "UGCItemCreated":
				if (success && whenUGCItemIdReceived != null) {
					whenUGCItemIdReceived(data);
				}
			case "UGCItemUpdateSubmitted":
				if (whenUGCItemUpdateComplete != null) {
					whenUGCItemUpdateComplete(success, data);
				}
			case "UGCLegalAgreementStatus":
			case "RemoteStorageFileShared":
				if (whenRemoteStorageFileShared != null) {
					whenRemoteStorageFileShared(success, data);
				}
			case "UserSharedWorkshopFilesEnumerated":
				if (whenUserSharedWorkshopFilesEnumerated != null) {
					var result = EnumerateUserPublishedFilesResult.fromString(data);
					whenUserSharedWorkshopFilesEnumerated(success, result);
				}
			case "PublishedWorkshopFilesEnumerated":
				if (whenPublishedWorkshopFilesEnumerated != null) {
					var result = EnumerateWorkshopFilesResult.fromString(data);
					whenPublishedWorkshopFilesEnumerated(success, result);
				}
			case "UserSubscribedFilesEnumerated":
				if (whenUserSubscribedFilesEnumerated != null) {
					var result = EnumerateUserSubscribedFilesResult.fromString(data);
					whenUserSubscribedFilesEnumerated(success, result);
				}
			case "UserPublishedFilesEnumerated":
				if (whenUserPublishedFilesEnumerated != null) {
					var result = EnumerateUserPublishedFilesResult.fromString(data);
					whenUserPublishedFilesEnumerated(success, result);
				}
			case "UGCDownloaded":
				if (whenUGCDownloaded != null) {
					var result = DownloadUGCResult.fromString(data);
					whenUGCDownloaded(success, result);
				}
			case "PublishedFileDetailsGotten":
				if (whenPublishedFileDetailsGotten != null) {
					var result = GetPublishedFileDetailsResult.fromString(data);
					whenPublishedFileDetailsGotten(success, result);
				}
			case "ItemInstalled":
				if (whenItemInstalled != null) {
					var result:String = cast data;
					whenItemInstalled(result);
				}
			case "ItemDownloaded":
				if (whenItemDownloaded != null) {
					var result:String = cast data;
					whenItemDownloaded(success, result);
				}
			case "UGCQueryCompleted":
				if (whenQueryUGCRequestSent != null) {
					var result = SteamUGCQueryCompleted.fromString(data);
					whenQueryUGCRequestSent(result);
				}
		}
	}
	
	private static var SteamWrap_Init:Dynamic;
	private static var SteamWrap_Shutdown:Dynamic;
	private static var SteamWrap_RunCallbacks:Dynamic;
	private static var SteamWrap_RequestStats:Dynamic;
	private static var SteamWrap_GetStat:Dynamic;
	private static var SteamWrap_GetStatFloat:Dynamic;
	private static var SteamWrap_GetStatInt:Dynamic;
	private static var SteamWrap_SetStat:Dynamic;
	private static var SteamWrap_SetStatFloat:Dynamic;
	private static var SteamWrap_SetStatInt:Dynamic;
	private static var SteamWrap_SetAchievement:Dynamic;
	private static var SteamWrap_GetAchievement:String->Bool;
	private static var SteamWrap_GetAchievementDisplayAttribute:String->String->String;
	private static var SteamWrap_GetNumAchievements:Void->Int;
	private static var SteamWrap_GetAchievementName:Int->String;
	private static var SteamWrap_GetSteamID:Void->String;
	private static var SteamWrap_GetPersonaName:Void->String;
	private static var SteamWrap_ClearAchievement:Dynamic;
	private static var SteamWrap_IndicateAchievementProgress:Dynamic;
	private static var SteamWrap_StoreStats:Dynamic;
	private static var SteamWrap_FindLeaderboard:Dynamic;
	private static var SteamWrap_UploadScore:String->Int->Int->Bool;
	private static var SteamWrap_DownloadScores:String->Int->Int->Bool;
	private static var SteamWrap_RequestGlobalStats:Dynamic;
	private static var SteamWrap_GetGlobalStat:Dynamic;
	private static var SteamWrap_RestartAppIfNecessary:Dynamic;
	private static var SteamWrap_IsOverlayEnabled:Dynamic;
	private static var SteamWrap_BOverlayNeedsPresent:Dynamic;
	private static var SteamWrap_IsSteamInBigPictureMode:Dynamic;
	private static var SteamWrap_IsSteamRunning:Dynamic;
	private static var SteamWrap_GetCurrentGameLanguage:Dynamic;
	private static var SteamWrap_OpenOverlay:Dynamic;
}

class LeaderboardScore {
	public var leaderboardId:String;
	public var score:Int;
	public var detail:Int;
	public var rank:Int;

	public function new(leaderboardId_:String, score_:Int, detail_:Int, rank_:Int=-1) {
		leaderboardId = leaderboardId_;
		score = score_;
		detail = detail_;
		rank = rank_;
	}

	public function toString():String {
		return leaderboardId  + "," + score + "," + detail + "," + rank;
	}

	public static function fromString(str:String):LeaderboardScore {
		var tokens = str.split(",");
		if (tokens.length == 4)
			return new LeaderboardScore(tokens[0], Util.str2Int(tokens[1]), Util.str2Int(tokens[2]), Util.str2Int(tokens[3]));
		else
			return null;
	}
}

class EnumerateUserSubscribedFilesResult extends EnumerateUserPublishedFilesResult
{
	public var timeSubscribed:Array<Int>;
	
	public function new(Result:EResult=1, ResultsReturned:Int=0, TotalResults:Int=0, PublishedFileIds:Array<String>=null, TimeSubscribed:Array<Int>=null)
	{
		super(Result, ResultsReturned, TotalResults, PublishedFileIds);
		timeSubscribed = TimeSubscribed;
	}
	
	public static function fromString(str:String):EnumerateUserSubscribedFilesResult
	{
		var returnObject = new EnumerateUserSubscribedFilesResult();
		returnObject = cast EnumerateUserPublishedFilesResult.fromString(str, returnObject);
		
		var timeSubscribed:Array<Int> = [];
		
		var arr = str.split(",");
		var currField = "";
		for (str in arr){
			
			if (str.indexOf(":") == -1){
				
				currField = "";
				var nameValue = str.split(":");
				
				if (nameValue[0] == "timeSubscribed"){
					timeSubscribed.push(Util.str2Int(nameValue[1]));
					currField = "timeSubscribed";
				}
				
			}
			else
			{
				if (currField == "timeSubscribed"){
					timeSubscribed.push(Util.str2Int(str));
				}
			}
		}
		
		returnObject.timeSubscribed = timeSubscribed;
		return returnObject;
	}
	
	public override function toString():String
	{
		return "EnumerateUserSubscribedFilesResult{result:" + result + ",resultsReturned:" + resultsReturned + ",totalResults:" + totalResults + ",publishedFileIds:" + publishedFileIds + "timeSubscribed:" + timeSubscribed + "}";
	}
}

class EnumerateWorkshopFilesResult extends EnumerateUserPublishedFilesResult
{
	public var score:Array<Float>;
	public var appID:Int;
	public var startIndex:Int;
	
	public function new(Result:EResult=1, ResultsReturned:Int=0, TotalResults:Int=0, PublishedFileIds:Array<String>=null, Score:Array<Float>=null, AppID:Int=0, StartIndex:Int=0)
	{
		super(Result, ResultsReturned, TotalResults, PublishedFileIds);
		score = Score;
		appID = AppID;
		startIndex = StartIndex;
	}
	
	public static function fromString(str:String):EnumerateWorkshopFilesResult
	{
		var returnObject = new EnumerateWorkshopFilesResult();
		EnumerateUserPublishedFilesResult.fromString(str, returnObject);
		
		var appID:Int = 0;
		var startIndex:Int = 0;
		
		var arr = str.split(",");
		var currField = "";
		for (str in arr){
			
			if (str.indexOf(":") != -1)
			{
				var nameValue = str.split(":");
				switch(nameValue[0]) {
					case "appID":       appID = Util.str2Int(nameValue[1]);
					case "startIndex":  startIndex = Util.str2Int(nameValue[1]);
					default: //do nothing
				}
			}
			
		}
		
		returnObject.appID = appID;
		returnObject.startIndex = startIndex;
		
		return returnObject;
	}
	
	public override function toString():String
	{
		return "EnumerateWorkshopFilesResult{result:" + result + ",resultsReturned:" + resultsReturned + ",totalResults:" + totalResults + ",appID:" + appID + ",startIndex:" + startIndex + ",publishedFileIds:" + publishedFileIds + "}";
	}
}

class EnumerateUserPublishedFilesResult
{
	public var result:EResult;
	public var resultsReturned:Int;
	public var totalResults:Int;
	public var publishedFileIds:Array<String>;
	
	public function new(Result:EResult=Fail, ResultsReturned:Int=0, TotalResults:Int=0, PublishedFileIds:Array<String>=null)
	{
		result = Result;
		resultsReturned = ResultsReturned;
		totalResults = TotalResults;
		publishedFileIds = PublishedFileIds;
	}
	
	public static function fromString(str:String, ?resultObject:EnumerateUserPublishedFilesResult):EnumerateUserPublishedFilesResult
	{
		var result:Int = EResult.Fail;
		var resultsReturned:Int = 0;
		var totalResults:Int = 0;
		var publishedFileIds:Array<String> = [];
		
		var arr = str.split(",");
		var currField = "";
		for (str in arr){
			
			if (str.indexOf(":") != -1)
			{
				currField = "";
				var nameValue = str.split(":");
				switch(nameValue[0]){
					case "result":           result = Util.str2Int(nameValue[1]);
					case "resultsReturned":  resultsReturned = Util.str2Int(nameValue[1]);
					case "totalResults":     totalResults = Util.str2Int(nameValue[1]);
					case "publishedFileIds": publishedFileIds.push(nameValue[1]);
						                     currField = "publishedFileIds";
				}
			}
			else
			{
				if (currField == "publishedFileIds")
				{
					publishedFileIds.push(str);
				}
			}
		}
		
		if (resultObject == null)
		{
			resultObject = new EnumerateUserPublishedFilesResult();
		}
		
		resultObject.result = cast result;
		resultObject.resultsReturned = resultsReturned;
		resultObject.totalResults = totalResults;
		resultObject.publishedFileIds = publishedFileIds;
		
		return resultObject;
	}
	
	public function toString():String
	{
		return "EnumerateUserPublishedFilesResult{result:" + result + ",resultsReturned:" + resultsReturned + ",totalResults:" + totalResults + ",publishedFileIds:" + publishedFileIds+"}";
	}
}

class DownloadUGCResult
{
	public var result:EResult;
	public var fileHandle:String;
	public var appID:Int;
	public var sizeInBytes:Int;
	public var fileName:String;
	public var steamIDOwner:String;
	
	public function new(Result:EResult = Fail, FileHandle:String = "", AppID:Int = 0, SizeInBytes:Int = 0, FileName:String = "", SteamIDOwner:String = "")
	{
		result = Result;
		fileHandle = FileHandle;
		appID = AppID;
		sizeInBytes = SizeInBytes;
		fileName = FileName;
		steamIDOwner = SteamIDOwner;
	}
	
	public static function fromString(str:String):DownloadUGCResult
	{
		var result = Fail;
		var fileHandle = "";
		var appID = 0;
		var sizeInBytes = 0;
		var fileName = "";
		var steamIDOwner = "";
		
		var arr = str.split(",");
		for (str in arr){
			if (str.indexOf(":") != -1)
			{
				var nameValue = str.split(":");
				switch(nameValue[0]){
					case "result":       result = Util.str2Int(nameValue[1]);
					case "fileHandle":   fileHandle = nameValue[1];
					case "appID":        appID = Util.str2Int(nameValue[1]);
					case "sizeInBytes":  sizeInBytes = Util.str2Int(nameValue[1]);
					case "fileName":     fileName = nameValue[1];
					case "steamIDOwner": steamIDOwner = nameValue[1];
				}
			}
		}
		
		return new DownloadUGCResult(result, fileHandle, appID, sizeInBytes, fileName, steamIDOwner);
	}
	
	public function toString():String
	{
		return ("{result:" + result + ",fileHandle:" + fileHandle+",appID:" + appID + ",sizeInBytes:" + sizeInBytes + ",fileName:" + fileName+",steamIDOwner:" + steamIDOwner + "}");
	}
}

class GetItemInstallInfoResult
{
	public var sizeOnDisk:Int;
	public var folder:String;
	public var timeStamp:String;
	
	public function new(SizeOnDisk:Int = 0, Folder:String = "", TimeStamp:String = "")
	{
		sizeOnDisk = SizeOnDisk;
		folder = Folder;
		timeStamp = TimeStamp;
	}
	
	public static function fromString(str:String):GetItemInstallInfoResult
	{
		var sizeOnDisk:Int = 0;
		var folder:String = "";
		var timeStamp:String = "";
		
		var folderSize:Int = 0;
		
		var arr = str.split("|");
		
		if (arr != null && arr.length == 4){
			var sizeOnDiskStr = arr[0];
			folder = arr[1];
			var folderSizeStr = arr[2];
			timeStamp = arr[3];
			
			var i:Null<Int> = 0;
			
			i = Util.str2Int(sizeOnDiskStr);
			sizeOnDisk = (i != null) ? i : 0;
			
			i = Util.str2Int(folderSizeStr);
			folderSize = (i != null) ? i : 0;
		}
		
		if(folder.length > folderSize){
			folder = folder.substr(0, folderSize);
		}
		
		return new GetItemInstallInfoResult(sizeOnDisk, folder, timeStamp);
	}
}

class GetPublishedFileDetailsResult
{
	public var result:EResult;
	public var fileID:String;
	public var creatorAppID:String;
	public var consumerAppID:String;
	public var title:String;
	public var description:String;
	public var fileHandle:String;
	public var previewFileHandle:String;
	public var steamIDOwner:String;
	public var timeCreated:Int;
	public var timeUpdated:Int;
	public var visibility:EPublishedFileVisibility;
	public var banned:Bool;
	public var tags:String;
	public var tagsTruncated:Bool;
	public var fileName:String;
	public var fileSize:Int;
	public var previewFileSize:Int;
	public var url:String;
	public var fileType:EWorkshopFileType;
	public var acceptedForUse:Bool;
	
	public function new(
		Result:EResult = Fail,
		FileID:String = "",
		CreatorAppID:String = "",
		ConsumerAppID:String = "",
		Title:String = "",
		Description:String = "",
		FileHandle:String = "",
		PreviewFileHandle:String = "",
		SteamIDOwner:String = "",
		TimeCreated:Int = 0,
		TimeUpdated:Int = 0,
		Visibility:EPublishedFileVisibility,
		Banned:Bool = false,
		Tags:String = "",
		TagsTruncated:Bool = false,
		FileName:String = "",
		FileSize:Int = 0,
		PreviewFileSize:Int = 0,
		URL:String = "",
		FileType:EWorkshopFileType,
		AcceptedForUse:Bool = false
	)
	{
		result = Result;
		fileID = FileID;
		creatorAppID = CreatorAppID;
		consumerAppID = ConsumerAppID;
		title = Title;
		description = Description;
		fileHandle = FileHandle;
		previewFileHandle = PreviewFileHandle;
		steamIDOwner = SteamIDOwner;
		timeCreated = TimeCreated;
		timeUpdated = TimeUpdated;
		visibility = Visibility;
		banned = Banned;
		tags = Tags;
		tagsTruncated = TagsTruncated;
		fileName = FileName;
		fileSize = FileSize;
		previewFileSize = PreviewFileSize;
		url = URL;
		fileType = FileType;
		acceptedForUse = AcceptedForUse;
	}
	
	public static function fromString(str:String):GetPublishedFileDetailsResult
	{
		var result:EResult = Fail;
		var fileID:String = "";
		var creatorAppID:String = "";
		var consumerAppID:String = "";
		var title:String = "";
		var description:String = "";
		var fileHandle:String = "";
		var previewFileHandle:String = "";
		var steamIDOwner:String = "";
		var timeCreated:Int = 0;
		var timeUpdated:Int = 0;
		var visibility:EPublishedFileVisibility = Private;
		var banned:Bool = false;
		var tags:String = "";
		var tagsTruncated:Bool = false;
		var fileName:String = "";
		var fileSize:Int = 0;
		var previewFileSize:Int = 0;
		var url:String = "";
		var fileType:EWorkshopFileType = Community;
		var acceptedForUse:Bool = false;
		
		var arr = str.split(",");
		for (str in arr){
			if (str.indexOf(":") != -1)
			{
				var nameValue = str.split(":");
				switch(nameValue[0]){
					case "result":             result = Util.str2Int(nameValue[1]);
					case "publishedFileID":    fileID = nameValue[1];
					case "creatorAppID":       creatorAppID = nameValue[1];
					case "consumerAppID":      consumerAppID = nameValue[1];
					case "title":              title = nameValue[1];
					case "description":        description = nameValue[1];
					case "fileHandle":         fileHandle = nameValue[1];
					case "previewFileHandle":  previewFileHandle = nameValue[1];
					case "steamIDOwner":       steamIDOwner = nameValue[1];
					case "timeCreated":        timeCreated = Util.str2Int(nameValue[1]);
					case "timeUpdated":        timeUpdated = Util.str2Int(nameValue[1]);
					case "visibility":         visibility = Util.str2Int(nameValue[1]);
					case "banned":             banned = Util.boolify(nameValue[1]);
					case "tagsTruncated":      tagsTruncated = Util.boolify(nameValue[1]);
					case "fileName":           fileName = nameValue[1];
					case "fileSize":           fileSize = Util.str2Int(nameValue[1]);
					case "url":                url = nameValue[1];
					case "fileType":           fileType = Util.str2Int(nameValue[1]);
					case "acceptedForUse":     acceptedForUse = Util.boolify(nameValue[1]);
				}
			}
		}
		
		return new GetPublishedFileDetailsResult(
			result,
			fileID,
			creatorAppID,
			consumerAppID,
			title,
			description,
			fileHandle,
			previewFileHandle,
			steamIDOwner,
			timeCreated,
			timeUpdated,
			visibility,
			banned,
			tagsTruncated,
			fileName,
			fileSize,
			url,
			fileType,
			acceptedForUse
		);
	}
}

class SteamUGCQueryCompleted
{
	public var handle:String = "";
	public var result:EResult = EResult.Fail;
	public var numResultsReturned:Int = 0;
	public var totalMatchingResults:Int = 0;
	public var cachedData:Bool = false;
	
	public function new(){}
	
	public static function fromString(str:String):SteamUGCQueryCompleted{
		var arr = str.split(",");
		var data = new SteamUGCQueryCompleted();
		if(arr != null && arr.length >= 4){
			var handle:String = arr[0];
			var result:EResult = Util.str2Int(arr[1]);
			var numResultsReturned:Int = Util.str2Int(arr[2]);
			var totalMatchingResults:Int = Util.str2Int(arr[3]);
			var cachedData:Bool = Util.boolify(arr[4]);
			data.handle = handle;
			data.result = result;
			data.numResultsReturned = numResultsReturned;
			data.totalMatchingResults = totalMatchingResults;
			data.cachedData = cachedData;
		}
		return data;
	}
}

class SteamUGCDetails
{
	public var publishedFileId:String = "";
	
	/** The result of the operation. **/
	public var result:EResult = EResult.Fail;
	
	/** Type of the file **/
	public var fileType:EWorkshopFileType = EWorkshopFileType.Community;
	
	/** ID of the app that created this file **/
	public var creatorAppID:String = "";
	
	/** ID of the app that will consume this file **/
	public var consumerAppID:String = "";
	
	/** title of document **/
	public var title:String = "";
	
	/** description of document **/
	public var description:String = "";
	
	/** Steam ID of the user who created this content **/
	public var steamIDOwner:String = "";
	
	/** time when the published file was created **/
	public var timeCreated:Float = 0;
	
	/** time when the published file was last updated **/
	public var timeUpdated:Float = 0;
	
	/** time when the user added the published file to their list (not always applicable) **/
	public var timeAddedToUserList:Float = 0;
	
	/** visibility **/
	public var visibility:EPublishedFileVisibility = EPublishedFileVisibility.Private;
	
	/** whether the file was banned **/
	public var banned:Bool = false;
	
	/** developer has specifically flagged this item as accepted in the Workshop **/
	public var acceptedForUse:Bool = false;
	
	/** whether the list of tags was too long to be returned in the provided buffer **/
	public var tagsTruncated:Bool = false;
	
	/** comma separated list of all tags associated with this file **/
	public var tags:String = "";
	
	/** The handle of the primary file **/
	public var file:String = "";
	
	/** The handle of the preview file **/
	public var previewFile:String = "";
	
	/** The cloud filename of the primary file **/
	public var fileName:String = "";
	
	/** Size of the primary file **/
	public var fileSize:Int = 0;
	
	/** Size of the preview file **/
	public var previewFileSize:Int = 0;
	
	/** URL (for a video or a website) **/
	public var url:String = "";
	
	/** number of votes up **/
	public var votesUp:Int = 0;
	
	/** number of votes down **/
	public var votesDown:Int = 0;
	
	/** calculated score **/
	public var score:Float = 0.0;
	
	/** collection details **/
	public var numChildren:Int = 0;
	
	public function new(
		PublishedFileId:String = "",
		Result:EResult = EResult.Fail,
		FileType:EWorkshopFileType = EWorkshopFileType.Community,
		CreatorAppID:String = "",
		ConsumerAppID:String = "",
		Title:String = "",
		Description:String = "",
		SteamIDOwner:String = "",
		TimeCreated:Float = 0,
		TimeUpdated:Float = 0,
		TimeAddedToUserList:Float = 0,
		Visibility:EPublishedFileVisibility = EPublishedFileVisibility.Private,
		Banned:Bool = false,
		AcceptedForUse:Bool = false,
		TagsTruncated:Bool = false,
		Tags:String = "",
		File:String = "",
		PreviewFile:String = "",
		FileName:String = "",
		FileSize:Int = 0,
		PreviewFileSize:Int = 0,
		URL:String = "",
		VotesUp:Int = 0,
		VotesDown:Int = 0,
		Score:Float = 0.0,
		NumChildren:Int = 0
	)
	{
		publishedFileId = PublishedFileId;
		result = Result;
		fileType = FileType;
		creatorAppID = CreatorAppID;
		consumerAppID = ConsumerAppID;
		title = Title;
		description = Description;
		steamIDOwner = SteamIDOwner;
		timeCreated = TimeCreated;
		timeUpdated = TimeUpdated;
		timeAddedToUserList = TimeAddedToUserList;
		visibility = Visibility;
		banned = Banned;
		acceptedForUse = AcceptedForUse;
		tagsTruncated = TagsTruncated;
		tags = Tags;
		file = File;
		previewFile = PreviewFile;
		fileName = FileName;
		fileSize = FileSize;
		previewFileSize = PreviewFileSize;
		url = URL;
		votesUp = VotesUp;
		votesDown = VotesDown;
		score = Score;
		numChildren = NumChildren;
	}
	
	public static function fromString(str:String):SteamUGCDetails{
		var PublishedFileId:String = "";
		var Result:EResult = EResult.Fail;
		var FileType:EWorkshopFileType = EWorkshopFileType.Community;
		var CreatorAppID:String = "";
		var ConsumerAppID:String = "";
		var Title:String = "";
		var Description:String = "";
		var SteamIDOwner:String = "";
		var TimeCreated:Float = 0;
		var TimeUpdated:Float = 0;
		var TimeAddedToUserList:Float = 0;
		var Visibility:EPublishedFileVisibility = EPublishedFileVisibility.Private;
		var Banned:Bool = false;
		var AcceptedForUse:Bool = false;
		var TagsTruncated:Bool = false;
		var Tags:String = "";
		var File:String = "";
		var PreviewFile:String = "";
		var FileName:String = "";
		var FileSize:Int = 0;
		var PreviewFileSize:Int = 0;
		var URL:String = "";
		var VotesUp:Int = 0;
		var VotesDown:Int = 0;
		var Score:Float = 0.0;
		var NumChildren:Int = 0;
		
		var arr = str.split(",");
		for (str in arr){
			if (str.indexOf(":") != -1)
			{
				var nameValue = str.split(":");
				var val = nameValue[1];
				
				switch(nameValue[0]){
					case "publishedFileId": PublishedFileId = val;
					case "result": Result = Util.str2Int(val);
					case "fileType": FileType = Util.str2Int(val);
					case "creatorAppID": CreatorAppID = val;
					case "consumerAppID": ConsumerAppID = val;
					case "title": Title = val;
					case "description": Description = val;
					case "steamIDOwner": SteamIDOwner = val;
					case "timeCreated": TimeCreated = Util.str2Float(val);
					case "timeUpdate": TimeUpdated = Util.str2Float(val);
					case "timeAddedToUserList": TimeAddedToUserList = Util.str2Float(val);
					case "visibility": Visibility = Util.str2Int(val);
					case "banned": Banned = Util.boolify(val);
					case "acceptedForUse": AcceptedForUse = Util.boolify(val);
					case "tagsTruncated": TagsTruncated = Util.boolify(val);
					case "tags": Tags = val;
					case "file": File = val;
					case "previewFile": PreviewFile = val;
					case "fileName": FileName = val;
					case "fileSize": FileSize = Util.str2Int(val);
					case "previewFileSize": PreviewFileSize = Util.str2Int(val);
					case "url": URL = val;
					case "votesUp": VotesUp = Util.str2Int(val);
					case "votesDown": VotesDown = Util.str2Int(val);
					case "score": Score = Util.str2Float(val);
					case "numChildren": NumChildren = Util.str2Int(val);
				}
			}
		}
		
		return new SteamUGCDetails(
			PublishedFileId,
			Result,
			FileType,
			CreatorAppID,
			ConsumerAppID,
			Title,
			Description,
			SteamIDOwner,
			TimeCreated,
			TimeUpdated,
			TimeAddedToUserList,
			Visibility,
			Banned,
			AcceptedForUse,
			TagsTruncated,
			Tags,
			File,
			PreviewFile,
			FileName,
			FileSize,
			PreviewFileSize,
			URL,
			VotesUp,
			VotesDown,
			Score,
			NumChildren
		);
	}
	
	public function toString():String{
		var names:Array<String> =
		[
			"publishedFileId",
			"result",
			"fileType",
			"creatorAppID",
			"consumerAppID",
			"title",
			"description",
			"steamIDOwner",
			"timeCreated",
			"timeUpdated",
			"timeAddedToUserList",
			"visibility",
			"banned",
			"acceptedForUse",
			"tagsTruncated",
			"tags",
			"file",
			"previewFile",
			"fileName",
			"fileSize",
			"previewFileSize",
			"url",
			"votesUp",
			"votesDown",
			"score",
			"numChildren"
		];
		var values:Array<Dynamic> = 
		[
			publishedFileId,
			result,
			fileType,
			creatorAppID,
			consumerAppID,
			title,
			description,
			steamIDOwner,
			timeCreated,
			timeUpdated,
			timeAddedToUserList,
			visibility,
			banned,
			acceptedForUse,
			tagsTruncated,
			tags,
			file,
			previewFile,
			fileName,
			fileSize,
			previewFileSize,
			url,
			votesUp,
			votesDown,
			score,
			numChildren
		];
		
		var str = "{";
		for (i in 0...names.length){
			var name = names[i];
			var value = values[i];
			str += name+":" + value;
			if (i != names.length - 1){
				str += ",";
			}
		}
		str += "}";
		return str;
	}
}

@:enum abstract EWorkshopFileType(Int) from Int to Int
{
	var Community              =  0;	// normal Workshop item that can be subscribed to
	var Microtransaction       =  1;	// Workshop item that is meant to be voted on for the purpose of selling in-game
	var Collection             =  2;	// a collection of Workshop or Greenlight items
	var Art                    =  3;	// artwork
	var Video                  =  4;	// external video
	var Screenshot             =  5;	// screenshot
	var Game                   =  6;	// Greenlight game entry
	var Software               =  7;	// Greenlight software entry
	var Concept                =  8;	// Greenlight concept
	var WebGuide               =  9;	// Steam web guide
	var IntegratedGuide        = 10;	// application integrated guide
	var Merch                  = 11;	// Workshop merchandise meant to be voted on for the purpose of being sold
	var ControllerBinding      = 12;	// Steam Controller bindings
	var SteamWorksAccessInvite = 13;	// internal
	var SteamVideo             = 14;	// Steam video
	var GameManagedItem        = 15;	// managed completely by the game, not the user, and not shown on the web
	
	public inline function fromInt(i:Int)
	{
		if (i < 0 || i > 15)
		{
			this = Community;
		}
		else
		{
			this = i;
		}
	}
	
	public inline function toInt():Int
	{
		return cast this;
	}
}

@:enum abstract EPublishedFileVisibility(Int) from Int to Int
{
	var Public = 0;
	var FriendsOnly = 1;
	var Private = 2;
	
	public inline function fromInt(i:Int)
	{
		if (i < 0 || i > 2)
		{
			this = Private;
		}
		else
		{
			this = i;
		}
	}
	
	public inline function toInt():Int
	{
		return cast this;
	}
}

@:enum abstract EResult(Int) from Int to Int
{
	var OK  = 1;                            // success
	var Fail = 2;                           // generic failure 
	var NoConnection = 3;                   // no/failed network connection
	//var NoConnectionRetry = 4;            // OBSOLETE - removed
	var InvalidPassword = 5;                // password/ticket is invalid
	var LoggedInElsewhere = 6;              // same user logged in elsewhere
	var InvalidProtocolVer = 7;             // protocol version is incorrect
	var InvalidParam = 8;                   // a parameter is incorrect
	var FileNotFound = 9;                   // file was not found
	var Busy = 10;                          // called method busy - action not taken
	var InvalidState = 11;                  // called object was in an invalid state
	var InvalidName = 12;                   // name is invalid
	var InvalidEmail = 13;                  // email is invalid
	var DuplicateName = 14;                 // name is not unique
	var AccessDenied = 15;                  // access is denied
	var Timeout = 16;                       // operation timed out
	var Banned = 17;                        // VAC2 banned
	var AccountNotFound = 18;               // account not found
	var InvalidSteamID = 19;                // steamID is invalid
	var ServiceUnavailable = 20;            // The requested service is currently unavailable
	var NotLoggedOn = 21;                   // The user is not logged on
	var Pending = 22;                       // Request is pending (may be in process; or waiting on third party)
	var EncryptionFailure = 23;             // Encryption or Decryption failed
	var InsufficientPrivilege = 24;         // Insufficient privilege
	var LimitExceeded = 25;                 // Too much of a good thing
	var Revoked = 26;                       // Access has been revoked (used for revoked guest passes)
	var Expired = 27;                       // License/Guest pass the user is trying to access is expired
	var AlreadyRedeemed = 28;               // Guest pass has already been redeemed by account; cannot be acked again
	var DuplicateRequest = 29;              // The request is a duplicate and the action has already occurred in the past; ignored this time
	var AlreadyOwned = 30;                  // All the games in this guest pass redemption request are already owned by the user
	var IPNotFound = 31;                    // IP address not found
	var PersistFailed = 32;                 // failed to write change to the data store
	var LockingFailed = 33;                 // failed to acquire access lock for this operation
	var LogonSessionReplaced = 34;
	var ConnectFailed = 35;
	var HandshakeFailed = 36;
	var IOFailure = 37;
	var RemoteDisconnect = 38;
	var ShoppingCartNotFound = 39;          // failed to find the shopping cart requested
	var Blocked = 40;                       // a user didn't allow it
	var Ignored = 41;                       // target is ignoring sender
	var NoMatch = 42;                       // nothing matching the request found
	var AccountDisabled = 43;
	var ServiceReadOnly = 44;               // this service is not accepting content changes right now
	var AccountNotFeatured = 45;            // account doesn't have value; so this feature isn't available
	var AdministratorOK = 46;               // allowed to take this action; but only because requester is admin
	var ContentVersion = 47;                // A Version mismatch in content transmitted within the Steam protocol.
	var TryAnotherCM = 48;                  // The current CM can't service the user making a request; user should try another.
	var PasswordRequiredToKickSession = 49; // You are already logged in elsewhere; this cached credential login has failed.
	var AlreadyLoggedInElsewhere = 50;      // You are already logged in elsewhere; you must wait
	var Suspended = 51;                     // Long running operation (content download) suspended/paused
	var Cancelled = 52;                     // Operation canceled (typically by user: content download)
	var DataCorruption = 53;                // Operation canceled because data is ill formed or unrecoverable
	var DiskFull = 54;                      // Operation canceled - not enough disk space.
	var RemoteCallFailed = 55;              // an remote call or IPC call failed
	var PasswordUnset = 56;                 // Password could not be verified as it's unset server side
	var ExternalAccountUnlinked = 57;       // External account (PSN; Facebook...) is not linked to a Steam account
	var PSNTicketInvalid = 58;              // PSN ticket was invalid
	var ExternalAccountAlreadyLinked = 59;  // External account (PSN; Facebook...) is already linked to some other account; must explicitly request to replace/delete the link first
	var RemoteFileConflict = 60;            // The sync cannot resume due to a conflict between the local and remote files
	var IllegalPassword = 61;               // The requested new password is not legal
	var SameAsPreviousValue = 62;           // new value is the same as the old one ( secret question and answer )
	var AccountLogonDenied = 63;            // account login denied due to 2nd factor authentication failure
	var CannotUseOldPassword = 64;          // The requested new password is not legal
	var InvalidLoginAuthCode = 65;          // account login denied due to auth code invalid
	var AccountLogonDeniedNoMail = 66;      // account login denied due to 2nd factor auth failure - and no mail has been sent
	var HardwareNotCapableOfIPT = 67;       // 
	var IPTInitError = 68;                  // 
	var ParentalControlRestricted = 69;     // operation failed due to parental control restrictions for current user
	var FacebookQueryError = 70;            // Facebook query returned an error
	var ExpiredLoginAuthCode = 71;          // account login denied due to auth code expired
	var IPLoginRestrictionFailed = 72;
	var AccountLockedDown = 73;
	var AccountLogonDeniedVerifiedEmailRequired = 74;
	var NoMatchingURL = 75;
	var BadResponse = 76;                   // parse failure; missing field; etc.
	var RequirePasswordReEntry = 77;        // The user cannot complete the action until they re-enter their password
	var ValueOutOfRange = 78;               // the value entered is outside the acceptable range
	var UnexpectedError = 79;               // something happened that we didn't expect to ever happen
	var Disabled = 80;                      // The requested service has been configured to be unavailable
	var InvalidCEGSubmission = 81;          // The set of files submitted to the CEG server are not valid !
	var RestrictedDevice = 82;              // The device being used is not allowed to perform this action
	var RegionLocked = 83;                  // The action could not be complete because it is region restricted
	var RateLimitExceeded = 84;             // Temporary rate limit exceeded; try again later; different from var LimitExceeded which may be permanent
	var AccountLoginDeniedNeedTwoFactor = 85;   // Need two-factor code to login
	var ItemDeleted = 86;                   // The thing we're trying to access has been deleted
	var AccountLoginDeniedThrottle = 87;    // login attempt failed; try to throttle response to possible attacker
	var TwoFactorCodeMismatch = 88;         // two factor code mismatch
	var TwoFactorActivationCodeMismatch = 89;   // activation code for two-factor didn't match
	var AccountAssociatedToMultiplePartners = 90;   // account has been associated with multiple partners
	var NotModified = 91;                   // data not modified
	var NoMobileDevice = 92;                // the account does not have a mobile device associated with it
	var TimeNotSynced = 93;                 // the time presented is out of range or tolerance
	var SmsCodeFailed = 94;                 // SMS code failure (no match; none pending; etc.)
	var AccountLimitExceeded = 95;          // Too many accounts access this resource
	var AccountActivityLimitExceeded = 96;  // Too many changes to this account
	var PhoneActivityLimitExceeded = 97;    // Too many changes to this phone
	var RefundToWallet = 98;                // Cannot refund to payment method; must use wallet
	var EmailSendFailure = 99;              // Cannot send an email
	var NotSettled = 100;                   // Can't perform operation till payment has settled
	var NeedCaptcha = 101;                  // Needs to provide a valid captcha
	var GSLTDenied = 102;                   // a game server login token owned by this token's owner has been banned
	var GSOwnerDenied = 103;                // game server owner is denied for other reason (account lock; community ban; vac ban; missing phone)
	var InvalidItemType = 104;              // the type of thing we were requested to act on is invalid
	var IPBanned = 105;                     // the ip address has been banned from taking this action
	var GSLTExpired = 106;                  // this token has expired from disuse; can be reset for use

	public inline function fromInt(i:Int)
	{
		if (i < 0)
		{
			this = Fail;
		}
		else if (i > 3)
		{
			this = Fail;
		}
		else
		{
			this = i;
		}
	}

	public inline function toInt():Int
	{
		return cast this;
	}
}

@:enum abstract EUGCReadAction(Int) from Int to Int
{
	/**
	 * Keeps the file handle open unless the last byte is read.  You can use this when reading large files (over 100MB) in sequential chunks.
	 * If the last byte is read, this will behave the same as Close.  Otherwise, it behaves the same as ContinueReading.
	 * This value maintains the same behavior as before the EUGCReadAction parameter was introduced.
	 */
	var ContinueReadingUntilFinished = 0;
	
	/**
	 * Keeps the file handle open.  Use this when using UGCRead to seek to different parts of the file.
	 * When you are done seeking around the file, make a final call with k_EUGCRead_Close to close it.
	 */
	var ContinueReading = 1;
	
	/**
	 * Frees the file handle.  Use this when you're done reading the content.  
	 * To read the file from Steam again you will need to call UGCDownload again. 
	 */
	var Close = 2;
	
	public inline function fromInt(i:Int)
	{
		if (i < 0) i = 0;
		if (i > 2) i = 2;
		this = i;
	}
	
	public inline function toInt():Int
	{
		return cast this;
	}
}

@:enum abstract EItemState(Int) from Int to Int
{
	/**item not tracked on client**/
	var None			= 0; 
	
	/**current user is subscribed to this item. Not just cached.**/
	var Subscribed		= 1;
	
	/**item was created with ISteamRemoteStorage**/
	var LegacyItem		= 2;
	
	/**item is installed and usable (but maybe out of date)**/
	var Installed		= 4;
	
	/**items needs an update. Either because it's not installed yet or creator updated content**/
	var NeedsUpdate		= 8;
	
	/**item update is currently downloading**/
	var Downloading		= 16;
	
	/**DownloadItem() was called for this item, content isn't available until DownloadItemResult_t is fired**/
	var DownloadPending	= 32;
	
	public function has(state:EItemState):Bool
	{
		return this & state != None;
	}
	
	public inline function fromInt(i:Int){
		if (i < 0) i = 0;
		if (i > 32) i = 32;
		this = switch(i){
			case 0, 1, 2, 4, 8, 16, 32: i;
			default: 0;
		}
	}
	
	public inline function toInt():Int{
		return cast this;
	}
}

@:enum abstract EUGCQuery(Int) from Int to Int
{
	var RankedByVote:Int									= 0;
	var RankedByPublicationDate:Int							= 1;
	var AcceptedForGameRankedByAcceptanceDate:Int			= 2;
	var RankedByTrend:Int									= 3;
	var FavoritedByFriendsRankedByPublicationDate			= 4;
	var CreatedByFriendsRankedByPublicationDate:Int			= 5;
	var RankedByNumTimesReported:Int						= 6;
	var CreatedByFollowedUsersRankedByPublicationDate:Int	= 7;
	var NotYetRated:Int										= 8;
	var RankedByTotalVotesAsc:Int							= 9;
	var RankedByVotesUp:Int									= 10;
	var RankedByTextSearch:Int								= 11;
	var RankedByTotalUniqueSubscriptions:Int				= 12;
	var RankedByPlaytimeTrend:Int							= 13;
	var RankedByTotalPlaytime:Int							= 14;
	var RankedByAveragePlaytimeTrend:Int					= 15;
	var RankedByLifetimeAveragePlaytime:Int					= 16;
	var RankedByPlaytimeSessionsTrend:Int					= 17;
	var RankedByLifetimePlaytimeSessions:Int				= 18;
	
	public inline function fromInt(i:Int){
		if (i < 0) i = 0;
		if (i > 18) i = 18;
		this = i;
	}
	
	public inline function toInt():Int{
		return cast this;
	}
}

@:enum abstract EUGCMatchingUGCType(Int) from Int to Int
{
	/**both mtx items and ready-to-use items**/
	var Items:Int			= 0;
	var Items_Mtx:Int		= 1;
	var Items_ReadyToUse	= 2;
	var Collections:Int		= 3;
	var Artwork:Int			= 4;
	var Videos:Int			= 5;
	var Screenshots:Int		= 6;
	/**both web quides and integrated guides**/
	var AllGuides:Int		= 7;
	var WebGuides:Int		= 8;
	var IntegratedGuides	= 9;
	/**ready-to-use items and integrated guides**/
	var UsableInGame:Int	= 10;
	var ControllerBindings	= 11;
	/**game managed items (not managed by users)**/
	var GameManagedItems	= 12;
	/**return everything**/
	var All:Int				= ~0;
	
	public inline function fromInt(i:Int){
		if (i < -1) i = -1;
		if (i > 12) i = 12;
		this = i;
	}
	
	public inline function toInt():Int{
		return cast this;
	}
}

/**
 * Different lists of published UGC for a user.
 * If the current logged in user is different than the specified user, the same options may not be 
 * allowed.
 */
@:enum abstract EUserUGCList(Int) from Int to Int
{
	var Published:Int		= 0;
	var VotedOn:Int			= 1;
	var VotedUp:Int			= 2;
	var VotedDown:Int		= 3;
	var WillVoteLater:Int	= 4;
	var Favorited:Int		= 5;
	var Subscribed:Int		= 6;
	var UsedOrPlayed:Int	= 7;
	var Followed:Int		= 8;
	
	public inline function fromInt(i:Int){
		if (i < 0) i = 0;
		if (i > 8) i = 8;
		this = i;
	}
	
	public inline function toInt():Int{
		return cast this;
	}
}

@:enum abstract EUserUGCListSortOrder(Int) from Int to Int
{
	var CreationOrderDesc:Int		= 0;
	var CreationOrderAsc:Int		= 1;
	var TitleAsc:Int				= 2;
	var LastUpdatedDesc:Int			= 3;
	var SubscriptionDateDesc:Int	= 4;
	var VoteScoreDesc:Int			= 5;
	var ForModeration:Int			= 6;
	
	public inline function fromInt(i:Int){
		if (i < 0) i = 0;
		if (i > 6) i = 6;
		this = i;
	}
	
	public inline function toInt():Int{
		return cast this;
	}
}
