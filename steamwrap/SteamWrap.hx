package steamwrap;

private enum LeaderboardOp
{
	FIND(id:String);
	UPLOAD(score:LeaderboardScore);
	DOWNLOAD(id:String);
}

class SteamWrap
{
	public static var active(default,null):Bool = false;
	public static var wantQuit(default,null):Bool = false;

	public static var whenAchievementStored:String->Void;
	public static var whenLeaderboardScoreDownloaded:LeaderboardScore->Void;
	public static var whenLeaderboardScoreUploaded:LeaderboardScore->Void;
	public static var whenTrace:String->Void;

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
			SteamWrap_SetAchievement = cpp.Lib.load("steamwrap", "SteamWrap_SetAchievement", 1);
			SteamWrap_ClearAchievement = cpp.Lib.load("steamwrap", "SteamWrap_ClearAchievement", 1);
			SteamWrap_StoreStats = cpp.Lib.load("steamwrap", "SteamWrap_StoreStats", 0);
			SteamWrap_FindLeaderboard = cpp.Lib.load("steamwrap", "SteamWrap_FindLeaderboard", 1);
			SteamWrap_UploadScore = cpp.Lib.load("steamwrap", "SteamWrap_UploadScore", 3);
			SteamWrap_DownloadScores = cpp.Lib.load("steamwrap", "SteamWrap_DownloadScores", 3);
			SteamWrap_RequestGlobalStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestGlobalStats", 0);
			SteamWrap_GetGlobalStat = cpp.Lib.load("steamwrap", "SteamWrap_GetGlobalStat", 1);
			SteamWrap_RestartAppIfNecessary = cpp.Lib.load("steamwrap", "SteamWrap_RestartAppIfNecessary", 1);
			SteamWrap_IsSteamRunning = cpp.Lib.load("steamwrap", "SteamWrap_IsSteamRunning", 0);
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
	private static var SteamWrap_StoreStats:Dynamic;
	private static var SteamWrap_FindLeaderboard:Dynamic;
	private static var SteamWrap_UploadScore:String->Int->Int->Bool;
	private static var SteamWrap_DownloadScores:String->Int->Int->Bool;
	private static var SteamWrap_RequestGlobalStats:Dynamic;
	private static var SteamWrap_GetGlobalStat:Dynamic;
	private static var SteamWrap_RestartAppIfNecessary:Dynamic;
	private static var SteamWrap_IsSteamRunning:Dynamic;
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


