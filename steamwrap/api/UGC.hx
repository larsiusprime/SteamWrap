package steamwrap.api;
import cpp.Lib;
import steamwrap.api.Steam;
import steamwrap.helpers.Loader;
import steamwrap.helpers.MacroHelper;

/**
 * The User Generated Content API. Used by API.hx, should never be created manually by the user.
 * API.hx creates and initializes this by default.
 * Access it via API.ugcstatic variable
 */

@:allow(steamwrap.api.Steam)
class UGC
{
	/*************PUBLIC***************/
	
	/**
	 * Whether the UGC API is initialized or not. If false, all calls will fail.
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
	
	public function setItemTags(updateHandle:String, tags:String):Bool {
		return SteamWrap_SetUGCItemTags(updateHandle, tags);
	}
	
	public function addItemKeyValueTag(updateHandle:String, key:String, value:String):Bool {
		return SteamWrap_AddUGCItemKeyValueTag(updateHandle, key, value);
	}
	
	public function removeItemKeyValueTags(updateHandle:String, key:String):Bool {
		return SteamWrap_RemoveUGCItemKeyValueTags(updateHandle, key);
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
	
	public function getNumSubscribedItems():Int {
		return SteamWrap_GetNumSubscribedItems.call(0);
	}
	
	public function getItemState(fileID:String):EItemState {
		var result:EItemState = SteamWrap_GetItemState.call(fileID);
		return result;
	}
	
	/**
	 * Begin downloading a UGC
	 * @param	fileID
	 * @param	highPriority
	 * @return
	 */
	public function downloadItem(fileID:String, highPriority:Bool):Bool {
		var result = SteamWrap_DownloadItem.call(fileID, highPriority ? 1 : 0);
		return result == 1;
	}
	
	/**
	 * Filter query results to only those that include this tag
	 * @param	queryHandle
	 * @param	tagName
	 * @return
	 */
	public function addRequiredTag(queryHandle:String, tagName:String):Bool {
		var result = SteamWrap_AddRequiredTag.call(queryHandle, tagName);
		return result == 1;
	}
	
	/**
	 * Filter query results to only those that lack this tag
	 * @param	queryHandle
	 * @param	tagName
	 * @return
	 */
	public function addExcludedTag(queryHandle:String, tagName:String):Bool {
		var result:Int = SteamWrap_AddExcludedTag.call(queryHandle, tagName);
		return result == 1;
	}
	
	/**
	 * Filter query results to only those that have a key with name `key` and a value that matches `value`
	 * @param	queryHandle
	 * @param	key
	 * @param	value
	 * @return
	 */
	public function addRequiredKeyValueTag(queryHandle:String, key:String, value:String):Bool {
		var result:Int = SteamWrap_AddRequiredKeyValueTag.call(queryHandle, key, value);
		return result == 1;
	}
	
	/**
	 * Return any key-value tags for the items
	 * @param	queryHandle
	 * @param	returnKeyValueTags
	 * @return
	 */
	public function setReturnKeyValueTags(queryHandle:String, returnKeyValueTags:Bool):Bool {
		var result:Int = SteamWrap_SetReturnKeyValueTags.call(queryHandle, returnKeyValueTags? 1 : 0);
		return result == 1;
	}
	
	/**
	 * Return the developer specified metadata for each queried item
	 * @param	queryHandle
	 * @param	returnMetadata
	 * @return
	 */
	public function setReturnMetadata(queryHandle:String, returnMetadata:Bool):Bool {
		var result:Int = SteamWrap_SetReturnMetadata.call(queryHandle, returnMetadata ? 1 : 0);
		return result == 1;
	}
	
	/**
	 * Get an array of publishedFileID's for UGC items the user is subscribed to
	 * @return publishedFileID array (represented as strings)
	 */
	public function getSubscribedItems():Array<String>{
		var result = SteamWrap_GetSubscribedItems();
		if (result == "" || result == null) return [];
		var arr:Array<String> = result.split(",");
		return arr;
	}
	
	/**
	 * Get the amount of bytes that have been downloaded for the given file
	 * @param	fileID the publishedFileID for this UGC item
	 * @return	an array: [0] is bytesDownloaded, [1] is bytesTotal
	 */
	public function getItemDownloadInfo(fileID:String):Array<Int>{
		var result = SteamWrap_GetItemDownloadInfo(fileID);
		if (result == "" || result == null) return [0, 0];
		var arr:Array<String> = result.split(",");
		var a = Std.parseInt(arr[0]);
		var b = Std.parseInt(arr[1]);
		var ai:Int = a != null ? a : 0;
		var bi:Int = b != null ? b : 0;
		return [ai, bi];
	}
	
