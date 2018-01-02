package steamwrap.api;
import cpp.Lib;
import haxe.io.Bytes;
import haxe.io.BytesData;
import steamwrap.api.Steam;
import steamwrap.helpers.Loader;
import steamwrap.helpers.MacroHelper;

/**
 * The Steam Cloud API. Used by API.hx, should never be created manually by the user.
 * API.hx creates and initializes this by default.
 * Access it via API.ugcstatic variable
 */

@:allow(steamwrap.api.Steam)
class Cloud
{
	/*************PUBLIC***************/
	
	/**
	 * Whether the Cloud API is initialized or not. If false, all calls will fail.
	 */
	public var active(default, null):Bool = false;
	
	//TODO: these all need documentation headers
	
	public function GetFileCount():Int {
		if (!active) return 0;
		return SteamWrap_GetFileCount.call(0);
	}
	
	public function FileExists(name:String):Bool {
		if (!active) return false;
		return SteamWrap_FileExists.call(name) == 1;
	}
	
	public function GetFileSize(name:String):Int {
		if (!active) return 0;
		return SteamWrap_GetFileSize.call(name);
	}
	
	public function GetQuota():{total:Int, available:Int}
	{
		if (!active) return {total:0, available:0};
		var str:String = SteamWrap_GetQuota();
		var arr = str.split(",");
		if (arr != null && arr.length == 2)
		{
			var total = Std.parseInt(arr[0]);
			if (total == null) total = 0;
			var available = Std.parseInt(arr[1]);
			if (available == null) available = 0;
			return {total:total, available:available};
		}
		return {total:0, available:0};
	}
	
	public function FileRead(name:String):String
	{
		if (!active) return null;
		if (!FileExists(name))
		{
			return null;
		}
		var fileData:String = SteamWrap_FileRead(name);
		return fileData;
	}
	
	public function FileShare(name:String) {
		if (!active) return;
		SteamWrap_FileShare.call(name);
	}
	
	public function FileWrite(name:String, data:Bytes):Void
	{
		if (!active) return;
		SteamWrap_FileWrite(name, data);
	}
	
	public function FileDelete(name:String):Bool {
		if (!active) return false;
		return SteamWrap_FileDelete.call(name) == 1;
	}
	
	public function IsCloudEnabledForApp():Bool {
		if (!active) return false;
		return SteamWrap_IsCloudEnabledForApp.call(0) == 1;
	}
	
	public function SetCloudEnabledForApp(b:Bool):Void {
		var i = b ? 1 : 0;
		if (!active) return;
		SteamWrap_SetCloudEnabledForApp.call(i);
	}
	
	/*************PRIVATE***************/
	
	private var customTrace:String->Void;
	private var appId:Int;
	
	//Old-school CFFI calls:
	private var SteamWrap_FileRead:Dynamic;
	private var SteamWrap_FileWrite:Dynamic;
	private var SteamWrap_GetQuota:Dynamic;
	
	//CFFI PRIME calls:
	private var SteamWrap_GetFileCount     = Loader.load("SteamWrap_GetFileCount", "ii");
	private var SteamWrap_FileExists    = Loader.load("SteamWrap_FileExists", "ci");
	private var SteamWrap_FileDelete    = Loader.load("SteamWrap_FileDelete", "ci");
	private var SteamWrap_GetFileSize      = Loader.load("SteamWrap_GetFileSize", "ci");
	private var SteamWrap_FileShare     = Loader.load("SteamWrap_FileShare", "cv");
	private var SteamWrap_IsCloudEnabledForApp   = Loader.load("SteamWrap_IsCloudEnabledForApp", "ii");
	private var SteamWrap_SetCloudEnabledForApp  = Loader.load("SteamWrap_SetCloudEnabledForApp", "iv");
	
	private function new(appId_:Int, CustomTrace:String->Void) {
		#if sys		//TODO: figure out what targets this will & won't work with and upate this guard
		
		if (active) return;
		
		appId = appId_;
		customTrace = CustomTrace;
		
		try {
			//Old-school CFFI calls:
			SteamWrap_FileRead  = cpp.Lib.load("steamwrap", "SteamWrap_FileRead", 1);
			SteamWrap_FileWrite = cpp.Lib.load("steamwrap", "SteamWrap_FileWrite", 2);
			SteamWrap_GetQuota = cpp.Lib.load("steamwrap", "SteamWrap_GetQuota", 0);
		}
		catch (e:Dynamic) {
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}
		
		active = true;
		
		#end
	}
}