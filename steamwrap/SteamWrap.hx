package steamwrap;
import cpp.Lib;
import haxe.Int64;

private enum LeaderboardOp
{
	FIND(id:String);
	UPLOAD(score:LeaderboardScore);
	DOWNLOAD(id:String);
}

typedef ControllerHandle = Int64;
typedef ControllerActionSetHandle = Int;
typedef ControllerDigitalActionHandle = Int;
typedef ControllerAnalogActionHandle = Int;

class SteamWrap
{
	
	public static var active(default,null):Bool = false;
	public static var wantQuit(default,null):Bool = false;

	public static var whenAchievementStored:String->Void;
	public static var whenLeaderboardScoreDownloaded:LeaderboardScore->Void;
	public static var whenLeaderboardScoreUploaded:LeaderboardScore->Void;
	public static var whenTrace:String->Void;
	public static var whenUGCItemIdReceived:String->Void;
	public static var whenUGCItemUpdateComplete:Bool->String->Void;

	static var haveGlobalStats:Bool;
	static var haveReceivedUserStats:Bool;
	static var wantStoreStats:Bool;
	static var appId:Int;

	static var leaderboardIds:Array<String>;
	static var leaderboardOps:List<LeaderboardOp>;

	public static function init(appId_:Int)
	{
		#if cpp
		if (active) return;

		appId = appId_;
		leaderboardIds = new Array<String>();
		leaderboardOps = new List<LeaderboardOp>();

		try
		{
			SteamWrap_Init = cpp.Lib.load("steamwrap", "SteamWrap_Init", 1);
			SteamWrap_Shutdown = cpp.Lib.load("steamwrap", "SteamWrap_Shutdown", 0);
			SteamWrap_RunCallbacks = cpp.Lib.load("steamwrap", "SteamWrap_RunCallbacks", 0);
			SteamWrap_RequestStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestStats", 0);
			SteamWrap_GetStat = cpp.Lib.load("steamwrap", "SteamWrap_GetStat", 1);
			SteamWrap_SetStat = cpp.Lib.load("steamwrap", "SteamWrap_SetStat", 2);
			SteamWrap_ClearAchievement = cpp.Lib.load("steamwrap", "SteamWrap_ClearAchievement", 1);
			SteamWrap_SetAchievement = cpp.Lib.load("steamwrap", "SteamWrap_SetAchievement", 1);
			SteamWrap_IndicateAchievementProgress = cpp.Lib.load("steamwrap", "SteamWrap_IndicateAchievementProgress", 3);
			SteamWrap_StoreStats = cpp.Lib.load("steamwrap", "SteamWrap_StoreStats", 0);
			SteamWrap_FindLeaderboard = cpp.Lib.load("steamwrap", "SteamWrap_FindLeaderboard", 1);
			SteamWrap_UploadScore = cpp.Lib.load("steamwrap", "SteamWrap_UploadScore", 3);
			SteamWrap_DownloadScores = cpp.Lib.load("steamwrap", "SteamWrap_DownloadScores", 3);
			SteamWrap_RequestGlobalStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestGlobalStats", 0);
			SteamWrap_GetGlobalStat = cpp.Lib.load("steamwrap", "SteamWrap_GetGlobalStat", 1);
			SteamWrap_RestartAppIfNecessary = cpp.Lib.load("steamwrap", "SteamWrap_RestartAppIfNecessary", 1);
			SteamWrap_IsSteamRunning = cpp.Lib.load("steamwrap", "SteamWrap_IsSteamRunning", 0);
			SteamWrap_CreateUGCItem = cpp.Lib.load("steamwrap", "SteamWrap_CreateUGCItem", 1);
			SteamWrap_StartUpdateUGCItem = cpp.Lib.load("steamwrap", "SteamWrap_StartUpdateUGCItem", 2);
			SteamWrap_SetUGCItemTitle = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemTitle", 2);
			SteamWrap_SetUGCItemDescription = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemDescription", 2);
			SteamWrap_SetUGCItemVisibility = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemVisibility", 2);
			SteamWrap_SetUGCItemContent = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemContent", 2);
			SteamWrap_SetUGCItemPreviewImage = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemPreviewImage", 2);
			SteamWrap_SubmitUGCItemUpdate = cpp.Lib.load("steamwrap", "SteamWrap_SubmitUGCItemUpdate", 2);
			SteamWrap_GetCurrentGameLanguage = cpp.Lib.load("steamwrap", "SteamWrap_GetCurrentGameLanguage", 0);
			SteamWrap_OpenOverlay = cpp.Lib.load("steamwrap", "SteamWrap_OpenOverlay", 1);
			SteamWrap_InitControllers = cpp.Lib.load("steamwrap", "SteamWrap_InitControllers", 0);
			SteamWrap_ShutdownControllers = cpp.Lib.load("steamwrap", "SteamWrap_ShutdownControllers", 0);
			SteamWrap_GetConnectedControllers = cpp.Lib.load("steamwrap", "SteamWrap_GetConnectedControllers", 0);
			SteamWrap_GetDigitalActionOrigins = cpp.Lib.load("steamwrap", "SteamWrap_GetDigitalActionOrigins", 3);
			SteamWrap_GetAnalogActionOrigins = cpp.Lib.load("steamwrap", "SteamWrap_GetAnalogActionOrigins", 3);
		}
		catch (e:Dynamic)
		{
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}

		// if we get this far, the dlls loaded ok and we need Steam to init.
		// otherwise, we're trying to run the Steam version without the Steam client
		active = SteamWrap_Init(steamWrap_onEvent);

		if (active)
		{
			customTrace("Steam active");
			SteamWrap_RequestStats();
			SteamWrap_RequestGlobalStats();
		}
		else
		{
			customTrace("Steam failed to activate");
			// restart under Steam
			wantQuit = true;
		}
		
		#end
	}

