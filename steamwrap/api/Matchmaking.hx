package steamwrap.api;
import steamwrap.helpers.Loader;
import steamwrap.helpers.SteamBase;

/**
 * ...
 * @author YellowAfterlife
 */
@:allow(steamwrap.api.Steam)
class Matchmaking extends SteamBase {
	
	/** Called when lobby creation succeeds/fails */
	public var whenLobbyCreated:Bool->Void = null;
	
	/** Called when a lobby joining succeeds/fails */
	public var whenLobbyJoined:Bool->Void = null;
	
	/**
	 * Called when the user accepts an invitation from an overlay.
	 * You generally want to do joinLobby(lobbyId) in that case,
	 * unless the game is amid something best not quit (e.g. other session)
	 */
	public var whenLobbyJoinRequested:{ lobbyID:String, friendID:String }->Void = null;
	
	/**
	 * Starts the lobby creation process.
	 * whenLobbyCreated will be called when it finishes.
	 * Lobby creation only fails if the game has Matchmaking API disabled
	 * or if there is no connection to Steam servers.
	 */
	public function createLobby(type:LobbyType, maxMembers:Int):Bool {
		return SteamWrap_CreateLobby(cast type, maxMembers);
	}
	private var SteamWrap_CreateLobby = Loader.load("SteamWrap_CreateLobby", "iib");
	
	/**
	 * Starts joining the given lobby.
	 * whenLobbyJoined will be called when this succeeds/fails.
	 */
	public function joinLobby(id:String):Bool {
		return SteamWrap_JoinLobby(id);
	}
	private var SteamWrap_JoinLobby = Loader.load("SteamWrap_JoinLobby", "sb");
	
	/**
	 * Leaves the current lobby, if any.
	 */
	public function leaveLobby():Bool {
		return SteamWrap_LeaveLobby();
	}
	private var SteamWrap_LeaveLobby = Loader.loadRaw("SteamWrap_LeaveLobby", 0);
	
	/**
	 * Returns Steam ID of user that is the current lobby' owner.
	 * When the owner leaves, ownership is automatically transferred to a new user.
	 */
	public function getLobbyOwner():String {
		return SteamWrap_LobbyOwnerID();
	}
	private var SteamWrap_LobbyOwnerID = Loader.loadRaw("SteamWrap_LobbyOwnerID", 0);
	
	/**
	 * Returns the number of users in the current lobby.
	 */
	public function getLobbyMembers():Int {
		return SteamWrap_LobbyMemberCount();
	}
	private var SteamWrap_LobbyMemberCount = Loader.loadRaw("SteamWrap_LobbyMemberCount", 0);
	
	/**
	 * Returns the ID of the given user (0...getLobbyMembers() excl) in the current lobby.
	 */
	public function getLobbyMember(index:Int):Int {
		return SteamWrap_LobbyMemberID(index);
	}
	private var SteamWrap_LobbyMemberID = Loader.loadRaw("SteamWrap_LobbyMemberID", 1);
	
	/**
	 * Displays the invitation overlay.
	 * This only works while in a lobby.
	 */
	public function activateInviteOverlay():Bool {
		return SteamWrap_ActivateInviteOverlay();
	}
	private var SteamWrap_ActivateInviteOverlay = Loader.loadRaw("SteamWrap_ActivateInviteOverlay", 0);
	
	override function new(appId:Int, customTrace:String->Void) {
		if (active) return;
		init(appId, customTrace);
	}
}

@:enum abstract LobbyType(Int) {
	public var PRIVATE = 0;
	public var FRIENDS_ONLY = 1;
	public var PUBLIC = 1;
}
