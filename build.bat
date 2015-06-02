@echo off
rem build native ndll
cd native
haxelib run hxcpp Build.xml

rem build test exe
rem cd ..
rem cd steamwrap
rem haxe -cp .. Test.hx -main Test -cpp ..\temp\hx

rem cd ..
rem copy temp\hx\Test.exe ndll\Windows
rem copy native\lib\*.dll ndll\Windows