	public static function shutdown()
	{
		if (!active) return;
		SteamWrap_Shutdown();
	}

	public static function startUpdateUGCItem(itemID:Int): String{
		return SteamWrap_StartUpdateUGCItem(appId, itemID);
	}

	public static function submitUGCItemUpdate(updateHandle:String, changeNotes:String):Bool {
		return SteamWrap_SubmitUGCItemUpdate(updateHandle, changeNotes);
	}

	public static function setUGCItemTitle(updateHandle:String, itemTitle:String):Bool {
		return SteamWrap_SetUGCItemTitle(updateHandle, itemTitle.substr(0, 128));
	}

	public static function setUGCItemDescription(updateHandle:String, itemDesc:String):Bool {
		return SteamWrap_SetUGCItemDescription(updateHandle, itemDesc.substr(0, 8000));
	}

	public static function setUGCItemVisibility(updateHandle:String, visibility:Int):Bool {
		/*
		* 	https://partner.steamgames.com/documentation/ugc
		*	0 : Public
		*	1 : Friends Only
		*	2 : Private
		*/
		return SteamWrap_SetUGCItemVisibility(updateHandle, visibility);
	}

	public static function setUGCItemContent(updateHandle:String, absPath:String):Bool {
		return SteamWrap_SetUGCItemContent(updateHandle, absPath);
	}

	public static function setUGCItemPreviewImage(updateHandle:String, absPath:String):Bool {
		return SteamWrap_SetUGCItemPreviewImage(updateHandle, absPath);
	}

	public static function createUGCItem(){
		SteamWrap_CreateUGCItem(appId);
	}

	public static function openOverlay(url:String){
		SteamWrap_OpenOverlay(url);
	}

	public static function isSteamRunning()
	{
		return SteamWrap_IsSteamRunning();
	}

	public static function restartAppInSteam()
	{
		return SteamWrap_RestartAppIfNecessary(appId);
	}

