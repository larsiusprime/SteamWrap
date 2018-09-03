@echo off

:: build the native ndll

cd native

haxelib run hxcpp Build.xml

cd ..

copy native\lib\win32\*.dll ndll\Windows


:: build the 64-bit native ndll

cd native

haxelib run hxcpp Build.xml -DHXCPP_M64

cd ..

copy native\lib\win64\*.dll ndll\Windows64


:: build the example program "Test.exe"

cd example
haxe -cp .. Test.hx -main Test -cpp ..\temp\hx
cd ..

copy temp\hx\Test.exe ndll\Windows

cd example
haxe -cp .. Test.hx -main Test -cpp ..\temp64\hx -D HXCPP_M64=1
cd ..

copy temp64\hx\Test.exe ndll\Windows64
