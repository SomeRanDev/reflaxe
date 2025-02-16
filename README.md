<img src="https://i.imgur.com/oZkCZ2C.png" alt="I made a reflaxe logo thingy look at it LOOK AT IT" width="400"/>

[![Test Workflow](https://github.com/SomeRanDev/reflaxe/actions/workflows/test.yml/badge.svg)](https://github.com/SomeRanDev/reflaxe/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<a href="https://discord.gg/uvq5gPEWCa"><img src="https://discordapp.com/api/guilds/162395145352904705/widget.png?style=shield" alt="Reflaxe Thread"/></a>

*A framework for creating Haxe language compilation targets using macros.*

All you need to worry about is programming the conversion from Haxe's typed AST to your desired programming language. Reflaxe handles organizing the input AST, reading user configuration, and generating the output file(s), while also providing various configuration options and helper functions for Haxe target developers.

[Read the docs here!](https://somerandev.github.io/reflaxe/)

&nbsp;
&nbsp;

## Table of Contents

| Topic | Description |
| --- | --- |
| [Automatic Installation](#automatic-installation) | How to generate a Reflaxe project using the "new" command. |
| [Manual Installation](#manual-installation) | How to install into your library manually. |
| [Building](#building) | How to build for library for submission. |
| [Reflaxe Properties](#reflaxe-properties) | How to configure unique properties for your Reflaxe project. |
| [Compiler Code Sample](/#compiler-code-sample) | How to code the compiler. |
| [CompilerInit Code Sample](/#compiler-init-code-sample) | How to code the init macro call. |
| [extraParams.hxml Sample](/#extraparamshxml-sample) | How to configure your library. |
| [compile.hxml Sample](/#compilerhxml-sample) | How to use your library on other Haxe projects. |
| [BaseCompiler Functions](/#basecompiler-functions) | The functions used to configure your compiler's behavior and code output. |
| [BaseCompiler Options](/#basecompiler-options) | Various options passed to Reflaxe for controlling your compiler's input/output. |

&nbsp;
&nbsp;
&nbsp;

## Automatic Installation
Reflaxe provides an easy script to help get started!

First install Reflaxe using one of the commands below:
```hxml
# install haxelib release
haxelib install reflaxe

# install nightly (recommended!)
haxelib git reflaxe https://github.com/SomeRanDev/reflaxe.git
```

Then run the following command to generate a new Reflaxe project:
```
haxelib run reflaxe new
```

To test your compiler, enter the directory and use `Test.hxml`:
```
cd reflaxe_<langname>
haxelib run reflaxe test
```

&nbsp;
&nbsp;
&nbsp;

## Manual Installation
| # | What to do | What to write |
| - | ------ | ------ |
| 1 | Install via haxelib git. | <pre>haxelib git reflaxe https://github.com/SomeRanDev/reflaxe.git</pre> |
| 2 | Add the lib to your `.hxml` file or compile command. | <pre lang="hxml">-lib reflaxe</pre> |
| 3 | Extend your compiler class from `DirectToStringCompiler`. | <pre lang="haxe">class MyLangCompiler extends reflaxe.DirectToStringCompiler</pre> |

&nbsp;
&nbsp;
&nbsp;

## Building

If you generated your project using the Reflaxe `new` script, you may notice your project has multiple source paths. One is for the compiler code, and the other is used for your language's API. Since Haxelib libraries are only allowed one source path, your project must be "built" before distribution.

To do this, simply run the `build` command:
```
haxelib run reflaxe build
```

This will make a copy of your project in the `_Build/` folder, with all of the API files combined into a single directory. When submitting your project to haxelib, zip the files only in the `_Build` folder and submit that.

&nbsp;
&nbsp;
&nbsp;

## Reflaxe Properties

You can also configure your multiple directories within `haxelib.json`.

Entering into `haxelib.json`, you'll find a new "reflaxe" property that should look something like this:
```json
"reflaxe": {
   "name": "Langauge",
   "abbv": "lang",
   "stdPaths": ["std", "std/lang/_std"]
}
```

You may add as many paths to the "stdPaths" as you like, and these will be combined together upon building the project.

&nbsp;
&nbsp;
&nbsp;

## Compiler Code Sample
For starters, you must fill out the abstract functions from `DirectToStringCompiler` to define how Haxe AST is converted into a String representation of your target language.

```haxe
class MyLangCompiler extends reflaxe.DirectToStringCompiler {
   //---------
   // fill out just these 3 functions and Reflaxe takes care of the rest
   //---------

   public function compileClassImpl(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<String> {
      // ...
   }

   public function compileEnumImpl(enumType: EnumType, options: Array<EnumOptionData>): Null<String> {
      // ...
   }

   public function compileExpressionImpl(expr: TypedExpr, topLevel: Bool): Null<String> {
      // ...
   }
}
```

&nbsp;
&nbsp;
&nbsp;

## Compiler Init Code Sample
Reflaxe projects also require an initialization macro call to setup the various properties for your target. While you can add this "Start" function to your compiler class, the standard for Reflaxe projects is to have this code in a separate class:

```haxe
class MyLangCompilerInit {
   //---------
   // call this from your library's hxml file using --macro
   public static function Start() {
      final options = {
         fileOutputExtension: ".mylang",
         outputDirDefineName: "mylang_out",
         fileOutputType: FilePerClass
      };

      //---------
      // pass an instance of your compiler w/ desired options
      reflaxe.ReflectCompiler.AddCompiler(new MyLangCompiler(), options);
   }
}
```

&nbsp;
&nbsp;
&nbsp;

## `extraParams.hxml` Sample
This framework is expected to be used to create Haxe libraries that "add" an output target. These Haxe libraries are then added to other projects and used to compile Haxe code to the target.

As haxelib only supports one class path per library, combine your class files for the compiler macro classes, target-specific classes, and Haxe standard lib overrides into a single folder.

Your Haxe library using Reflaxe should include an `extraParams.hxml` file that:
* Defines unique definitions for your target for use in conditional compilation.
* Runs an initialization macro similar to the `MyLangCompilerInit.Start` function shown above.
```hxml
-D mylang

--macro MyLangCompilerInit.Start()
```

&nbsp;
&nbsp;
&nbsp;

## `compiler.hxml` Sample
The Haxe project that uses your library must first add it to their `.hxml` file. This will cause the Haxe project to use your custom compiler target. All that is left is to define the "outputDirDefineName" define to configure the directory or filename of the output for your compiler target.

```hxml
# your target will be used when your lib is included
-lib haxe-to-mylang

# set the output directory to "outputDir"
-D mylang_out=outputDir
```

&nbsp;
&nbsp;
&nbsp;

## `BaseCompiler` Options
This is the list of options that can be passed to `ReflectCompiler.AddCompiler` to configure how your compiler works.

While these all have default values, it is recommended `fileOutputExtension` and `outputDirDefineName` are defined for your language at the bare minimum.

```haxe
/**
	How the source code files are outputted.
**/
public var fileOutputType: BaseCompilerFileOutputType = FilePerClass;

/**
	This `String` is appended to the filename for each output file.
**/
public var fileOutputExtension: String = ".hxoutput";

/**
	This is the define that decides where the output is placed.
	For example, this define will place the output in the "out" directory.

	-D hxoutput=out
**/
public var outputDirDefineName: String = "hxoutput";

/**
	If "fileOutputType" is `SingleFile`, this is the name of
	the file generated if a directory is provided.
**/
public var defaultOutputFilename: String = "output";

/**
	A list of type paths that will be ignored and not generated.
	Useful in cases where you can optimize the generation of
	certain Haxe classes to your target's native syntax.

	For example, ignoring `haxe.iterators.ArrayIterator` and
	generating to the target's native for-loop.
**/
public var ignoreTypes: Array<String> = [];

/**
	A list of variable names that cannot be used in the
	generated output. If these are used in the Haxe source,
	an underscore is appended to the name in the output.
**/
public var reservedVarNames: Array<String> = [];

/**
	The name of the function used to inject code directly
	to the target. Set to `null` to disable this feature.
**/
public var targetCodeInjectionName: Null<String> = null;

/**
	If `true`, null-safety will be enforced for all the code
	compiled to the target. Useful for ensuring null is only
	used on types explicitly marked as nullable.
**/
public var enforceNullTyping: Bool = false;

/**
	If `true`, typedefs will be converted to their internal
	class or enum type before being processed and generated.
**/
public var unwrapTypedefs: Bool = true;

/**
	Whether Haxe's "Everything is an Expression" is normalized.
**/
public var normalizeEIE: Bool = true;

/**
	Whether variables of the same name are allowed to be
	redeclarated in the same scope or a subscope.
**/
public var preventRepeatVars: Bool = true;

/**
	Whether variables captured by lambdas are wrapped in
	an `Array`. Useful as certain targets can't capture and
	modify a value unless stored by reference.
**/
public var wrapLambdaCaptureVarsInArray: Bool = false;

/**
	If `true`, during the EIE normalization phase, all
	instances of null coalescence are converted to a
	null-check if statement.
**/
public var convertNullCoal: Bool = false;

/**
	If `true`, during the EIE normalization phase, all
	instances of prefix/postfix increment and decrement
	are converted to a Binop form.

	Helpful on Python-like targets that do not support
	the `++` or `--` operators.
**/
public var convertUnopIncrement: Bool = false;

/**
	When enabled, function properties that are referenced
	as a value will be wrapped in a lambda.

	For example this:
		```haxe
		var fcc = String.fromCharCode
		```
	
	Gets converted to this:
		```haxe
		var fcc = function(i: Int): String {
			return String.fromCharCode(i);
		}
		```
**/
public var wrapFunctionReferences: LambdaWrapType = ExternOnly;

/**
	If `wrapFunctionReferences` is set to either `NativeMetaOnly`
	or `ExternOnly`, the metadata listed here will trigger a
	function to be wrapped in a lambda.

	Metadata that will modify the code that's generated for a
	function at its call-site should be included here.
**/
public var wrapFunctionMetadata: Array<String> = [
	":native",
	":nativeFunctionCode"
];

/**
	If `true`, only the module containing the "main"
	function and any classes it references are compiled.
	Otherwise, Haxe's less restrictive output type list is used.
**/
public var smartDCE: Bool = false;

/**
	If `true`, any std module is only compiled if explicitly
	added during compilation using:
	`BaseCompiler.addModuleTypeForCompilation(ModuleType)`

	Helpful for projects that want to be extremely
	precise with what modules are compiled.

	By default, no modules are compiled when this is enabled,
	`onCompileStart` must be used to decide what will be
	compiled first.
**/
public var dynamicDCE: Bool = false;

/**
	A list of meta attached to "std" classes for the
	custom target. Used to filter these std classes
	for the "Smart DCE" option.
**/
public var customStdMeta: Array<String> = [];

/**
	If `true`, a map of all the ModuleTypes mapped by their
	relevence to the implementation are provided to
	BaseCompiler's compileClass and compileEnum.
	Useful for generating "import-like" content.
**/
public var trackUsedTypes: Bool = false;

/**
	If `true`, functions from `ClassHierarchyTracker` will
	be available for use. This requires some processing
	prior to the start of compilation, so opting out is an option.
**/
public var trackClassHierarchy: Bool = true;

/**
	If `true`, any old output files that are not generated
	in the most recent compilation will be deleted.
	A text file containing all the current output files is
	saved in the output directory to help keep track. 

	This feature is ignored when "fileOutputType" is SingleFile.
**/
public var deleteOldOutput: Bool = true;

/**
	If `false`, an error is thrown if a function without
	a body is encountered. Typically this occurs when
	an umimplemented Haxe API function is encountered.
**/
public var ignoreBodilessFunctions: Bool = false;

/**
	If `true`, extern classes and fields are not passed to `BaseCompiler`.
**/
public var ignoreExterns: Bool = true;

/**
	If `true`, properties that are not physical properties
	are not passed to `BaseCompiler`. (i.e. both their
	read and write rules are "get", "set", or "never").
**/
public var ignoreNonPhysicalFields: Bool = true;

/**
	If `true`, the `@:meta` will be automatically handled
	for classes, enums, and class fields. This meta works
	like it does for Haxe/C#, allowing users to define
	metadata/annotations/attributes in the target output.

	```haxe
	@:meta(my_meta) var field = 123;
	```

	For example, the above Haxe code converts to the below
	output code. Use "autoNativeMetaFormat" to configure
	how the native metadata is formatted.

	```
	[my_meta]
	let field = 123;
	```
**/
public var allowMetaMetadata: Bool = true;

/**
	If "allowMetaMetadata" is enabled, this configures
	how the metadata is generated for the output.
	Use "{}" to represent the metadata content.

	```haxe
	autoNativeMetaFormat: "[[@{}]]"
	```

	For example, setting this option to the String above
	would cause Haxe `@:meta` to be converted like below:

	`@:meta(my_meta)`   -->   `[[@my_meta]]`
**/
public var autoNativeMetaFormat: Null<String> = null;

/**
	A list of metadata unique for the target.

	It's not necessary to fill this out as metadata can
	just be read directly from the AST. However, supplying
	it here allows Reflaxe to validate the meta automatically,
	ensuring the correct number/type of arguments are used.
**/
public var metadataTemplates: Array<{
	meta: haxe.macro.Compiler.MetadataDescription,
	disallowMultiple: Bool,
	paramTypes: Null<Array<MetaArgumentType>>,
	compileFunc: Null<(MetadataEntry, Array<String>) -> Null<String>>
}> = [];
```

test