	public function getItemInstallInfo(fileID:String):GetItemInstallInfoResult{
		var result = SteamWrap_GetItemInstallInfo(fileID, 30000);
		return GetItemInstallInfoResult.fromString(result);
	}
	
	/*
	 * Query UGC associated with a user. Creator app id or consumer app id must be valid and be set to the current running app. Page should start at 1.
	 */
	/*
	public function createQueryUserUGCRequest(accountID:String, listType, matchingUGCType, sortOrder, creatorAppID:String, consumerAppID:String, page:Int)
	{
		
	}
	*/
	
	/**
	 * Query for all matching UGC. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1.
	 * @param	queryType
	 * @param	matchingUGCType
	 * @param	creatorAppID
	 * @param	consumerAppID
	 * @param	page
	 * @return
	 */
	public function createQueryAllUGCRequest(queryType:EUGCQuery, matchingUGCType:EUGCMatchingUGCType, creatorAppID:Int, consumerAppID:Int, page:Int):String
	{
		var result:String = SteamWrap_CreateQueryAllUGCRequest(queryType, matchingUGCType, creatorAppID, consumerAppID, page);
		return result;
	}
	
	/**
	 * Query for the details of the given published file ids
	 * @param	fileIDs
	 * @return
	 */
	public function createQueryUGCDetailsRequest(fileIDs:Array<String>):String
	{
		var result = SteamWrap_CreateQueryUGCDetailsRequest(fileIDs.join(","));
		return result;
	}
	
	/**
	 * Send the query to Steam
	 * @param	handle
	 */
	public function sendQueryUGCRequest(handle:String):Void
	{
		trace("sendQueryUGCRequest(" + handle+")");
		SteamWrap_SendQueryUGCRequest.call(handle);
	}
	
	/**
	 * Retrieve an individual result after receiving the callback for querying UGC
	 * @param	handle
	 * @param	index
	 * @return
	 */
	public function getQueryUGCResult(handle:String, index:Int):SteamUGCDetails
	{
		var result:String = SteamWrap_GetQueryUGCResult(handle, index);
		var details:SteamUGCDetails = SteamUGCDetails.fromString(result);
		return details;
	}
	
	/**
	 * 
	 * @param	handle
	 * @param	index
	 * @return
	 */
	public function getQueryUGCMetadata(handle:Int, index:Int):String
	{
		var result:String = SteamWrap_GetQueryUGCMetadata(handle, index, 5000);
		return result;
	}
	
	public function getQueryUGCNumKeyValueTags(handle:String, index:Int):Int
	{
		var result = SteamWrap_GetQueryUGCNumKeyValueTags.call(handle, index);
		return result;
	}
	
	public function getQueryUGCKeyValueTag(handle:String, index:Int, keyValueTagIndex:Int):Array<String>
	{
		var result:String = SteamWrap_GetQueryUGCKeyValueTag(handle, index, keyValueTagIndex, 255, 255);
		if (result != null && result.indexOf("=") != -1){
			var arr = result.split("=");
			if (arr != null && arr.length == 2 && arr[0] != null && arr[1] != null){
				return arr;
			}
		}
		return ["",""];
	}
	
	public function releaseQueryUGCRequest(handle:String):Bool
	{
		var result = SteamWrap_ReleaseQueryUGCRequest.call(handle);
		return result == 1;
	}
	
	/*************PRIVATE***************/
	
	private var customTrace:String->Void;
	private var appId:Int;
	
