package steamwrap.api;
import steamwrap.helpers.Loader;
import steamwrap.helpers.SteamBase;

/**
 * Wraps parts of Steam Matchmaking API.
 * For sake of simplicity, only one "current" lobby is tracked per player.
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
	public var whenLobbyJoinRequested:{ lobbyID:SteamID, friendID:SteamID }->Void = null;
	
	/**
	 * Called when an updated list of lobbies is received.
	 */
	public var whenLobbyListReceived:Bool->Void = null;
	
	//{ Current lobby
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
	public function joinLobby(id:SteamID):Bool {
		return SteamWrap_JoinLobby(id);
	}
	private var SteamWrap_JoinLobby = Loader.loadRaw("SteamWrap_JoinLobby", 1);
	
	/**
	 * Leaves the current lobby, if any.
	 */
	public function leaveLobby():Bool {
		return SteamWrap_LeaveLobby();
	}
	private var SteamWrap_LeaveLobby = Loader.loadRaw("SteamWrap_LeaveLobby", 0);
	
	/**
	 * Returns Steam ID of the current lobby (if any).
	 */
	public function getLobbyID():SteamID {
		return SteamWrap_LobbyID_();
	}
	private var SteamWrap_LobbyID_ = Loader.loadRaw("SteamWrap_LobbyID_", 0);
	
	/**
	 * Returns Steam ID of user that is the current lobby' owner.
	 * When the owner leaves, ownership is automatically transferred to a new user.
	 */
	public function getLobbyOwner():SteamID {
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
	public function getLobbyMember(index:Int):SteamID {
		return SteamWrap_LobbyMemberID(index);
	}
	private var SteamWrap_LobbyMemberID = Loader.loadRaw("SteamWrap_LobbyMemberID", 1);
	
	/**
	 * Changes lobby data (which can then be used to display on lobby list).
	 * Only lobby' owner can change lobby data.
	 */
	public function setLobbyData(field:String, value:String):Bool {
		return SteamWrap_LobbySetData(field, value);
	}
	private var SteamWrap_LobbySetData = Loader.loadRaw("SteamWrap_LobbySetData", 2);
	
	/**
	 * Changes lobby type (visibility setting). Only lobby owner can do this.
	 */
	public function setLobbyType(type:LobbyType):Bool {
		return SteamWrap_SetLobbyType(cast type);
	}
	private var SteamWrap_SetLobbyType = Loader.load("SteamWrap_SetLobbyType", "ib");
	
	/**
	 * Displays the invitation overlay.
	 * This only works while in a lobby.
	 */
	public function activateInviteOverlay():Bool {
		return SteamWrap_ActivateInviteOverlay();
	}
	private var SteamWrap_ActivateInviteOverlay = Loader.loadRaw("SteamWrap_ActivateInviteOverlay", 0);
	//}
	
	//{ Lobby list
	/**
	 * Requests a list of matching lobbies from Steam.
	 * whenLobbyListReceived will be called when this finishes.
	 */
	public function requestLobbyList():Bool {
		return SteamWrap_RequestLobbyList();
	}
	private var SteamWrap_RequestLobbyList = Loader.loadRaw("SteamWrap_RequestLobbyList", 0);
	
	/**
	 * Indicates whether a lobby list request is currently underway.
	 */
	public var lobbyListIsLoading(get, never):Bool;
	private function get_lobbyListIsLoading():Bool {
		return SteamWrap_LobbyListIsLoading();
	}
	private var SteamWrap_LobbyListIsLoading = Loader.loadRaw("SteamWrap_LobbyListIsLoading", 0);
	
	/**
	 * Returns the number of stored entries in the current list of lobbies.
	 */
	public var lobbyListLength(get, never):Int;
	private function get_lobbyListLength():Int {
		return SteamWrap_LobbyListLength();
	}
	private var SteamWrap_LobbyListLength = Loader.loadRaw("SteamWrap_LobbyListLength", 0);
	
	/**
	 * Returns Steam ID of the lobby at given position in the list.
	 * This can be used with joinLobby to connect to it.
	 */
	public function lobbyListID(index:Int):SteamID {
		return SteamWrap_LobbyListGetID(index);
	}
	private var SteamWrap_LobbyListGetID = Loader.loadRaw("SteamWrap_LobbyListGetID", 1);
	
	/**
	 * Returns stored data for lobby at the given position in the list.
	 */
	public function lobbyListData(index:Int, field:String):String {
		return SteamWrap_LobbyListGetData(index, field);
	}
	private var SteamWrap_LobbyListGetData = Loader.loadRaw("SteamWrap_LobbyListGetData", 2);
	//}
	
	//{ Lobby filters
	/**
	 * Sets up a string filter for the next lobby list request.
	 */
	public function addLobbyListStringFilter(field:String, value:String, cmp:LobbyCmp):Bool {
		return SteamWrap_LobbyListAddStringFilter(field, value, cast cmp);
	}
	private var SteamWrap_LobbyListAddStringFilter = Loader.loadRaw("SteamWrap_LobbyListAddStringFilter", 3);
	
	/**
	 * Sets up a numerical filter for the next lobby list request.
	 */
	public function addLobbyListNumericalFilter(field:String, value:Int, cmp:LobbyCmp):Bool {
		return SteamWrap_LobbyListAddNumericalFilter(field, value, cast cmp);
	}
	private var SteamWrap_LobbyListAddNumericalFilter = Loader.loadRaw("SteamWrap_LobbyListAddNumericalFilter", 3);
	
	/**
	 * Sorts the results of next lobby list request by proximity to value.
	 * Commonly used for matching the user with someone closest to their level.
	 */
	public function addLobbyListNearFilter(field:String, value:Int):Bool {
		return SteamWrap_LobbyListAddNearFilter(field, value);
	}
	private var SteamWrap_LobbyListAddNearFilter = Loader.loadRaw("SteamWrap_LobbyListAddNearFilter", 2);
	
	/**
	 * Limits the results of next lobby list request by geographical proximity.
	 */
	public function addLobbyListDistanceFilter(filter:LobbyDistanceFilter):Bool {
		return SteamWrap_LobbyListAddDistanceFilter(cast filter);
	}
	private var SteamWrap_LobbyListAddDistanceFilter = Loader.loadRaw("SteamWrap_LobbyListAddDistanceFilter", 1);
	//}
	
	private function new(appId:Int, customTrace:String->Void) {
		if (active) return;
		init(appId, customTrace);
	}
}

