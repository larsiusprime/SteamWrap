package steamwrap.api;
import cpp.Lib;
import steamwrap.api.Steam;
import steamwrap.helpers.Loader;
import steamwrap.helpers.MacroHelper;

/**
 * The Workshop API. Used by API.hx, should never be created manually by the user.
 * API.hx creates and initializes this by default.
 * Access it via API.workshop static variable
 */

@:allow(steamwrap.api.Steam)
class Workshop
{
	/*************PUBLIC***************/
	
	/**
	 * Whether the Workshop API is initialized or not. If false, all calls will fail.
	 */
	public var active(default, null):Bool = false;
	
	//TODO: these all need documentation headers
	
	/**
	 * Asynchronously enumerates files that the user has shared via Steam Workshop (will return data via the whenUserSharedWorkshopFilesEnumerated callback)
	 * @param	steamID	the steam user ID
	 * @param	startIndex	which index to start enumerating from
	 * @param	requiredTags	comma-separated list of tags that returned entries MUST have
	 * @param	excludedTags	comma-separated list of tags that returned entries MUST NOT have
	 * @return	whether the call succeeded or not
	 */
	public function enumerateUserSharedWorkshopFiles(steamID:String, startIndex:Int, requiredTags:String, excludedTags:String):Void{
		SteamWrap_EnumerateUserSharedWorkshopFiles.call(steamID, startIndex, requiredTags, excludedTags);
	}
	
	/**
	 * Asynchronously enumerates Steam Workshop files that the user has subscribed to (will return data via the whenUserSubscribedFilesEnumerated callback)
	 * @param	startIndex	which index to start enumerating from
	 * @return	whether the call succeeded or not
	 */
	public function enumerateUserSubscribedFiles(startIndex:Int):Void{
		SteamWrap_EnumerateUserSubscribedFiles.call(startIndex);
	}
	
	/**
	 * Asynchronously enumerates files that the user has published to Steam Workshop (will return data via the whenUserPublishedFilesEnumerated callback)
	 * @param	startIndex	which index to start enumerating from
	 * @return	whether the call succeeded or not
	 */
	public function enumerateUserPublishedFiles(startIndex:Int):Void{
		SteamWrap_EnumerateUserPublishedFiles.call(startIndex);
	}
	
	/**
	 * Downloads a UGC file.  A priority value of 0 will download the file immediately,
	 * otherwise it will wait to download the file until all downloads with a lower priority
	 * value are completed.  Downloads with equal priority will occur simultaneously.
	 * @param	handle
	 * @param	priority
	 */
	public function ugcDownload(handle:String, priority:Int):Void{
		SteamWrap_UGCDownload(handle, priority);
	}
	
	/*************PRIVATE***************/
	
	private var customTrace:String->Void;
	private var appId:Int;
	
	//Old-school CFFI calls:
	
	//CFFI PRIME calls:
	//private var SteamWrap_EnumeratePublishedWorkshopFiles  = Loader.load("SteamWrap_EnumeratePublishedWorkshopFiles" , "iiiicci");
	private var SteamWrap_EnumerateUserSharedWorkshopFiles = Loader.load("SteamWrap_EnumerateUserSharedWorkshopFiles", "ciccv");
	private var SteamWrap_EnumerateUserSubscribedFiles     = Loader.load("SteamWrap_EnumerateUserSubscribedFiles"    , "iv");
	private var SteamWrap_EnumerateUserPublishedFiles      = Loader.load("SteamWrap_EnumerateUserPublishedFiles"     , "iv");
	private var SteamWrap_UGCDownload                      = Loader.load("SteamWrap_UGCDownload" , "civ");
	
	private function new(appId_:Int, CustomTrace:String->Void) {
		#if sys		//TODO: figure out what targets this will & won't work with and upate this guard
		
		if (active) return;
		
		appId = appId_;
		customTrace = CustomTrace;
		
		try {
			//Old-school CFFI calls:
		}
		catch (e:Dynamic) {
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}
		
		// if we get this far, the dlls loaded ok and we need Steam controllers to init.
		// otherwise, we're trying to run the Steam version without the Steam client
		active = true;//SteamWrap_InitControllers();
		
		#end
	}
}