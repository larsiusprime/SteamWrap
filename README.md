SteamWrap
---------
Simple Haxe native extension Steam API wrapper. This code originally shipped in [Papers, Please](http://papersplea.se) and the changes in this fork were made for the PC release of [rymdkapsel](http://rymdkapsel.com). Windows, OS X and Linux/SteamOS builds are supported.

#### Current Features:

- Achievements & Leaderboards
- Steam Controller Support
- UGC (user generated content)
- Stats (not well-tested)

~~This repository comes with prebuilt binaries, which means it should work "out of the box".~~

(I'm in the process of updating the binaries, right now all it has is Windows)

#### To include steamwrap.ndll in your OpenFL or NME project:

1. Install the library:

    latest git version:
```haxelib git steamwrap https://github.com/larsiusprime/SteamWrap```
    
2. Add the following nodes to your project.xml (assumes OpenFL or NME for now):
 ```
    <haxelib name="steamwrap"/>
  
    <!-- Replace the question marks with your Steam App ID -->
    <setenv name="STEAM_APP_ID" value="??????" />

    <!-- OS X only: Set this value to the same value as the file property of your <app> node, this is needed to embed things into the generated .app file -->
    <!-- Setting this for other platforms won't do any harm, so you can safely leave it enabled for everything -->
    <set name="APP_FILE" value="??????" />
 ```
 
3. If you are doing non-Steam builds as well, it is practical to wrap this in a conditional. Run your builds as: `openfl test <platform> -Dsteam` to enable it, for example: `openfl test windows -Dsteam`.
 ```
	<section if="steam">
		<!-- Steam specifics go here -->
	</section>
 ```

	**!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!**
	
	**This extension will automatically create a steam_appid.txt in your binary folder.**
	**Do not ship your game with this file. Make sure it's stripped during the publishing stage.**
	
	**Compiling with the "-Dfinal" flag should suppress creation of the steam_appid.txt**
	
	```openfl test windows -Dsteam -Dfinal``` (for instance)
	
	**!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!**

#### Usage:

See steamwrap/example/Test.hx for a basic example.

#### To build steamwrap.ndll from source:

**Automatic steps**

1. Run setup.bat and enter the values it asks you for
   - This only works when run from windows

Or you can set it up manually:

------------

**Manual steps:**

1. Copy the hxcpp headers:
    	
		HAXE_DIR/lib/hxcpp/VERSION/include/hx/*.h -> STEAMWRAP_DIR/native/include/hx/*.h

2. Copy the Steam SDK headers and libs:
		
		STEAMSDK_DIR/public/steam/*.h -> native/include/steam/*.h
		STEAMSDK_DIR/redistributable_bin/steam_api.dll -> native/lib/win32/
		STEAMSDK_DIR/redistributable_bin/steam_api.lib -> native/lib/win32/
		STEAMSDK_DIR/redistributable_bin/osx32/libsteam_api.dylib -> native/lib/osx64/
		STEAMSDK_DIR/redistributable_bin/linux32/libsteam_api.so -> native/lib/linux32/
		STEAMSDK_DIR/redistributable_bin/linux64/libsteam_api.so -> native/lib/linux64/

3. Put some files in the build dir (Mac):

	Windows:
	```
		ndll/Windows/steam_appid.txt
		STEAMSDK_DIR/redistributable_bin/steam_api.dll -> ndll/Windows
	```

	Mac:
	```
		ndll/Mac64/steam_appid.txt
		STEAMSDK_DIR/redistributable_bin/steam_api.lib -> ndll/Mac64/
	```

	Linux:
	```
		ndll/Linux/steam_appid.txt
		STEAMSDK_DIR/redistributable_bin/steam_api.so -> ndll/Linux/
		
		ndll/Linux64/steam_appid.txt
		STEAMSDK_DIR/redistributable_bin/steam_api.so -> ndll/Linux64/
	```

	**WHAT THIS DOES:**
	
	The steam_api dll/dylib/so file must be next to your platform's steamwrap.ndll file in order for the extension to 		work. The dll/dylib/so file has all of the actual Steam API functionality, and the ndll file allows your Haxe 			project to communicate with it.
	
	As for the `steam_appid.txt` file, it's only there to make the "Test" program work. That's because the "Test" program 	will appear in your platform's ndll/<Platform> folder when you use the "build.bat" or "build" script to compile it.
	
	In order for your test program to work it must be able to find:
	  - steamwrap.ndll (so Haxe can talk to Steam)
	  - steam_api.dll/dylib/so (to provide the Steam API)
	  - steam_appid.txt (to make the Steam Client recognize your app as a particular Steam Game when testing)
	  
------------

**Final Steps:**

1. Run the "build" script (it's a basic haxelib command shortcut). 
	steamwrap.ndll will be output to ndll/[PLATFORM]

	That's great, but we want to make sure it works! Let's run something with it. If you run the Test program now, you'll notice it exits immediately, asking you to supply an app ID.

2. Edit steamwrap/example/Test.hx to include your Steam App ID and achievement ID's, etc.

	Now you are ready to compile example/Test.hx.

3. Start the Steam client, leave it open in the background, and run the Test app to make sure it connects.

	

