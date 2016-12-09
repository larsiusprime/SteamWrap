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
		return SteamWrap_GetFileCount(0);
	}
	
	public function GetFileExists(name:String):Bool {
		return SteamWrap_GetFileExists(name) == 1;
	}
	
	public function GetFileSize(name:String):Int {
		return SteamWrap_GetFileSize(name);
	}
	
	public function FileRead(name:String):Bytes {
		if !(GetFileExists(name))
		{
			return null;
		}
		var length = GetFileSize(name);
		var bytesData:BytesData = SteamWrap_FileRead(name);
		return new Bytes(length, bytesData);
	}
	
	public function FileShare(name:String) {
		return SteamWrap_FileShare(name);
	}
	
	public function FileWrite(name:String, data:Bytes):Void {
		SteamWrap_FileWrite(name, data, data.length);
	}
	
	/*************PRIVATE***************/
	
	private var customTrace:String->Void;
	private var appId:Int;
	
	//Old-school CFFI calls:
	private var SteamWrap_FileRead:Dynamic;
	private var SteamWrap_FileWrite:Dynamic;
	
	//CFFI PRIME calls:
	private var SteamWrap_GetFileCount     = Loader.load("SteamWrap_GetFileCount", "ii");
	private var SteamWrap_GetFileExists    = Loader.load("SteamWrap_GetFileSize", "ci");
	private var SteamWrap_GetFileSize      = Loader.load("SteamWrap_GetFileSize", "ci");
	private var SteamWrap_GetFileShare     = Loader.load("SteamWrap_GetFileShare", "ci");
	
	private function new(appId_:Int, CustomTrace:String->Void) {
		#if sys		//TODO: figure out what targets this will & won't work with and upate this guard
		
		if (active) return;
		
		appId = appId_;
		customTrace = CustomTrace;
		
		try {
			//Old-school CFFI calls:
			SteamWrap_FileRead  = cpp.Lib.load("steamwrap", "FileRead", 1);
			SteamWrap_FileWrite = cpp.Lib.load("steamwrap", "FileWrite", 2);
		}
		catch (e:Dynamic) {
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}
		
		active = true;
		
		#end
	}
}