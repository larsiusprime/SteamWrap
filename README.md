SteamWrap
---------
Simple Haxe native extension Steam API wrapper. This code shipped in [Papers, Please](http://papersplea.se) but I can't guarantee robustness. In particular, the stats stuff isn't used much and is not well-tested. Only built against Windows and OSX so far.

Some basic instructions for building a native extension are here: [http://www.joshuagranick.com/blog/?p=566](http://www.joshuagranick.com/blog/?p=566)

#### To build steamwrap.ndll:

1.  Copy the hxcpp headers:
    	
		HAXEDIR/lib/hxcpp/VERSION/include/hx/*.h -> native/include/hx/*.h

2. 	Copy the Steam SDK headers and libs:
		
		STEAMSDK/public/steam/*.h -> native/include/steam/*.h
		STEAMSDK/public/redistributable_bin/steam_api.dll -> native/lib/
		STEAMSDK/public/redistributable_bin/steam_api.lib -> native/lib/
		STEAMSDK/public/redistributable_bin/osx32/libsteam_api.dylib -> native/lib/

3. 	Edit steamwrap/Test.hx to include your Steam App ID

4. 	Run the "build" script (it's a basic haxelib command shortcut). 
	steamwrap.ndll will be output to ndll/[PLATFORM]

5.	Put some files in the built dir (Mac):
		
		ndll/Mac/steam_appid.txt
		STEAMSDK/public/redistributable_bin/steam_api.lib -> ndll/Mac/

6.	Start Steam and run ndll/Mac/Test to confirm that it connects.

#### To include steamwrap.ndll in your OpenFL project:

1. Build the ndll first as above. 

2. Add the following nodes to your NMML.
 ```
    <!-- Replace the question marks with your Steam App ID -->
	<setenv name="STEAM_APP_ID" value="??????" />

    <!-- Supply the relative path to where you put this extension -->
	<include path="../../lib/steamwrap" />
 ```
 
3. If you are doing non steam builds as well, it is practical to wrap this in a conditional. Run your builds as: `openfl test cpp -Dsteam` to enable it.
 ```
	<section if="steam">
		<!-- Steam specifics go here -->
	</section>
 ```

	**!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!**
	
	**This extension will automatically create a steam_appid.txt in your binary folder.**
    **Do not ship your game with this file. Make sure it's stripped during the publishing stage.**
	
	**!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!**

#### Usage:

See steamwrap/Test.hx for a basic example.