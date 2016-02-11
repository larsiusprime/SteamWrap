@echo off

:: build the native ndll

cd native
haxelib run hxcpp Build.xml

cd ..

copy native\lib\win32\*.dll ndll\Windows

:: build the Text.exe 
:: (uncomment the lines below to build the Test program after you've set it up properly)

::cd example
::haxe -cp .. Test.hx -main Test -cpp ..\temp\hx
::cd ..

::copy temp\hx\Test.exe ndll\Windows

