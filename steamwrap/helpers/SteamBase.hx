package steamwrap.helpers;

/**
 * ...
 * @author YellowAfterlife
 */
class SteamBase {
	public var active(default, null):Bool = false;
	private static var errors:Array<String> = [];
	//
	private var customTrace:String->Void;
	private var appId:Int;
	
	private function init(appId:Int, customTrace:String->Void):Bool {
		this.appId = appId;
		this.customTrace = customTrace;
		//
		var es = Loader.loadErrors;
		if (es.length > 0) {
			for (e in es) trace("Failed to initialize SteamWrap: " + e);
			es.splice(0, es.length);
			active = false;
		} else active = true;
		return active;
	}
}