	private static inline function customTrace(str:String)
	{
		if (whenTrace != null)
			whenTrace(str);
		else
			trace(str);
	}

	private static inline function report(func:String, params:Array<String>, result:Bool):Bool
	{
		var str = "[STEAM] " + func + "(" + params.join(",") + ") " + (result ? " SUCCEEDED" : " FAILED");
		customTrace(str);
		return result;
	}

	public static function setAchievement(id:String):Bool
	{
		return active && report("setAchievement", [id], SteamWrap_SetAchievement(id));
	}

	public static function clearAchievement(id:String):Bool
	{
		return active && report("clearAchievement", [id], SteamWrap_ClearAchievement(id));
	}

	public static function indicateAchievementProgress(id:String, curProgress:Int, maxProgress:Int):Bool
	{
		return active && report("indicateAchivevementProgress", [id, Std.string(curProgress), Std.string(maxProgress)], SteamWrap_IndicateAchievementProgress(id, curProgress, maxProgress));
	}

	// Kinda awkwardly returns 0 on errors and uses 0 for checking success
	public static function getStat(id:String):Int
	{
		if (!active)
			return 0;
		var val = SteamWrap_GetStat(id);
		report("getStat", [id], val != 0);
		return val;
	}

	public static function setStat(id:String, val:Int):Bool
	{
		return active && report("setStat", [id, Std.string(val)], SteamWrap_SetStat(id, val));
	}

	public static function storeStats():Bool
	{
		return active && report("storeStats", [], SteamWrap_StoreStats());
	}

	private static function findLeaderboardIfNecessary(id:String)
	{
		if (!Lambda.has(leaderboardIds, id) && !Lambda.exists(leaderboardOps, function(op) { return Type.enumEq(op, FIND(id)); }))
		{
			leaderboardOps.add(LeaderboardOp.FIND(id));
		}
	}

	public static function uploadLeaderboardScore(score:LeaderboardScore):Bool
	{
		if (!active) return false;
		var startProcessingNow = (leaderboardOps.length == 0);
		findLeaderboardIfNecessary(score.leaderboardId);
		leaderboardOps.add(LeaderboardOp.UPLOAD(score));
		if (startProcessingNow) processNextLeaderboardOp();
		return true;
	}

	public static function downloadLeaderboardScore(id:String):Bool
	{
		if (!active) return false;
		var startProcessingNow = (leaderboardOps.length == 0);
		findLeaderboardIfNecessary(id);
		leaderboardOps.add(LeaderboardOp.DOWNLOAD(id));
		if (startProcessingNow) processNextLeaderboardOp();
		return true;
	}

