import steamwrap.api.Steam;
import steamwrap.api.Controller;

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
		
		Steam.init(appID);
		Steam.whenAchievementStored = steamWrap_onAchievementStored;
		Steam.whenLeaderboardScoreDownloaded = steamWrap_onLeaderboardScoreDownloaded;

		var achs = [];				//PUT SOME ACHIEVEMENTS HERE: ["BEAT_LEVEL_1","BEAT_LEVEL_2"], etc.
		
		if (achs != null && achs.length > 0)
		{
			for (ach in achs) Steam.clearAchievement(ach);
			for (ach in achs) Steam.setAchievement(ach);
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
		
		var controllers:Array<Int> = Steam.controllers.getConnectedControllers();
		
		trace("controllers = " + controllers);
		
		var inGameControls = Steam.controllers.getActionSetHandle("InGameControls");
		var menuControls = Steam.controllers.getActionSetHandle("MenuControls");
		
		trace("===ACTION SET HANDLES===");
		trace("ingame = " + inGameControls + " menu = " + menuControls);
		
		var menu_up = Steam.controllers.getDigitalActionHandle("menu_up");
		var menu_down = Steam.controllers.getDigitalActionHandle("menu_down");
		var menu_left = Steam.controllers.getDigitalActionHandle("menu_left");
		var menu_right = Steam.controllers.getDigitalActionHandle("menu_right");
		var fire = Steam.controllers.getDigitalActionHandle("fire");
		var jump = Steam.controllers.getDigitalActionHandle("Jump");
		var pause_menu = Steam.controllers.getDigitalActionHandle("pause_menu");
		var throttle = Steam.controllers.getAnalogActionHandle("Throttle");
		var move = Steam.controllers.getAnalogActionHandle("Move");
		var camera = Steam.controllers.getAnalogActionHandle("Camera");
		
		trace("===DIGITAL ACTION HANDLES===");
		trace("menu up = " + menu_up + " down = " + menu_down + " left = " + menu_left + " right = " + menu_right);
		trace("fire = " + fire + " jump = " + jump);
		trace("pause_menu = " + pause_menu);
		
		if (controllers != null && controllers.length > 0)
		{
			var fireOrigins:Array<EControllerActionOrigin> = [];
			var fireOriginCount = Steam.controllers.getDigitalActionOrigins(controllers[0], inGameControls, fire, fireOrigins);
			
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
			var moveOriginCount = Steam.controllers.getAnalogActionOrigins(controllers[0], inGameControls, move, moveOrigins);
			
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
			Steam.onEnterFrame();
			Sys.sleep(0.1);
			
			if (controllers != null && controllers.length > 0)
			{
				Steam.controllers.activateActionSet(controllers[0], inGameControls);
				var currentActionSet = Steam.controllers.getCurrentActionSet(controllers[0]);
				trace("current action set = " + currentActionSet);
				
				var fireData = Steam.controllers.getDigitalActionData(controllers[0], fire);
				trace("fireData: bState = " + fireData.bState + " bActive = " + fireData.bActive);
				
				var moveData = Steam.controllers.getAnalogActionData(controllers[0], move);
				trace("moveData: eMode = " + moveData.eMode + " x/y = " + moveData.x + "/" + moveData.y + " bActive = " + moveData.bActive);
			}
		}
	}

	private static function steamWrap_onAchievementStored(id:String)
	{
		trace("Achievement stored: " + id);
	}

	private static function steamWrap_onLeaderboardScoreDownloaded(score:Array<steamwrap.api.Steam.LeaderboardScore>)
	{
		trace("Leaderboard score downloaded: " + score.toString());
	}
}
