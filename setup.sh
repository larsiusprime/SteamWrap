#!/bin/bash
function pause(){
   read -p "$*"
}

echo "Enter FULL path (no ~, etc) to Steam SDK root (folder that contains 'redistributable_bin', no trailing slash):"
read STEAMPATH
echo "Enter FULL path (no ~, etc) to hxcpp root (folder that contains '/include', no trailing slash):"
read HXCPP

cp "$STEAMPATH"/public/steam/*.h native/include/steam
cp "$STEAMPATH"/redistributable_bin/steam_api.dll native/lib/win32 > /dev/null
cp "$STEAMPATH"/redistributable_bin/steam_api.lib native/lib/win32 > /dev/null
cp "$STEAMPATH"/redistributable_bin/osx32/libsteam_api.dylib native/lib/osx64 > /dev/null
cp "$STEAMPATH"/redistributable_bin/linux32/libsteam_api.so native/lib/linux32 > /dev/null
cp "$STEAMPATH"/redistributable_bin/linux64/libsteam_api.so native/lib/linux64 > /dev/null
cp "$HXCPP"/include/hx/*.h native/include/hx > /dev/null
