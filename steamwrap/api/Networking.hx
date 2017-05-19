package steamwrap.api;
import haxe.io.Bytes;
import steamwrap.helpers.SteamBase;
import steamwrap.helpers.Loader;

/**
 * ...
 * @author YellowAfterlife
 */
@:allow(steamwrap.api.Steam)
class Networking extends SteamBase {
	
	/**
	 * 
	 * @param	id	
	 * @param	bytes	
	 * @param	size	
	 * @param	type	
	 * @return	Whether sending succeeded.
	 */
	public function sendPacket(id:String, bytes:Bytes, size:Int, type:EP2PSend):Int {
		return SteamWrap_SendPacket(id, bytes, size, cast type);
	}
	//private var SteamWrap_SendP2PPacket = Loader.load("SteamWrap_SendP2PPacket", "coiii");
	private var SteamWrap_SendPacket = Loader.loadRaw("SteamWrap_SendPacket", 4);
	
	/**
	 * Pulls the next packet out of receive queue
	 * @return
	 */
	public function receivePacket():Bool {
		return SteamWrap_ReceivePacket();
	}
	private var SteamWrap_ReceivePacket = Loader.loadRaw("SteamWrap_ReceivePacket", 0);
	
	public function getPacketData():Bytes {
		return Bytes.ofData(SteamWrap_GetPacketData());
	}
	private var SteamWrap_GetPacketData = Loader.loadRaw("SteamWrap_GetPacketData", 0);
	
	public function getPacketSender():String {
		return SteamWrap_GetPacketSender();
	}
	private var SteamWrap_GetPacketSender = Loader.loadRaw("SteamWrap_GetPacketSender", 0);
	
	//
	private function new(appId:Int, customTrace:String->Void) {
		if (active) return;
		init(appId, customTrace);
	}
	
}

@:enum abstract EP2PSend(Int) {
	public var UNRELIABLE = 0;
	public var UNRELIABLE_NO_DELAY = 1;
	public var RELIABLE = 2;
	public var RELIABLE_WITH_BUFFERING = 3;
}
