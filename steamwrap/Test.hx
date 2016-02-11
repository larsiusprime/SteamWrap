import steamwrap.SteamWrap;

class Test
{
	static function main()
	{
		trace("Start");

		SteamWrap.init(PUT STEAM APP ID HERE);
		SteamWrap.whenAchievementStored = steamWrap_onAchievementStored;
		SteamWrap.whenLeaderboardScoreDownloaded = steamWrap_onLeaderboardScoreDownloaded;

		var achs = ["YOUR", "ACHIEVEMENT", "IDS", "GO", "HERE"];

		for (ach in achs) SteamWrap.clearAchievement(ach);
		for (ach in achs) SteamWrap.setAchievement(ach);
		
		var leaderBoardIds = ["YOUR", "LEADERBOARD", "IDS", "GO", "HERE"];
		SteamWrap.registerLeaderboards(leaderboardIds);
		for (leaderboardId in leaderboardIds)
		{
			SteamWrap.downloadLeaderboardScore(leaderboardId); (o
		}
		
		var init = SteamWrap.initControllers();
		var controllers:Array<Int> = SteamWrap.getConnectedControllers();
		
		trace("controllers = " + controllers);
		
		var inGameControls = SteamWrap.getActionSetHandle("InGameControls");
		var menuControls = SteamWrap.getActionSetHandle("MenuControls");
		
		trace("===ACTION SET HANDLES===");
		trace("ingame = " + inGameControls + " menu = " + menuControls);
		
		var menu_up = SteamWrap.getDigitalActionHandle("menu_up");
		var menu_down = SteamWrap.getDigitalActionHandle("menu_down");
		var menu_left = SteamWrap.getDigitalActionHandle("menu_left");
		var menu_right = SteamWrap.getDigitalActionHandle("menu_right");
		var fire = SteamWrap.getDigitalActionHandle("fire");
		var jump = SteamWrap.getDigitalActionHandle("Jump");
		var pause_menu = SteamWrap.getDigitalActionHandle("pause_menu");
		var throttle = SteamWrap.getAnalogActionHandle("Throttle");
		var move = SteamWrap.getAnalogActionHandle("Move");
		var camera = SteamWrap.getAnalogActionHandle("Camera");
		
		trace("===DIGITAL ACTION HANDLES===");
		trace("menu up = " + menu_up + " down = " + menu_down + " left = " + menu_left + " right = " + menu_right);
		trace("fire = " + fire + " jump = " + jump);
		trace("pause_menu = " + pause_menu);
		
		var fireOrigins:Array<EControllerActionOrigin> = [];
		var fireOriginCount = SteamWrap.getDigitalActionOrigins(controllers[0], inGameControls, fire, fireOrigins);
		
		trace("===DIGITAL ACTION ORIGINS===");
		trace("fire: count = " + fireOriginCount + " origins = " + fireOrigins);
		
		for (origin in fireOrigins) {
			if (origin != NONE) {
				trace("glpyh = " + Std.string(origin).toLowerCase());
			}
		}
		
		trace("===ANALOG ACTION HANDLES===");
		trace("throttle = " + throttle + " move = " + move + " camera = " + camera);
		
		var moveOrigins:Array<EControllerActionOrigin> = [];
		var moveOriginCount = SteamWrap.getAnalogActionOrigins(controllers[0], inGameControls, move, moveOrigins);
		
		trace("===ANALOG ACTION ORIGINS===");
		trace("move: count = " + moveOriginCount + " origins = " + moveOrigins);
		
		for (origin in moveOrigins) {
			if (origin != NONE) {
				trace("glpyh = " + Std.string(origin).toLowerCase());
			}
		}
		
		while (true)
		{
			SteamWrap.onEnterFrame();
			Sys.sleep(0.1);
			SteamWrap.activateActionSet(controllers[0], inGameControls);
			var currentActionSet = SteamWrap.getCurrentActionSet(controllers[0]);
			trace("current action set = " + currentActionSet);
			
			var fireData = SteamWrap.getDigitalActionData(controllers[0], fire);
			trace("fireData: bState = " + fireData.bState + " bActive = " + fireData.bActive);
			
			var moveData = SteamWrap.getAnalogActionData(controllers[0], move);
			trace("moveData: eMode = " + moveData.eMode + " x/y = "+ moveData.x + "/" + moveData.y + " bActive = " + moveData.bActive);
		}
	}

	private static function steamWrap_onAchievementStored(id:String)
	{
		trace("Achievement stored: " + id);
	}

	private static function steamWrap_onLeaderboardScoreDownloaded(score:steamwrap.SteamWrap.LeaderboardScore)
	{
		trace("Leaderboard score downloaded: " + score.toString());
	}
}