@:enum abstract LobbyDistanceFilter(Int) {
	
	/** Show lobbies from roughly the same/adjacent country */
	public var NEAR = 0;
	
	/** Show lobbies from roughly the same region */
	public var DEFAULT = 1;
	
	/** Show lobbies from roughly the same continent */ 
	public var FAR = 2;
	
	/** Show lobbies from anywhere (note: very high latencies possible) */
	public var WORLDWIDE = 3;
}

@:enum abstract LobbyType(Int) {
	
	/** Can only be joined by invitation */
	public var PRIVATE = 0;
	
	/** Can be joined by invitation and via friends-list (user options - "Join game") */
	public var FRIENDS_ONLY = 1;
	
	/** Can be joined by invitation, friends-list, and shows up in public lobby list */
	public var PUBLIC = 2;
}

@:enum abstract LobbyCmp(Int) {
	public var EQUAL = 0;
	public var NOT_EQUAL = 3;
	public var LESS_THAN = -1;
	public var EQUAL_OR_LESS_THAN = -2;
	public var GREATER_THAN = 1;
	public var EQUAL_OR_GREATER_THAN = 2;
	// short versions:
	public var EQ = 0;
	public var NE = 3;
	public var LT = -1;
	public var LE = -2;
	public var GT = 1;
	public var GE = 2;
}
