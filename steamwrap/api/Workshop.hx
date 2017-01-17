package steamwrap.api;
import cpp.Lib;
import haxe.io.Bytes;
import haxe.io.BytesData;
import steamwrap.api.Steam;
import steamwrap.helpers.Loader;
import steamwrap.helpers.MacroHelper;
import sys.io.File;

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
	 * Gets the amount of data downloaded so far for a piece of content
	 * @param	handle	the UGC file handle
	 * @return	an array with two values, index 0 is bytes downloaded, index 1 is total bytes expected (can be zero if the call fails or hasn't started yet, be careful before dividing for a percentage!)
	 */
	public function getUGCDownloadProgress(handle:String):Array<Int>{
		var data:String = SteamWrap_GetUGCDownloadProgress(handle);
		var arr:Array<String> = data.split(",");
		if (arr != null && arr.length == 2)
		{
			return [
				Std.parseInt(arr[0]),
				Std.parseInt(arr[1])
			];
		}
		return [0, 0];
	}
	
	/**
	 * Gets the amount of data downloaded so far for a piece of content as a percent
	 * @param	handle	the UGC file handle
	 * @return	a float between 0.0 and 1.0
	 */
	public function getUGCDownloadPercent(handle:String):Float{
		var data = getUGCDownloadProgress(handle);
		var bytes = data[0];
		var total = data[1];
		if (total <= 0) return 0.0;
		return bytes / total;
	}
	
	/**
	 * Downloads a UGC file.  A priority value of 0 will download the file immediately,
	 * otherwise it will wait to download the file until all downloads with a lower priority
	 * value are completed.  Downloads with equal priority will occur simultaneously.
	 * @param	handle	the UGC file handle
	 * @param	priority
	 */
	public function UGCDownload(handle:String, priority:Int):Void{
		SteamWrap_UGCDownload.call(handle, priority);
	}
	
	/**
	 * After download, gets the content of the file.  
	 * Small files can be read all at once by calling this function with an offset of 0 and cubDataToRead equal to the size of the file.
	 * Larger files can be read in chunks to reduce memory usage (since both sides of the IPC client and the game itself must allocate
	 * enough memory for each chunk).  Once the last byte is read, the file is implicitly closed and further calls to UGCRead will fail
	 * unless UGCDownload is called again.
	 * For especially large files (anything over 100MB) it is a requirement that the file is read in chunks.
	 * @param	handle	the UGC file handle
	 * @param	bytesToRead	how many bytes you intend to read
	 * @param	offset	position to start reading from (in bytes)
	 * @param	action	which method to use to read the file
	 * @return	the requested file contents as a Bytes data structure
	 */
	public function UGCRead(handle:String, bytesToRead:Int, offset:Int, action:EUGCReadAction):Bytes
	{
		var bytes:BytesData = SteamWrap_UGCRead(handle, bytesToRead, offset, action);
		return Bytes.ofData(bytes);
	}
	
	/**
	 * After download, gets the content of a file by repeatedly calling UGCRead() with the appropriate parameters, so you don't have to 
	 * worry about micromanaging the reading logic based on the file size.
	 * @param	handle	the UGC file handle
	 * @param	totalSizeInBytes	the total size of the file to be read in bytes
	 * @param	chunkSize	the size of a single reading "chunk" in bytes -- if the file is larger, multiple UGCRead() calls will be used
	 * @return	the entire file contents as a Bytes data structure
	 */
	public function UGCReadEntireFile(handle:String, totalSizeInBytes:Int, chunkSize:Int=8388608):Bytes
	{
		var chunks = Math.ceil(totalSizeInBytes / chunkSize);
		
		if (chunks == 1 && totalSizeInBytes < chunkSize)
		{
			chunkSize = totalSizeInBytes;
		}
		
		var bytes:Bytes = Bytes.alloc(totalSizeInBytes);
		var bytesLeft = totalSizeInBytes;
		var offset = 0;
		
		for (i in 0...chunks)
		{
			if (bytesLeft < chunkSize)
			{
				chunkSize = bytesLeft;
			}
			
			var result:BytesData = SteamWrap_UGCRead(handle, chunkSize, offset, EUGCReadAction.ContinueReadingUntilFinished);
			
			if (result != null)
			{
				bytes.blit(offset, Bytes.ofData(result), 0, chunkSize);
			}
			
			bytesLeft -= chunkSize;
			offset += chunkSize;
			
			if (bytesLeft <= 0)
			{
				break;
			}
		}
		
		return bytes;
	}
	
	public function getPublishedFileDetails(fileId:String, maxSecondsOld:Int):Void{
		SteamWrap_GetPublishedFileDetails.call(fileId, maxSecondsOld);
	}
	
	/*************PRIVATE***************/
	
	private var customTrace:String->Void;
	private var appId:Int;
	
	//Old-school CFFI calls:
	private var SteamWrap_GetUGCDownloadProgress:Dynamic;
	private var SteamWrap_UGCRead:Dynamic;
	
	//CFFI PRIME calls:
	private var SteamWrap_GetPublishedFileDetails          = Loader.load("SteamWrap_GetPublishedFileDetails"         , "civ");
	//private var SteamWrap_EnumeratePublishedWorkshopFiles  = Loader.load("SteamWrap_EnumeratePublishedWorkshopFiles" , "iiiicci");
	private var SteamWrap_EnumerateUserSharedWorkshopFiles = Loader.load("SteamWrap_EnumerateUserSharedWorkshopFiles", "ciccv");
	private var SteamWrap_EnumerateUserSubscribedFiles     = Loader.load("SteamWrap_EnumerateUserSubscribedFiles"    , "iv");
	private var SteamWrap_EnumerateUserPublishedFiles      = Loader.load("SteamWrap_EnumerateUserPublishedFiles"     , "iv");
	private var SteamWrap_UGCDownload                      = Loader.load("SteamWrap_UGCDownload"                     , "civ");
	
	private function new(appId_:Int, CustomTrace:String->Void) {
		#if sys		//TODO: figure out what targets this will & won't work with and upate this guard
		
		if (active) return;
		
		appId = appId_;
		customTrace = CustomTrace;
		
		try {
			//Old-school CFFI calls:
			SteamWrap_GetUGCDownloadProgress = cpp.Lib.load("steamwrap", "SteamWrap_GetUGCDownloadProgress", 1);
			SteamWrap_UGCRead = cpp.Lib.load("steamwrap", "SteamWrap_UGCRead", 4);
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