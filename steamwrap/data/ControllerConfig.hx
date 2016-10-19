package steamwrap.data;
import haxe.EnumTools;
import haxe.Json;
import steamwrap.data.Locale;

/**
 * A strongly-typed data structure representation of the "game_actions_xyz.vdf"
 * file Steam uses to define controller inputs for your game. You can initialize
 * this from a VDF string, JSON string, or generic data structure
 * 
 * @author 
 */
class ControllerConfig
{

	public var actionSets:Array<ControllerActionSet>;
	public var localizations:Array<ControllerLocalization>;
	
	public function new()
	{
		
	}
	
	public function toString():String
	{
		var str = "actions:\n";
		for (actionSet in actionSets)
		{
			str += actionSet.name + " loc = " + actionSet.localizationKey + "\n";
			str += "...buttons = \n";
			for (button in actionSet.button) {
				str += "......" + button.name + " loc = " + button.localizationKey + "\n";
			}
			str += "...analogs = \n";
			for (analog in actionSet.analogTrigger) {
				str += "......" + analog.name + " loc = " + analog.localizationKey + "\n";
			}
			str += "...stickpadgyros = \n";
			for (stickpadgyro in actionSet.stickPadGyro) {
				str += "......" + stickpadgyro.name + " loc = " + stickpadgyro.localizationKey + " mode = " + stickpadgyro.inputMode + " osMouse = " + stickpadgyro.osMouse + "\n";
			}
		}
		str += "localizations:\n";
		for (loc in localizations)
		{
			str += "...locale = " + loc.locale + "\n";
			for (key in loc.values.keys())
			{
				str += "......" + key + " = " + loc.values.get(key) + "\n";
			}
		}
		
		return str;
	}
	
	public static function fromVDF(str:String):ControllerConfig
	{
		return fromObject(VDF.parse(str));
	}
	
	public static function fromJSON(str:String):ControllerConfig
	{
		return fromObject(Json.parse(str));
	}
	
	public static function fromObject(obj:Dynamic):ControllerConfig
	{
		var config = new ControllerConfig();
		
		config.actionSets = [];
		config.localizations = [];
		
		var foundRoot = false;
		
		for (field in Reflect.fields(obj))
		{
			var s:String = simplestr(field);
			
			if (s == "ingameactions")
			{
				foundRoot = true;
				var root = Reflect.field(obj, field);
				
				var foundActions = false;
				var foundLocs = false;
				
				for (field2 in Reflect.fields(root))
				{
					var s2:String = simplestr(field2);
					
					if (s2 == "actions")
					{
						var actionRoot = Reflect.field(root, field2);
						loadActions(config, actionRoot);
						foundActions = true;
					}
					
					if (s2 == "localization")
					{
						var locRoot = Reflect.field(root, field2);
						loadLocalizations(config, locRoot);
						foundLocs = true;
					}
				}
				
				if(!foundActions)
				{
					throw "field (In Game Actions).(actions) not found!";
				}
				
				if(!foundLocs)
				{
					trace ("WARNING: (In Game Actions).(localization) not found!");
				}
			}
			else
			{
				if (!foundRoot)
				{
					throw ("root field (In Game Actions) not found!");
				}
			}
		}
		
		return config;
	}
	
