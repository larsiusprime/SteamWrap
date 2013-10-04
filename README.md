SteamWrap
---------
Simple Haxe native extension Steam API wrapper. This code shipped in [Papers, Please](http://papersplea.se) but I can't guarantee robustness. In particular, the stats stuff isn't used much and is not well-tested. Only built against Windows and OSX so far.

Some basic instructions for building a native extension are here: [http://www.joshuagranick.com/blog/?p=566](http://www.joshuagranick.com/blog/?p=566)

#### To build steamwrap.ndll:

1.  Copy the hxcpp headers:
		
		HAXEDIR/lib/hxcpp/VERSION/include/hx/*.h -> native/include/hx/*.h

2. 	Copy the Steam SDK headers and libs:
		
		STEAMSDK/public/steam/*.h -> native/include/steam/*.h
		STEAMSDK/public/redistributable_bin/steam_api.dll -> native/include/lib/
		STEAMSDK/public/redistributable_bin/steam_api.lib -> native/include/lib/
		STEAMSDK/public/redistributable_bin/osx32/libsteam_api.dylib -> native/include/lib/

3. 	Edit steamwrap/Test.hx to include your Steam App Id

4. 	Run the "build" script (it's a basic haxelib command shortcut). 
	steamwrap.ndll will be output to ndll/[PLATFORM]

5.	Put some files in the built dir (Mac):
		
		ndll/Mac/steam_appid.txt
		STEAMSDK/public/redistributable_bin/steam_api.lib -> ndll/Mac/

6.	Start Steam and run ndll/Mac/Test to confirm that it connects.

#### To include steamwrap.ndll in your OpenFL project:

1. Build the ndll first as above. 
(Assuming it goes into a subdirectory of your project named "SteamWrap")

2. Add include rules to copy steam libs as assets. This is the Project.hx code; if you're using project.xml, create <assets> nodes with the same info and conditions.

	```
	if (target == Platform.MAC)
	{
		// @@ hack to get dylib copied over
	    	assets.push(new Asset("SteamWrap/ndll/steam_appid.txt", "../MacOS/steam_appid.txt", AssetType.BINARY));
	    	assets.push(new Asset("SteamWrap/ndll/Mac/libsteam_api.dylib", "../MacOS/libsteam_api.dylib", AssetType.BINARY));
	}
	else if (target == Platform.WINDOWS)
	{
	    	// @@ hack to get dll copied over
	    	assets.push(new Asset("SteamWrap/ndll/steam_appid.txt", "steam_appid.txt", AssetType.BINARY));
	    	assets.push(new Asset("SteamWrap/native/lib/steam_api.dll", "steam_api.dll", AssetType.BINARY));
	}
	```

	**!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!**
	
	**Don't ship your game with steam_appid.txt. Make sure it's stripped during the publishing stage.**
	
	**!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!**

3. Add the extension to your project.xml:

	&lt;extension name="steamwrap" path="./SteamWrap" /&gt;
	(or possibly &lt;extension path="./SteamWrap/include.nmml" /&gt;)
	
#### Usage:

See steamwrap/Test.hx for a basic example.
