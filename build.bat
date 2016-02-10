@echo off
rem build native ndll
cd native
haxelib run hxcpp Build.xml

rem build test exe
cd ..

cd steamwrap
haxe -cp .. Test.hx -main Test -cpp ..\temp\hx
cd ..

copy temp\hx\Test.exe ndll\Windows
copy native\lib\*.dll ndll\Windows

