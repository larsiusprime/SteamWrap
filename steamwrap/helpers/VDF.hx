package steamwrap.helpers;
import haxe.Json;

/*

Converts a VDF file (Valve Data Format) into a generic object (which can then be converted to Json via hx.Json)

-------------

VDF (de)serialization
Distributed under the ISC License

========================
Copyright (c) 2010-2013, Anthony Garcia <anthony@lagg.me>

Permission to use, copy, modify, and/or distribute this software for any 
purpose with or without fee is hereby granted, provided that the above 
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR 
PERFORMANCE OF THIS SOFTWARE.
========================

Ported to node.js by Rob Jackson - rjackson.me.
Minor tweaks for vdfjson by Rob Jackson - rjackson.me.
Ported to Haxe by Lars Doucet
*/

typedef StrNum = { str:String,  num:Int };
typedef ObjNum = { obj:Dynamic, num:Int };

class VDF
{
	public static inline var STRING = '"';
	public static inline var NODE_OPEN = '{';
	public static inline var NODE_CLOSE = '}';
	public static inline var BR_OPEN =  '[';
	public static inline var BR_CLOSE =  ']';
	public static inline var COMMENT = '/';
	public static inline var CR = '\r';
	public static inline var LF = '\n';
	public static inline var SPACE =  ' ';
	public static inline var TAB =  '\t';
	public static var WHITESPACE(default, null) = [' ', "\t", "\r", "\n"];
	
	public static function parse(string:String):Dynamic
	{
		var _parsed = _parse(string);
		if (_parsed != null && _parsed.obj != null)
		{
			return _strip(_parsed.obj);
		}
		return { };
	}
	
	private static function _parse(stream:String, ptr:Int = 0):ObjNum
	{
		var laststr:String = "";
		var lasttok:String = "";
		var lastbrk:String = "";
		var i:Int = ptr;
		var next_is_value:Bool = false;
		var deserialized:ObjNum = { obj:{}, num:0 };
		
		while (i < stream.length)
		{
			var c = stream.substring(i, i + 1);
			
			switch(c)
			{
				case NODE_OPEN:
					next_is_value = false;  // Make sure the next string is interpreted as a key.
					
					var parsed = _parse(stream, i + 1);
					Reflect.setField(deserialized, laststr, parsed.obj);
					i = parsed.num;
				case NODE_CLOSE:
					return { obj:deserialized, num:i };
				case BR_OPEN:
					var _string:StrNum = _symtostr(stream, i, VDF.BR_CLOSE);
					lastbrk = _string.str;
					i = _string.num;
				case COMMENT:
					if ((i + 1) < stream.length && stream.substring(i + 1, i + 2) == "/")
					{
						i = stream.indexOf("\n", i);
					}
				case CR, LF:
					var ni = i + 1;
					if (ni < stream.length && stream.substring(ni, ni + 1) == LF)
					{
						i = ni;
					}
					if (lasttok != LF)
					{
						c = LF;
					}
				default:
					if (c != SPACE && c != TAB)
					{
						var _string = (c == STRING ? _symtostr(stream, i) : _unquotedtostr(stream, i));
						var string = _string.str;
						i = _string.num;
						
						if (lasttok == STRING && next_is_value)
						{
							if (Reflect.hasField(deserialized, laststr) && lastbrk != null)
							{
								lastbrk = null;  // Ignore this sentry if it's the second bracketed expression
							}
							else
							{
								Reflect.setField(deserialized, laststr, string);
							}
						}
						c = STRING;  // Force c == string so lasttok will be set properly.
						laststr = string;
						next_is_value = !next_is_value;
					}
					else
					{
						c = lasttok;
					}
			}
			lasttok = c;
			i += 1;
		}
		
		return { obj:deserialized, num:i };
	}
	
	private static function _strip(obj:Dynamic,i:Int=0):Dynamic {
		
		//Remove the annoying "num":0 and "obj":{} that litter the parsed data structure
		
		var fields = Reflect.fields(obj);
		
		var len = fields.length;
		for (i in 0...len) {
			var j = len - i - 1;
			
			var v:Dynamic = Reflect.field(obj, fields[j]);
			var t = Type.typeof(v);
			
			var vs:String = Std.string(v);
			
			if (fields[j] == "num") {
				var vi:Int = cast (v);
				if (vi == 0) {
					Reflect.deleteField(obj, fields[j]);
				}
			}
			else if (fields[j] == "obj") {
				if (vs == "{}") {
					Reflect.deleteField(obj, fields[j]);
				}
			}
			
			var fs = Reflect.fields(v);
			if (fs != null && fs.length > 0) {
				_strip(v,i+1);
			}
			
		}
		
		return obj;
	}
	
	private static function _symtostr(line:String, i:Int, token:String = '"'):StrNum
	{
		var opening = i + 1;
		var closing = opening;
		
		var ci = line.indexOf(token, opening);
		
		while (ci != -1)
		{
			if (line.substring(ci - 1, ci) != "\\")
			{
				closing = ci;
				break;
			}
			ci = line.indexOf(token, ci + 1);
		}
		
		var finalstr = line.substring(opening, closing);
		return { str:finalstr, num:(i + finalstr.length + 1) };
	}
	
	private static function _unquotedtostr(line:String, i:Int):StrNum
	{
		var ci = i;
		while (ci < line.length)
		{
			if (WHITESPACE.indexOf(line.substring(ci, ci + 1)) > -1)
			{
				break;
			}
			ci += 1;
		}
		return {str:line.substring(i, ci), num:ci};
	}
}