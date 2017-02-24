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
	
	public static function str2Float(str:String, defaultValue:Float=0.0):Float{
		var f = Std.parseFloat(str);
		if (Math.isNaN(f)) return defaultValue;
		else return f;
	}

	public static function str2Int(str:String, defaultValue:Int=0):Int{
		var i = Std.parseInt(str);
		if (i == null) return defaultValue;
		else return i;
	}
}