	private static function loadActions(config:ControllerConfig, actionRoot:Dynamic)
	{
		for (actionSetName in Reflect.fields(actionRoot))
		{
			var set:ControllerActionSet = { name:actionSetName, localizationKey:"", button:[], analogTrigger:[], stickPadGyro:[] };
			var actionSetNode = Reflect.field(actionRoot, actionSetName);
			for (field in Reflect.fields(actionSetNode))
			{
				var s:String = simplestr(field);
				if (s == "title")
				{
					set.localizationKey = Reflect.field(actionSetNode, field);
				}
				else if (s == "button")
				{
					var buttonNode = Reflect.field(actionSetNode, field);
					for (bField in Reflect.fields(buttonNode))
					{
						var value = simplestr(Reflect.field(buttonNode, bField));
						if (false == (bField == "obj" && value == "{}"))
						{
							var buttonAction = { name:bField, localizationKey:value };
							set.button.push(buttonAction);
						}
					}
					
				}
				else if (s == "analogtrigger")
				{
					var analogTriggerNode = Reflect.field(actionSetNode, field);
					for (aField in Reflect.fields(analogTriggerNode))
					{
						var value = simplestr(Reflect.field(analogTriggerNode, aField));
						if (false == (aField == "obj" && value == "{}"))
						{
							var analogAction = { name:aField, localizationKey:value };
							set.analogTrigger.push(analogAction);
						}
					}
					
				}
				else if (s == "stickpadgyro")
				{
					var stickPadGyroNode = Reflect.field(actionSetNode, field);
					for (sField in Reflect.fields(stickPadGyroNode))
					{
						var stickPadGyroAction = { name:sField, localizationKey:"", inputMode:JoystickMove, osMouse:false };
						var sNode = Reflect.field(stickPadGyroNode, sField);
						var noFields = true;
						for (s2Field in Reflect.fields(sNode)) 
						{
							noFields = false;
							var s2Str:String = simplestr(s2Field);
							var s2Node = Reflect.field(sNode, s2Field);
							var s2Val  = Reflect.field(s2Node, s2Field);
							
							if (s2Str == "title")
							{
								stickPadGyroAction.localizationKey = simplestr(s2Val);
							}
							else if (s2Str == "input_mode")
							{
								var inputMode = simplestr(s2Val);
								if (inputMode == "absolute_mouse")
								{
									stickPadGyroAction.inputMode = AnalogInputMode.AbsoluteMouse;
								}
							}
							else if (s2Str == "os_mouse")
							{
								stickPadGyroAction.osMouse = (s2Val == "1");
							}
						}
						if (!noFields)
						{
							set.stickPadGyro.push(stickPadGyroAction);
						}
					}
				}
			}
			config.actionSets.push(set);
		}
		return config;
	}
	
	private static function simplestr(str:String):String
	{
		str = str.toLowerCase();
		str = StringTools.replace(str, " ", "");
		return str;
	}
	
	private static function loadLocalizations(config:ControllerConfig, locRoot:Dynamic)
	{
		for (locName in Reflect.fields(locRoot))
		{
			var locale:Locale = locName;
			if (locale != Locale.UNKNOWN)
			{
				var locNode = Reflect.field(locRoot, locName);
				var localization:ControllerLocalization = {locale:locale, values:new Map<String,String>()};
				
				for (locKey in Reflect.fields(locNode))
				{
					var locValue = Reflect.field(locNode, locKey);
					localization.values.set(locKey, locValue);
				}
				
				config.localizations.push(localization);
			}
			else
			{
				trace ("WARNING: unsupported locale (" + locale + ")");
			}
		}
	}
}

typedef ControllerActionSet = {
	private var name:String;
	private var localizationKey:String;
	private var button:Array<ButtonAction>;
	private var analogTrigger:Array<AnalogTriggerAction>;
	private var stickPadGyro:Array<StickPadGyroAction>;
};

//typedef ControllerAction = OneOfThree<ButtonAction,AnalogTriggerAction,StickPadGyroAction>;

typedef ButtonAction = {
	var name:String;
	var localizationKey:String;
}

typedef AnalogTriggerAction = {
	var name:String;
	var localizationKey:String;
}

typedef StickPadGyroAction = {
	var name:String;
	var localizationKey:String;
	var inputMode:AnalogInputMode;
	var osMouse:Bool;
}

typedef ControllerLocalization = {
	var locale:Locale;
	var values:Map<String,String>;
}

enum AnalogInputMode {
	AbsoluteMouse;
	JoystickMove;
}

enum ControllerActionType {
	Button;
	AnalogTrigger;
	StickPadGyro;
}