package steamwrap.api;
import cpp.Lib;
import haxe.Int64;
import steamwrap.api.Steam.EnumerateWorkshopFilesResult;
import steamwrap.api.Steam.DownloadUGCResult;
import steamwrap.helpers.Loader;

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
	 * The Steam Workshop API
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
		
		if(type != "" && type != null && type != "UserStatsStored"){
			trace("***steamWrap_onEvent(" + type+" , " + success + " , " + data + ")");
		}
		
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
				trace("BINGO BOINGO");
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
			return new LeaderboardScore(tokens[0], Std.parseInt(tokens[1]), Std.parseInt(tokens[2]), Std.parseInt(tokens[3]));
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
					timeSubscribed.push(Std.parseInt(nameValue[1]));
					currField = "timeSubscribed";
				}
				
			}
			else
			{
				if (currField == "timeSubscribed"){
					timeSubscribed.push(Std.parseInt(str));
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
					case "appID":       appID = Std.parseInt(nameValue[1]);
					case "startIndex":  startIndex = Std.parseInt(nameValue[1]);
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
		trace("fromString(" + str + ")");
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
					case "result":           result = Std.parseInt(nameValue[1]);
					case "resultsReturned":  resultsReturned = Std.parseInt(nameValue[1]);
					case "totalResults":     totalResults = Std.parseInt(nameValue[1]);
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
					case "result":       result = Std.parseInt(nameValue[1]);
					case "fileHandle":   fileHandle = nameValue[1];
					case "appID":        appID = Std.parseInt(nameValue[1]);
					case "sizeInBytes":  sizeInBytes = Std.parseInt(nameValue[1]);
					case "fileName":     fileName = nameValue[1];
					case "steamIDOwner": steamIDOwner = nameValue[1];
				}
			}
		}
		
		return new DownloadUGCResult(result, fileHandle, appID, sizeInBytes, fileName, steamIDOwner);
	}
}

@:enum abstract EResult(Int) from Int to Int
{
	var Ok = 0;
	var Fail = 1;
	var AlreadyRegistered= 2;
	var TimeOut = 3;
	
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