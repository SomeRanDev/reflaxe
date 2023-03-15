# Reflaxe Test

This "test" project functions as both a test and a template project for starting to work with Reflaxe. Feel free to copy the code here, and modify it as you please to get started on your Reflaxe project! 

The project compiles Haxe into "TestScript", a simple, fake language based on Python, created to demonstrate how Reflaxe works.

Run this following command to compile into TestScript:
```
haxe Test.hxml
```

## TestCompiler.hx

The entire compiler used for this project is contained in `TestCompiler.hx`. It's recommended you split up the functions into different files for better organization, but keeping it all in one class is an option too.

## MyClass.hx

This is the Haxe code that is "compiled" into our fake "TestScript" language. Modify this Haxe code to see how it translates into the new language.

## std/

This folder is where our "TestScript" standard library is contained. During testing, we add this class path to allow for special, TestScript-unqiue Haxe classes.

There is also the `std/testscript/_std` folder. This is also added to the class path, and is used to override the default Haxe API classes like the other Haxe targets do to configure them. At the bare minimum you'll probably need to write a custom version of `String`, `Map`, `Array` for full syntax support, and `Math`, `Std`, `Sys`, `EReg`, `Reflect`, `Type`, and `haxe/Log` for full Haxe API support.

## out/

The "TestScript" output is placed here.
