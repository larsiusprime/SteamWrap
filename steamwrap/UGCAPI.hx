package steamwrap;
import cpp.Lib;
import steamwrap.helpers.Loader;
import steamwrap.helpers.MacroHelper;

/**
 * The User Generated Content API. Used by API.hx, should never be created manually by the user.
 * API.hx creates and initializes this by default.
 * Access it via API.ugcstatic variable
 */

@:allow(steamwrap.API)
class UGCAPI
{
	/*************PUBLIC***************/
	
	/**
	 * Whether the controller API is initialized or not. If false, all calls will fail.
	 */
	public var active(default, null):Bool = false;
	
	//TODO: these all need documentation headers
	
	public function createItem():Void {
		SteamWrap_CreateUGCItem(appId);
	}
	
	public function setItemContent(updateHandle:String, absPath:String):Bool {
		return SteamWrap_SetUGCItemContent(updateHandle, absPath);
	}
	
	public function setItemDescription(updateHandle:String, itemDesc:String):Bool {
		return SteamWrap_SetUGCItemDescription(updateHandle, itemDesc.substr(0, 8000));
	}
	
	public function setItemPreviewImage(updateHandle:String, absPath:String):Bool {
		return SteamWrap_SetUGCItemPreviewImage(updateHandle, absPath);
	}
	
	public function setItemTitle(updateHandle:String, itemTitle:String):Bool {
		return SteamWrap_SetUGCItemTitle(updateHandle, itemTitle.substr(0, 128));
	}
	
	public function setItemVisibility(updateHandle:String, visibility:Int):Bool {
		/*
		* 	https://partner.steamgames.com/documentation/ugc
		*	0 : Public
		*	1 : Friends Only
		*	2 : Private
		*/
		return SteamWrap_SetUGCItemVisibility(updateHandle, visibility);
	}
	
	public function startUpdateItem(itemID:Int):String {
		return SteamWrap_StartUpdateUGCItem(appId, itemID);
	}
	
	public function submitItemUpdate(updateHandle:String, changeNotes:String):Bool {
		return SteamWrap_SubmitUGCItemUpdate(updateHandle, changeNotes);
	}
	
	/*************PRIVATE***************/
	
	private var customTrace:String->Void;
	private var appId:Int;
	
	//Old-school CFFI calls:
	private var SteamWrap_CreateUGCItem:Dynamic;
	private var SteamWrap_SetUGCItemTitle:Dynamic;
	private var SteamWrap_SetUGCItemDescription:Dynamic;
	private var SteamWrap_SetUGCItemVisibility:Dynamic;
	private var SteamWrap_SetUGCItemContent:Dynamic;
	private var SteamWrap_SetUGCItemPreviewImage:Dynamic;
	private var SteamWrap_StartUpdateUGCItem:Dynamic;
	private var SteamWrap_SubmitUGCItemUpdate:Dynamic;
	
	//CFFI PRIME calls:
		//none so far
	
	private function new(appId_:Int, CustomTrace:String->Void) {
		#if sys		//TODO: figure out what targets this will & won't work with and upate this guard
		
		if (active) return;
		
		appId = appId_;
		customTrace = CustomTrace;
		
		try {
			//Old-school CFFI calls:
			SteamWrap_CreateUGCItem = cpp.Lib.load("steamwrap", "SteamWrap_CreateUGCItem", 1);
			SteamWrap_SetUGCItemContent = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemContent", 2);
			SteamWrap_SetUGCItemDescription = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemDescription", 2);
			SteamWrap_SetUGCItemPreviewImage = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemPreviewImage", 2);
			SteamWrap_SetUGCItemTitle = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemTitle", 2);
			SteamWrap_SetUGCItemVisibility = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemVisibility", 2);
			SteamWrap_StartUpdateUGCItem = cpp.Lib.load("steamwrap", "SteamWrap_StartUpdateUGCItem", 2);
			SteamWrap_SubmitUGCItemUpdate = cpp.Lib.load("steamwrap", "SteamWrap_SubmitUGCItemUpdate", 2);
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