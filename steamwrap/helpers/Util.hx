package steamwrap.helpers;

/**
 * ...
 * @author 
 */
class Util {
	
	public static function boolify(str:String):Bool
	{
		str = str.toLowerCase();
		if (str == "1" || str == "true") return true;
		return false;
	}
}