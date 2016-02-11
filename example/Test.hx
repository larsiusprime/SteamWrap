import steamwrap.API;
import steamwrap.ControllerAPI;

class Test
{
	static function main()
	{
		trace("Start");
		
		var appID:Int = -1;			//PUT YOUR APP ID HERE!
		
		if (appID == -1)
		{
			trace("You need to supply an app ID!");
			Sys.exit(0);
		}
		
		API.init(appID);
		API.whenAchievementStored = steamWrap_onAchievementStored;
		API.whenLeaderboardScoreDownloaded = steamWrap_onLeaderboardScoreDownloaded;

		var achs = [];				//PUT SOME ACHIEVEMENTS HERE: ["BEAT_LEVEL_1","BEAT_LEVEL_2"], etc.
		
		if (achs != null && achs.length > 0)
		{
			for (ach in achs) API.clearAchievement(ach);
			for (ach in achs) API.setAchievement(ach);
		}
		else
		{
			trace("You didn't define any achievements to test...");
		}
		
		//The controller code below assumes you have already read the Steam Docs
		//on controller support and set up the "default" test configuration, so that
		//you're testing locally with a game_actions_<YOURAPPID>.vdf file
		//
		//If you have no clue what this means, READ THE STEAM DOCS!
		//
		//It won't crash if you haven't, it just won't work
		
		var controllers:Array<Int> = API.controllers.getConnectedControllers();
		
		trace("controllers = " + controllers);
		
		var inGameControls = API.controllers.getActionSetHandle("InGameControls");
		var menuControls = API.controllers.getActionSetHandle("MenuControls");
		
		trace("===ACTION SET HANDLES===");
		trace("ingame = " + inGameControls + " menu = " + menuControls);
		
		var menu_up = API.controllers.getDigitalActionHandle("menu_up");
		var menu_down = API.controllers.getDigitalActionHandle("menu_down");
		var menu_left = API.controllers.getDigitalActionHandle("menu_left");
		var menu_right = API.controllers.getDigitalActionHandle("menu_right");
		var fire = API.controllers.getDigitalActionHandle("fire");
		var jump = API.controllers.getDigitalActionHandle("Jump");
		var pause_menu = API.controllers.getDigitalActionHandle("pause_menu");
		var throttle = API.controllers.getAnalogActionHandle("Throttle");
		var move = API.controllers.getAnalogActionHandle("Move");
		var camera = API.controllers.getAnalogActionHandle("Camera");
		
		trace("===DIGITAL ACTION HANDLES===");
		trace("menu up = " + menu_up + " down = " + menu_down + " left = " + menu_left + " right = " + menu_right);
		trace("fire = " + fire + " jump = " + jump);
		trace("pause_menu = " + pause_menu);
		
		if (controllers != null && controllers.length > 0)
		{
			var fireOrigins:Array<EControllerActionOrigin> = [];
			var fireOriginCount = API.controllers.getDigitalActionOrigins(controllers[0], inGameControls, fire, fireOrigins);
			
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
			var moveOriginCount = API.controllers.getAnalogActionOrigins(controllers[0], inGameControls, move, moveOrigins);
			
			trace("===ANALOG ACTION ORIGINS===");
			trace("move: count = " + moveOriginCount + " origins = " + moveOrigins);
			
			for (origin in moveOrigins) {
				if (origin != NONE) {
					trace("glpyh = " + Std.string(origin).toLowerCase());
				}
			}
		}
		
		while (true)
		{
			API.onEnterFrame();
			Sys.sleep(0.1);
			
			if (controllers != null && controllers.length > 0)
			{
				API.controllers.activateActionSet(controllers[0], inGameControls);
				var currentActionSet = API.controllers.getCurrentActionSet(controllers[0]);
				trace("current action set = " + currentActionSet);
				
				var fireData = API.controllers.getDigitalActionData(controllers[0], fire);
				trace("fireData: bState = " + fireData.bState + " bActive = " + fireData.bActive);
				
				var moveData = API.controllers.getAnalogActionData(controllers[0], move);
				trace("moveData: eMode = " + moveData.eMode + " x/y = " + moveData.x + "/" + moveData.y + " bActive = " + moveData.bActive);
			}
		}
	}

	private static function steamWrap_onAchievementStored(id:String)
	{
		trace("Achievement stored: " + id);
	}

	private static function steamWrap_onLeaderboardScoreDownloaded(score:steamwrap.API.LeaderboardScore)
	{
		trace("Leaderboard score downloaded: " + score.toString());
	}
}

