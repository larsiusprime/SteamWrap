import steamwrap.SteamWrap;

class Test
{
    static function main()
    {
    	trace("Start");

    	SteamWrap.init(PUT STEAM APP ID HERE);
    	SteamWrap.whenAchievementStored = steamWrap_onAchievementStored;
        SteamWrap.whenLeaderboardScoreDownloaded = steamWrap_onLeaderboardScoreDownloaded;

    	//var achs = [ "ACH_TOKEN_ANTEGRIA", "ACH_TOKEN_REPUBLIA", "ACH_TOKEN_IMPOR", "ACH_TOKEN_OBRISTAN" ];
    	//for (ach in achs) SteamWrap.clearAchievement(ach);
    	//for (ach in achs) SteamWrap.setAchievement(ach);
    	var leaderboardIds = [ "LB_ENDLESS_C1_TL", "LB_ENDLESS_C1_EN", "LB_ENDLESS_C1_PR" ];
    	//SteamWrap.registerLeaderboards(leaderboardIds);
        for (leaderboardId in leaderboardIds)
            SteamWrap.downloadLeaderboardScore(leaderboardId);

    	while (true)
    	{
    		SteamWrap.onEnterFrame();
    		Sys.sleep(0.1);
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

