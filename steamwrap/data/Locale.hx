package steamwrap.data;

/**
 * ...
 * @author 
 */
@:enum
abstract Locale(String) from String
{
	var BRAZILIAN = "brazilian";
	var BULGARIAN = "bulgarian";
	var CZECH = "czech";
	var DANISH = "danish";
	var DUTCH = "dutch";
	var ENGLISH = "english";
	var FINNISH = "finnish";
	var FRENCH = "french";
	var GERMAN = "german";
	var GREEK = "greek";
	var HUNGARIAN = "hungarian";
	var ITALIAN = "italian";
	var JAPANESE = "japanese";
	var KOREANA = "koreana";
	var KOREAN = "korean";
	var NORWEGIAN = "norwegian";
	var POLISH = "polish";
	var PORTUGUESE = "portuguese";
	var ROMANIAN = "romanian";
	var RUSSIAN = "russian";
	var SCHINESE = "schinese";
	var SPANISH = "spanish";
	var SWEDISH = "swedish";
	var TCHINESE = "tchinese";
	var THAI = "thai";
	var TURKISH = "turkish";
	var UKRAINIAN = "ukrainian";
	var UNKNOWN = "unknown";
	
	public function new(str:String) {
		
		str = str.toLowerCase();
		
		this = switch(str : Locale) {
			
			case 
				Locale.BRAZILIAN, 
				Locale.BULGARIAN, 
				Locale.CZECH, 
				Locale.DANISH, 
				Locale.DUTCH, 
				Locale.ENGLISH,
				Locale.FINNISH, 
				Locale.FRENCH, 
				Locale.GERMAN, 
				Locale.GREEK, 
				Locale.HUNGARIAN, 
				Locale.ITALIAN, 
				Locale.JAPANESE,
				Locale.KOREANA, 
				Locale.KOREAN, 
				Locale.NORWEGIAN, 
				Locale.POLISH, 
				Locale.PORTUGUESE, 
				Locale.ROMANIAN,
				Locale.RUSSIAN, 
				Locale.SCHINESE, 
				Locale.SPANISH, 
				Locale.SWEDISH, 
				Locale.TCHINESE, 
				Locale.THAI, 
				Locale.TURKISH,
				Locale.UKRAINIAN: 
					cast str;
			default:
				cast Locale.UNKNOWN;
		}
		
	}
}
