package steamwrap.api;

/**
 * In a good case scenario, should be using 64-bit integers for this.
 */
abstract SteamID(String) from String to String {
	public static inline var defValue:SteamID = "0";
}