	//Old-school CFFI calls:
	private var SteamWrap_CreateUGCItem:Dynamic;
	private var SteamWrap_SetUGCItemTitle:Dynamic;
	private var SteamWrap_SetUGCItemTags:Dynamic;
	private var SteamWrap_AddUGCItemKeyValueTag:Dynamic;
	private var SteamWrap_RemoveUGCItemKeyValueTags:Dynamic;
	private var SteamWrap_SetUGCItemDescription:Dynamic;
	private var SteamWrap_SetUGCItemVisibility:Dynamic;
	private var SteamWrap_SetUGCItemContent:Dynamic;
	private var SteamWrap_SetUGCItemPreviewImage:Dynamic;
	private var SteamWrap_StartUpdateUGCItem:Dynamic;
	private var SteamWrap_SubmitUGCItemUpdate:Dynamic;
	private var SteamWrap_GetSubscribedItems:Dynamic;
	private var SteamWrap_GetItemDownloadInfo:Dynamic;
	private var SteamWrap_GetItemInstallInfo:Dynamic;
	private var SteamWrap_CreateQueryAllUGCRequest:Dynamic;
	private var SteamWrap_CreateQueryUGCDetailsRequest:Dynamic;
	private var SteamWrap_GetQueryUGCResult:Dynamic;
	private var SteamWrap_GetQueryUGCKeyValueTag:Dynamic;
	private var SteamWrap_GetQueryUGCMetadata:Dynamic;
	
	//CFFI PRIME calls:
	private var SteamWrap_GetNumSubscribedItems = Loader.load("SteamWrap_GetNumSubscribedItems","ii");
	private var SteamWrap_GetItemState = Loader.load("SteamWrap_GetItemState","ci");
	private var SteamWrap_DownloadItem = Loader.load("SteamWrap_DownloadItem","cii");
	private var SteamWrap_AddRequiredKeyValueTag = Loader.load("SteamWrap_AddRequiredKeyValueTag", "ccci");
	private var SteamWrap_AddRequiredTag = Loader.load("SteamWrap_AddRequiredTag", "cci");
	private var SteamWrap_AddExcludedTag = Loader.load("SteamWrap_AddExcludedTag", "cci");
	private var SteamWrap_SendQueryUGCRequest = Loader.load("SteamWrap_SendQueryUGCRequest", "cv");
	private var SteamWrap_SetReturnMetadata = Loader.load("SteamWrap_SetReturnMetadata", "cii");
	private var SteamWrap_SetReturnKeyValueTags = Loader.load("SteamWrap_SetReturnKeyValueTags", "cii");
	private var SteamWrap_ReleaseQueryUGCRequest = Loader.load("SteamWrap_ReleaseQueryUGCRequest", "ci");
	private var SteamWrap_GetQueryUGCNumKeyValueTags = Loader.load("SteamWrap_GetQueryUGCNumKeyValueTags", "cii");
	
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
			SteamWrap_SetUGCItemTags = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemTags", 2);
			SteamWrap_AddUGCItemKeyValueTag = cpp.Lib.load("steamwrap", "SteamWrap_AddUGCItemKeyValueTag", 3);
			SteamWrap_RemoveUGCItemKeyValueTags = cpp.Lib.load("steamwrap", "SteamWrap_RemoveUGCItemKeyValueTags", 2);
			SteamWrap_SetUGCItemVisibility = cpp.Lib.load("steamwrap", "SteamWrap_SetUGCItemVisibility", 2);
			SteamWrap_StartUpdateUGCItem = cpp.Lib.load("steamwrap", "SteamWrap_StartUpdateUGCItem", 2);
			SteamWrap_SubmitUGCItemUpdate = cpp.Lib.load("steamwrap", "SteamWrap_SubmitUGCItemUpdate", 2);
			SteamWrap_GetSubscribedItems = cpp.Lib.load("steamwrap", "SteamWrap_GetSubscribedItems", 0);
			SteamWrap_GetItemDownloadInfo = cpp.Lib.load("steamwrap", "SteamWrap_GetItemDownloadInfo", 1);
			SteamWrap_GetItemInstallInfo = cpp.Lib.load("steamwrap", "SteamWrap_GetItemInstallInfo", 2);
			
			SteamWrap_CreateQueryAllUGCRequest = cpp.Lib.load("steamwrap", "SteamWrap_CreateQueryAllUGCRequest", 5);
			SteamWrap_CreateQueryUGCDetailsRequest = cpp.Lib.load("steamwrap", "SteamWrap_CreateQueryUGCDetailsRequest", 1);
			SteamWrap_GetQueryUGCResult = cpp.Lib.load("steamwrap", "SteamWrap_GetQueryUGCResult", 2);
			SteamWrap_GetQueryUGCKeyValueTag = cpp.Lib.load("steamwrap", "SteamWrap_GetQueryUGCKeyValueTag", 5);
			SteamWrap_GetQueryUGCMetadata = cpp.Lib.load("steamwrap", "SteamWrap_GetQueryUGCMetadata", 3);
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