	private static function processNextLeaderboardOp()
	{
		var op = leaderboardOps.pop();
		if (op == null) return;

		switch (op)
		{
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

	public static function getCurrentGameLanguage() {
		return SteamWrap_GetCurrentGameLanguage();
	}
	
	public static function initControllers() {
		return SteamWrap_InitControllers();
	}

	public static function shutdownControllers() {
		return SteamWrap_ShutdownControllers();
	}

	/**
	 * Returns an array of integer handles for polling controller data
	 * 
	 * NOTE: the native steam controller handles are uint64's and too large to easily pass to Haxe,
	 * so the "true" values are left on the C++ side and haxe only deals with 0-based integer indeces
	 * that map back to the "true" values on the C++ side
	 * @return
	 */
	public static function getConnectedControllers():Array<Int> {
		var str:String = SteamWrap_GetConnectedControllers();
		var arrStr:Array<String> = str.split(",");
		var intStr = [];
		for (astr in arrStr) {
			intStr.push(Std.parseInt(astr));
		}
		return intStr;
	}
	
	/**
	 * Get the integer handle for a Steam Controller action set
	 * 
	 * NOTE: per the Steam API documentation, you must first define a game_actions_X.vdf file
	 * and configure that properly for any action sets to be recognized
	 * 
	 * @param	actionSetName
	 * @return
	 */
	public static function getActionSetHandle(actionSetName:String):Int {
		return SteamWrap_GetActionSetHandle.call(actionSetName);
	}
	
	/**
	 * Get the integer handle of a digital (on/off) action
	 * 
	 * @param	actionName
	 * @return
	 */
	public static function getDigitalActionHandle(actionName:String):Int {
		return SteamWrap_GetDigitalActionHandle.call(actionName);
	}
	
	/**
	 * Get the analog handle of an analog (continuous value) action
	 * 
	 * @param	actionName
	 * @return
	 */
	public static function getAnalogActionHandle(actionName:String):Int {
		return SteamWrap_GetAnalogActionHandle.call(actionName);
	}
	
	/**
	 * Returns the current state of the supplied digital game action
	 * 
	 * @param	controller	integer handle for the controller you want to check
	 * @param	action	integer handle for the action you want to check
	 * @return
	 */
	public static function getDigitalActionData(controller:Int, action:Int):ControllerDigitalActionData {
		return new ControllerDigitalActionData(SteamWrap_GetDigitalActionData.call(controller, action));
	}
	
	/**
	 * Returns the current state of these supplied analog game action
	 * 
	 * @param	controller	integer handle for the controller you want to check
	 * @param	action	integer handle for the action you want to check
	 * @param	data	an existing ControllerAnalogActionData structure you want to fill (optional) 
	 * @return
	 */
	public static function getAnalogActionData(controller:Int, action:Int, ?data:ControllerAnalogActionData):ControllerAnalogActionData {
		if (data == null)
		{
			data = new ControllerAnalogActionData();
		}
		
		data.bActive = SteamWrap_GetAnalogActionData.call(controller, action);
		data.eMode = cast SteamWrap_GetAnalogActionData_eMode.call(0);
		data.x = SteamWrap_GetAnalogActionData_x.call(0);
		data.y = SteamWrap_GetAnalogActionData_y.call(0);
		
		return data;
	}
	
	/**
	 * Get the origin(s) for a digital action with an action set. Use this to display the appropriate on-screen prompt for the action.
	 * 
	 * @param	controller	integer handle for a controller
	 * @param	actionSet	integer handle for an action set
	 * @param	action	integer handle for a digital action
	 * @param	originsOut	array to fill with EControllerActionOrigin values
	 * @return the number of origins supplied in originsOut.
	 */
	
	public static function getDigitalActionOrigins(controller:Int, actionSet:Int, action:Int, originsOut:Array<EControllerActionOrigin>):Int {
		
		var str:String = SteamWrap_GetDigitalActionOrigins(controller, actionSet, action);
		var strArr:Array<String> = str.split(",");
		
		var result = 0;
		
		//result is the first value in the array
		if(strArr != null && strArr.length > 0){
			result = Std.parseInt(strArr[0]);
		}
		
		if (strArr.length > 1 && originsOut != null) {
			for (i in 1...strArr.length) {
				originsOut[i] = strArr[i];
			}
		}
		
		return result;
	}
	
	/**
	 * Get the origin(s) for an analog action with an action set. Use this to display the appropriate on-screen prompt for the action.
	 * 
	 * @param	controller	integer handle for a controller
	 * @param	actionSet	integer handle for an action set
	 * @param	action	integer handle for an analog action
	 * @param	originsOut	array to fill with EControllerActionOrigin values
	 * @return the number of origins supplied in originsOut.
	 */
	
	public static function getAnalogActionOrigins(controller:Int, actionSet:Int, action:Int, originsOut:Array<EControllerActionOrigin>):Int {
		
		var str:String = SteamWrap_GetAnalogActionOrigins(controller, actionSet, action);
		var strArr:Array<String> = str.split(",");
		
		var result = 0;
		
		//result is the first value in the array
		if(strArr != null && strArr.length > 0){
			result = Std.parseInt(strArr[0]);
		}
		
		if (strArr.length > 1 && originsOut != null) {
			for (i in 1...strArr.length) {
				originsOut[i] = strArr[i];
			}
		}
		
		return result;
	}
	
	/**
	 * Activate an action set (only actions belonging to this set will fire from the controller)
	 * 
	 * @param	controller	integer handle for the controller you want to check
	 * @param	actionSet	integer handle for the action set you want activate
	 */
	public static function activateActionSet(controller:Int, actionSet:Int) {
		return SteamWrap_ActivateActionSet.call(controller, actionSet);
	}
	
	/**
	 * Get the integer handle of the currently active action set
	 * 
	 * @param	controllerHandle integer handle for the controller you want to check
	 * @return	integer handle of the currently active action set
	 */
	public static function getCurrentActionSet(controllerHandle:Int):Int {
		return SteamWrap_GetCurrentActionSet.call(controllerHandle);
	}
	
	public static function onEnterFrame()
	{
		if (!active) return;
		SteamWrap_RunCallbacks();

		if (wantStoreStats)
		{
			wantStoreStats = false;
			SteamWrap_StoreStats();
		}
	}

	private static function steamWrap_onEvent(e:Dynamic)
	{
		var type:String = Std.string(Reflect.field(e, "type"));
		var success:Bool = (Std.int(Reflect.field(e, "success")) != 0);
		var data:String = Std.string(Reflect.field(e, "data"));

		customTrace("[STEAM] " + type + (success ? " SUCCESS" : " FAIL") + " (" + data + ")");

		switch (type)
		{
			case "UserStatsReceived":
				haveReceivedUserStats = success;

			case "UserStatsStored":
				// retry next frame if failed
				wantStoreStats = !success;

			case "UserAchievementStored":
				if (whenAchievementStored != null) whenAchievementStored(data);

			case "GlobalStatsReceived":
				haveGlobalStats = success;

			case "LeaderboardFound":
				if (success)
				{
					leaderboardIds.push(data);
				}
				processNextLeaderboardOp();
			case "ScoreDownloaded":
				if (success)
				{
					var scores = data.split(";");
					for (score in scores)
					{
						var score = LeaderboardScore.fromString(data);
						if (score != null && whenLeaderboardScoreDownloaded != null) whenLeaderboardScoreDownloaded(score);
					}
				}
				processNextLeaderboardOp();
			case "ScoreUploaded":
				if (success)
				{
					var score = LeaderboardScore.fromString(data);
					if (score != null && whenLeaderboardScoreUploaded != null) whenLeaderboardScoreUploaded(score);
				}
				processNextLeaderboardOp();
			case "UGCItemCreated":
				if (success && whenUGCItemIdReceived != null){
					whenUGCItemIdReceived(data);
				}
			case "UGCItemUpdateSubmitted":
				if (whenUGCItemUpdateComplete != null){
					whenUGCItemUpdateComplete(success, data);
				}
			case "UGCLegalAgreementStatus":
		}
	}

	private static var SteamWrap_Init:Dynamic;
	private static var SteamWrap_Shutdown:Dynamic;
	private static var SteamWrap_RunCallbacks:Dynamic;
	private static var SteamWrap_RequestStats:Dynamic;
	private static var SteamWrap_GetStat:Dynamic;
	private static var SteamWrap_SetStat:Dynamic;
	private static var SteamWrap_SetAchievement:Dynamic;
	private static var SteamWrap_ClearAchievement:Dynamic;
	private static var SteamWrap_IndicateAchievementProgress:Dynamic;
	private static var SteamWrap_StoreStats:Dynamic;
	private static var SteamWrap_FindLeaderboard:Dynamic;
	private static var SteamWrap_UploadScore:String->Int->Int->Bool;
	private static var SteamWrap_DownloadScores:String->Int->Int->Bool;
	private static var SteamWrap_RequestGlobalStats:Dynamic;
	private static var SteamWrap_GetGlobalStat:Dynamic;
	private static var SteamWrap_RestartAppIfNecessary:Dynamic;
	private static var SteamWrap_IsSteamRunning:Dynamic;
	private static var SteamWrap_CreateUGCItem:Dynamic;
	private static var SteamWrap_StartUpdateUGCItem:Dynamic;
	private static var SteamWrap_SetUGCItemTitle:Dynamic;
	private static var SteamWrap_SetUGCItemDescription:Dynamic;
	private static var SteamWrap_SetUGCItemVisibility:Dynamic;
	private static var SteamWrap_SetUGCItemContent:Dynamic;
	private static var SteamWrap_SetUGCItemPreviewImage:Dynamic;
	private static var SteamWrap_SubmitUGCItemUpdate:Dynamic;
	private static var SteamWrap_GetCurrentGameLanguage:Dynamic;
	private static var SteamWrap_OpenOverlay:Dynamic;
	
	private static var SteamWrap_InitControllers:Dynamic;
	private static var SteamWrap_ShutdownControllers:Dynamic;
	private static var SteamWrap_GetConnectedControllers:Dynamic;
	private static var SteamWrap_GetDigitalActionOrigins:Dynamic;
	private static var SteamWrap_GetAnalogActionOrigins:Dynamic;
	
	private static var SteamWrap_GetActionSetHandle      = Loader.load("SteamWrap_GetActionSetHandle","ci");
	private static var SteamWrap_GetDigitalActionHandle  = Loader.load("SteamWrap_GetDigitalActionHandle","ci");
	private static var SteamWrap_GetAnalogActionHandle   = Loader.load("SteamWrap_GetAnalogActionHandle","ci");
	private static var SteamWrap_ActivateActionSet       = Loader.load("SteamWrap_ActivateActionSet","iii");
	private static var SteamWrap_GetCurrentActionSet     = Loader.load("SteamWrap_GetCurrentActionSet","ii");
	private static var SteamWrap_GetDigitalActionData    = Loader.load("SteamWrap_GetDigitalActionData", "iii");
	private static var SteamWrap_GetAnalogActionData     = Loader.load("SteamWrap_GetAnalogActionData", "iii");
		private static var SteamWrap_GetAnalogActionData_eMode = Loader.load("SteamWrap_GetAnalogActionData_eMode", "ii");
		private static var SteamWrap_GetAnalogActionData_x     = Loader.load("SteamWrap_GetAnalogActionData_x", "if");
		private static var SteamWrap_GetAnalogActionData_y     = Loader.load("SteamWrap_GetAnalogActionData_y", "if");
	
	
	
}

class LeaderboardScore
{
	public var leaderboardId:String;
	public var score:Int;
	public var detail:Int;
	public var rank:Int;

	public function new(leaderboardId_:String, score_:Int, detail_:Int, rank_:Int=-1)
	{
		leaderboardId = leaderboardId_;
		score = score_;
		detail = detail_;
		rank = rank_;
	}

	public function toString():String
	{
		return leaderboardId  + "," + score + "," + detail + "," + rank;
	}

	public static function fromString(str:String):LeaderboardScore
	{
		var tokens = str.split(",");
		if (tokens.length == 4)
			return new LeaderboardScore(tokens[0], Std.parseInt(tokens[1]), Std.parseInt(tokens[2]), Std.parseInt(tokens[3]));
		else
			return null;
	}
}

abstract ControllerDigitalActionData(Int) from Int to Int{
	
	public function new(i:Int) {
		this = i;
	}
	
	public var bState(get, never):Bool;
	private function get_bState():Bool{return this & 0x1 == 0x1;}
	
	public var bActive(get, never):Bool;
	private function get_bActive():Bool{return this & 0x10 == 0x10;}
}

class ControllerAnalogActionData
{
	public var eMode:EControllerSourceMode;
	public var x:Float;
	public var y:Float;
	public var bActive:Int;
	
	public function new()
	{
		//
	}
}

@:enum abstract ESteamControllerPad(Int) {
	public var Left = 0;
	public var Right = 1;
}

@:enum abstract EControllerSource(Int) {
	public var None = 0;
	public var LeftTrackpad = 1;
	public var RightTrackpad = 2;
	public var Joystick = 3;
	public var ABXY = 4;
	public var Switch = 5;
	public var LeftTrigger = 6;
	public var RightTrigger = 7;
	public var Gyro = 8;
	public var Count = 9;
}

@:enum abstract EControllerSourceMode(Int) {
	public var None = 0;
	public var Dpad = 1;
	public var Buttons = 2;
	public var FourButtons = 3;
	public var AbsoluteMouse = 4;
	public var RelativeMouse = 5;
	public var JoystickMove = 6;
	public var JoystickCamera = 7;
	public var ScrollWheel = 8;
	public var Trigger = 9;
	public var TouchMenu = 10;
	public var MouseJoystick = 11;
	public var MouseRegion = 12;
}

@:enum abstract EControllerActionOrigin(Int) {
	
	public static var fromStringMap(default, null):Map<String, EControllerActionOrigin>
		= MacroHelper.buildMap("steamwrap.EControllerActionOrigin");
	
	public static var toStringMap(default, null):Map<EControllerActionOrigin, String>
		= MacroHelper.buildMap("steamwrap.EControllerActionOrigin", true);
		
	public var NONE = 0;
	public var A = 1;
	public var B = 2;
	public var X = 3;
	public var Y = 4;
	public var LEFTBUMPER= 5;
	public var RIGHTBUMPER= 6;
	public var LEFTGRIP = 7;
	public var RIGHTGRIP = 8;
	public var START = 9;
	public var BACK = 10;
	public var LEFTPAD_TOUCH = 11;
	public var LEFTPAD_SWIPE = 12;
	public var LEFTPAD_CLICK = 13;
	public var LEFTPAD_DPADNORTH = 14;
	public var LEFTPAD_DPADSOUTH = 15;
	public var LEFTPAD_DPADWEST = 16;
	public var LEFTPAD_DPADEAST = 17;
	public var RIGHTPAD_TOUCH = 18;
	public var RIGHTPAD_SWIPE = 19;
	public var RIGHTPAD_CLICK = 20;
	public var RIGHTPAD_DPADNORTH = 21;
	public var RIGHTPAD_DPADSOUTH = 22;
	public var RIGHTPAD_DPADWEST = 23;
	public var RIGHTPAD_DPADEAST = 24;
	public var LEFTTRIGGER_PULL = 25;
	public var LEFTTRIGGER_CLICK = 26;
	public var RIGHTTRIGGER_PULL = 27;
	public var RIGHTTRIGGER_CLICK = 28;
	public var LEFTSTICK_MOVE = 29;
	public var LEFTSTICK_CLICK = 30;
	public var LEFTSTICK_DPADNORTH = 31;
	public var LEFTSTICK_DPADSOUTH = 32;
	public var LEFTSTICK_DPADWEST = 33;
	public var LEFTSTICK_DPADEAST = 34;
	public var GRYRO_MOVE = 35;
	public var GRYRO_PITCH = 36;
	public var GRYRO_YAW = 37;
	public var GRYRO_ROLL = 38;
	public var COUNT = 39;
	
	@:from private static function fromString (s:String):EControllerActionOrigin{
		
		var i = Std.parseInt(s);
		
		if (i == null) {
			
			//if it's not a numeric value, try to interpret it from its name
			s = s.toUpperCase();
			return fromStringMap.exists(s) ? fromStringMap.get(s) : NONE;
		}
		
		return cast Std.int(i);
		
	}
	
	@:to public inline function toString():String
	{
		return toStringMap.get(cast this);
	}
	
}