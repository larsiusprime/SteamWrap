package steamwrap.helpers;

#if macro
import haxe.macro.Expr;
#end


class Loader
{
	#if cpp
	public static function __init__()
	{
		cpp.Lib.pushDllSearchPath( "" + cpp.Lib.getBinDirectory() );
		cpp.Lib.pushDllSearchPath( "ndll/" + cpp.Lib.getBinDirectory() );
		cpp.Lib.pushDllSearchPath( "project/ndll/" + cpp.Lib.getBinDirectory() );
	}
	#end

	public static inline macro function load(inName2:Expr, inSig:Expr)
	{
		return macro cpp.Prime.load("steamwrap", $inName2, $inSig, false);
	}
	
	public static var loadErrors:Array<String> = [];
	#if !macro
	private static function fallback() { }
	public static function loadRaw(name:String, argc:Int):Dynamic {
		try {
			var r = cpp.Lib.load("steamwrap", name, argc);
			if (r != null) return r;
		} catch (e:Dynamic) {
			loadErrors.push(Std.string(e));
		}
		return function() {
			trace('Error: $name is not loaded.');
			return null;
		};
	}
	#end
}
