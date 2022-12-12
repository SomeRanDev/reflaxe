# Reflaxe - Reflection Compiler for Haxe
A framework for creating Haxe language compilation targets using macros.

All you need to worry about is programming the conversion from Haxe's typed AST to your desired programming language. Reflaxe handles organizing the input AST, reading user configuration, and generating the output file(s), while also providing various configuration options and helper functions for Haxe target developers.

&nbsp;
&nbsp;

## Table of Contents

| Topic | Description |
| --- | --- |
| [Installation](https://github.com/RobertBorghese/reflaxe#installation) | How to install into your library. |
| [Compiler Code Sample](https://github.com/RobertBorghese/reflaxe/#compiler-code-sample) | How to code the compiler. |
| [extraParams.hxml Sample](https://github.com/RobertBorghese/reflaxe/#extraparamshxml-sample) | How to configure your library. |
| [compile.hxml Sample](https://github.com/RobertBorghese/reflaxe/#compilerhxml-sample) | How to use your library on other Haxe projects. |
| [BaseCompiler Functions](https://github.com/RobertBorghese/reflaxe/#basecompiler-functions) | The functions used to configure your compiler's behavior and code output. |
| [BaseCompiler Options](https://github.com/RobertBorghese/reflaxe/#basecompiler-options) | Various options passed to Reflaxe for controlling your compiler's input/output. |

&nbsp;
&nbsp;
&nbsp;

## Installation
| # | What to do | What to write |
| - | ------ | ------ |
| 1 | Install via haxelib. | <pre>haxelib install reflaxe</pre> |
| 2 | Add the lib to your `.hxml` file or compile command. | <pre lang="hxml">-lib reflaxe</pre> |
| 3 | Extend your compiler class from `BaseCompiler`. | <pre lang="haxe">class MyLangCompiler extends reflaxe.BaseCompiler</pre> |

&nbsp;
&nbsp;
&nbsp;

## Compiler Code Sample
Now fill out the abstract functions from `BaseCompiler` to define how Haxe AST is converted into a String representation of your target language.

```haxe
class MyLangCompiler extends reflaxe.BaseCompiler {

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

   //---------
   // fill out just these 3 functions and Reflaxe takes care of the rest
   //---------

   public function compileClassImpl(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String> {
      // ...
   }

   public function compileEnumImpl(enumType: EnumType, constructs: Map<String, haxe.macro.EnumField>): Null<String> {
      // ...
   }

   public function compileExpressionImpl(expr: TypedExpr): Null<String> {
      // ...
   }
}
```

&nbsp;
&nbsp;
&nbsp;

## `extraParams.hxml` Sample
This framework is expected to be used to create Haxe libraries that "add" an output target. These Haxe libraries are then added to other projects and used to compile Haxe code to the target.

Your Haxe library using Reflaxe should include an `extraParams.hxml` file that:
* Includes class paths for your target's unique classes and Haxe standard lib overrides.
* Defines unique definitions for your target for use in conditional compilation.
* Runs an initialization macro similar to the `MyLangCompiler.Start` function shown above.
```hxml
-cp std
-cp std/mylang/_std

-D mylang

--macro MyLangCompiler.Start()
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

## `BaseCompiler` Functions
Here is a list of the relevant `BaseCompiler` functions and typedefs.

```haxe
//---------
// These are the typedefs passed to "compileClass"
typedef ClassFieldVars = Array<{ isStatic: Bool, read: VarAccess, write: VarAccess, field: ClassField }>;
typedef ClassFieldFuncs = Array<{ isStatic: Bool, kind: MethodKind, tfunc: TFunc, field: ClassField }>;

//---------
// BaseCompiler abstract class
abstract class BaseCompiler {
   //---------
   // This function is given data about Haxe classes. It must either return a String of
   // the source code this class generates, or `null` if the class should be ignored.
   public abstract function compileClassImpl(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String>;
   
   //---------
   // Similar to "compileClass", except used for Haxe enums.
   public abstract function compileEnumImpl(classType: EnumType, constructs: Map<String, EnumField>): Null<String>;
   
   //---------
   // Given the `TypedExpr`, this function should return a String of the generated
   // expression for the output language.
   // Returning `null` causes the compiler to ignore this expression.
   public abstract function compileExpressionImpl(expr: TypedExpr): Null<String>;

   //---------
   // Typedef and Abstract compiling functions are also included, but they are ignored
   // by default. They can be overriden if desired.
   public function compileTypedefImpl(classType: DefType): Null<String> { return null; }
   public function compileAbstractImpl(classType: AbstractType): Null<String> { return null; }
   
   // ---
   
   //---------
   // Normally this function is unused, however if "Manual" mode is selected for
   // "fileOutputType", this function is called and Reflaxe does not generate any
   // output itself. If you wish for more control over how files are generated with
   // your custom Haxe target, this is the function for you.
   public function generateFilesManually() {}
   
   // ---
   
   //---------
   // These functions are created in Reflaxe and should not be overriden.
   // They should be used in "compileClass" to compile the expressions from functions
   // and variables as opposed to using "compileExpression" on them directly.
   public function compileClassVarExpr(expr: TypedExpr): String { ... }
   public function compileClassFuncExpr(expr: TypedExpr): String { ... }
   
   //---------
   // Use this to compile sub-expressions in compileExpressionImpl
   public function compileExpression(expr: TypedExpr): Null<String> { ... }
}
```

&nbsp;
&nbsp;
&nbsp;

## `BaseCompiler` Options
This is the list of options that can be passed to `ReflectCompiler.AddCompiler` to configure how your compiler works.

While these all have default values, it is recommended `fileOutputExtension`, `requireDefine`, and `outputDirDefineName` should be defined for your language at the bare minimum.

```haxe
// -------------------------------------------------------
// How the source code files are outputted.
// There are four options: 
//  * SingleFile - all output is combined into single file
//  * FilePerModule - all module output is organized into files
//  * FilePerClass - each Haxe class is output into its own file
//  * Manual - nothing is generated and BaseCompiler.generateFilesManually is called
public var fileOutputType: BaseCompilerFileOutputType = FilePerClass;

// -------------------------------------------------------
// This string is appended to the filename for each output file.
public var fileOutputExtension: String = ".hxoutput";

// -------------------------------------------------------
// This is the define that decides where the output is placed.
// For example, this define will place the output in the "out" directory.
//
// -D hxoutput=out
//
public var outputDirDefineName: String = "hxoutput";

// -------------------------------------------------------
// If "SingleFile" is selected for "fileOutputType", this is the
// name of the file generated if a directory is provided to "outputDirDefineName".
public var defaultOutputFilename: String = "output";

// -------------------------------------------------------
// A list of type paths that will be ignored and not generated.
// Useful in cases where you can optimize the generation of
// certain Haxe classes to your target's native syntax.
//
// For example, ignoring `haxe.ArrayIterator` and generating
// to the target's native for-loop.
public var ignoreTypes: Array<String> = [];

// -------------------------------------------------------
// The name of the function used to inject code directly to the target.
// Set to `null` to disable this feature.
public var targetCodeInjectionName: Null<String> = null;

// -------------------------------------------------------
// If "true", null safety will be enforced for all the code
// compiled to the target. Useful for ensuring null is only
// used on types explicitly marked as nullable.
public var enforceNullSafety: Bool = true;

// -------------------------------------------------------
// Whether Haxe's "Everything is an Expression" is normalized.
public var normalizeEIE: Bool = true;

// -------------------------------------------------------
// If "true", only the module containing the "main" function and 
// any classes it references are compiled.
// Otherwise, Haxe's less restrictive dce is used.
public var smartDCE: Bool = false;

// -------------------------------------------------------
// If "true", any old output files that are not generated
// in the most recent compilation will be deleted.
// A text file containing all the current output files is
// saved in the output directory to help keep track. 
//
// This feature is ignored when "fileOutputType" is SingleFile.
public var deleteOldOutput: Bool = true;

// -------------------------------------------------------
// If "true", an error is thrown if a function without
// a body is encountered. Typically this occurs when
// an umimplemented Haxe API function is encountered.
public var ignoreBodilessFunctions: Bool = false;

// -------------------------------------------------------
// If "true", extern classes and fields are not passed to BaseCompiler.
public var ignoreExterns: Bool = true;

// -------------------------------------------------------
// If "true", properties that are not physical properties
// are not passed to BaseCompiler. (i.e. both their
// read and write rules are "get", "set", or "never").
public var ignoreNonPhysicalFields: Bool = true;
```
