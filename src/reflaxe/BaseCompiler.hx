package reflaxe;

#if (macro || reflaxe_runtime)

import reflaxe.helpers.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.compiler.MetadataCompiler;
import reflaxe.compiler.TypeUsageTracker;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.output.DataAndFileInfo;
import reflaxe.output.OutputManager;
import reflaxe.output.OutputPath;
import reflaxe.output.StringOrBytes;
import reflaxe.preprocessors.ExpressionPreprocessor;

using StringTools;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ClassTypeHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

/**
	An enum for dictating how the compiler outputs the
	target source files.
**/
enum BaseCompilerFileOutputType {
	/**
		Do not automatically generate output.
	**/
	Manual;

	/**
		All output is combined into a single output file.
	**/
	SingleFile;

	/**
		A new source file is generated for each Haxe module.
		Each file will contain at least one class, maybe more.
	**/
	FilePerModule;

	/**
		A new source file is generated for each Haxe class.
	**/
	FilePerClass;
}

/**
	A structure that contains all the options for
	configuring the `BaseCompiler`'s behavior.
**/
@:structInit
class BaseCompilerOptions {
	/**
		The "preprocessors" applied to the expressions of functions and
		variables before being provided to the user's compiler.

		Leave this as `null` to use the default setup provided by the
		function: `ExpressionPreprocessorHelper.defaults`.
	**/
	public var expressionPreprocessors: Null<Array<ExpressionPreprocessor>> = null;

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
		to the target. This only works when extending from the
		`DirectToStringCompiler` class.

		Set to `null` to disable this feature.
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
		If `true`, ONLY the following is compiled by default:
		- Modules with `@:keep`
		- Modules and packages passed as Haxe arguments.

		To add more types to the queue, this function should
		be used during compilation:
		`BaseCompiler.addModuleTypeForCompilation(ModuleType)`

		Helpful for projects that want to be extremely
		precise with what modules are compiled.

		Compiling the main function/module needs to be done
		manully in `onCompileStart`. It can be obtained in
		both forms using the following functions:
		```haxe
		BaseCompiler.getMainExpr(): Null<TypedExpr>;
		BaseCompiler.getMainModule(): Null<ModuleType>;
		```
	**/
	public var manualDCE: Bool = false;

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
		If `true`, extern classes and fields are not passed to BaseCompiler.
	**/
	public var ignoreExterns: Bool = true;

	/**
		If `true`, properties that are not physical properties
		are not passed to BaseCompiler. (i.e. both their
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
}

/**
	The metadata argument type that can be configured
	in "metadataTemplates" for `BaseCompilerOptions`.
**/
enum abstract MetaArgumentType(String) to String {
	var Bool = "bool";
	var Number = "number";
	var String = "string";
	var Identifier = "ident";
	var Array = "array";
	var Anything = "any";
	var Optional = "any?";
}

/**
	The super class all compilers should extend from.
	The behavior of how the Haxe AST is transpiled is
	configured by implementing the abstract methods.
**/
abstract class BaseCompiler {
	// =======================================================
	// * Conditional Overridables
	//
	// Override these in custom compiler to filter types.
	// =======================================================

	/**
		A function intended to be overriden by your compiler class.

		This is called once at the start of compilation.

		`moduleTypes` is an array of ALL types supplied by the Haxe
		compiler. Removing (or adding?) entries from this will
		change what modules are sent to your compiler.

		`moduleTypes` is a unique copy made specifically for this
		function, so it is safe to modify directly and return it.

		To enable the exact behavior supplied by the deprecated
		`smartDCE` option, the following code can be used:
		```haxe
		public override function filterTypes(moduleTypes: Array<ModuleType>): Array<ModuleType> {
			final tracker = new reflaxe.input.ModuleUsageTracker(moduleTypes, this);
			return tracker.filteredTypes(this.options.customStdMeta);
		}
		```
	**/
	public function filterTypes(moduleTypes: Array<ModuleType>): Array<ModuleType> {
		return moduleTypes;
	}

	/**
		A function intended to be overriden by your compiler class.

		This is called at the start of compilation for each class.

		If `false` is returned, the class will not be sent to your
		compiler later.
	**/
	public function shouldGenerateClass(cls: ClassType): Bool {
		if(cls.isTypeParameter()) {
			return false;
		}
		if(cls.isExprClass()) {
			return false;
		}
		return !cls.isReflaxeExtern() || !options.ignoreExterns;
	}

	/**
		A function intended to be overriden by your compiler class.

		This is called at the start of compilation for each enum.

		If `false` is returned, the enum will not be sent to your
		compiler later.
	**/
	public function shouldGenerateEnum(enumType: EnumType): Bool {
		return !enumType.isReflaxeExtern() || !options.ignoreExterns;
	}

	/**
		A function intended to be overriden by your compiler class.

		This is called at the start of compilation for each class field.

		If `false` is returned, a `ClassFuncData` or `ClassVarData` will
		not be generated for the field. The field will still be accessible
		from the `ClassType` however.
	**/
	public function shouldGenerateClassField(cls: ClassField): Bool {
		return true;
	}
	
	// =======================================================
	// * Conditional Events
	//
	// Override these in custom compiler to handle certain events.
	// =======================================================
	public function onCompileStart() {}
	public function onCompileEnd() {}
	public function onOutputComplete() {}
	public function onClassAdded(cls: ClassType, output: Null<String>): Void {}
	public function onEnumAdded(cls: EnumType, output: Null<String>): Void {}
	public function onTypedefAdded(cls: DefType, output: Null<String>): Void {}
	public function onAbstractAdded(cls: AbstractType, output: Null<String>): Void {}

	// =======================================================
	// * Compile-End Callbacks
	//
	// Functions accumulated while compiling to call upon completion.
	// =======================================================
	public var compileEndCallbacks(default, null): Array<() -> Void> = [];

	/**
		Calls the provided callback at the end of compilation.
		Useful for running code upon compiling a class or expression that will
		be able to make decisions based on the final state of the compiler.

		I.e: Adding reflection code only if a reflection function is used.
	**/
	function addCompileEndCallback(callback: () -> Void) {
		compileEndCallbacks.push(callback);
	}

	// =======================================================
	// * new
	// =======================================================
	public function new() {}

	// =======================================================
	// * err
	// =======================================================
	function err(msg: String, pos: Null<Position> = null): Dynamic {
		#if eval
		if(pos == null) pos = Context.currentPos();
		return Context.error(msg, pos);
		#else
		return null;
		#end
	}

	// =======================================================
	// * Options
	// =======================================================
	public var options(default, null): BaseCompilerOptions = {};
	public var expressionPreprocessors(default, null): Array<ExpressionPreprocessor> = [];

	public function setOptions(options: BaseCompilerOptions) {
		this.options = options;
		this.expressionPreprocessors = (
			options.expressionPreprocessors ?? ExpressionPreprocessorHelper.defaults()
		);

		setupReservedVarNames();
	}

	// =======================================================
	// * Output Directory
	// =======================================================
	public var output(default, null): Null<OutputManager> = null;

	/**
		Used to configure how output is generated automatically.
	**/
	public abstract function generateOutputIterator(): Iterator<DataAndFileInfo<StringOrBytes>>;

	/**
		Sets the directory files will be generated in.
	**/
	public function setOutputDir(outputDir: String) {
		if(this.output == null) {
			this.output = new OutputManager(this);
		}
		this.output.setOutputDir(outputDir);
	}

	/**
		Generates the output.
	**/
	public function generateFiles() {
		if(this.output != null) {
			this.output.generateFiles();
		} else {
			err("Attempted to output without being assigned destination.");
		}
	}

	/**
		A function intended to be overriden by your compiler class.

		This is called once at the end of compilation if
		`options.fileOutputType` is set to `Manual`.

		This is where you can generate your output files manually
		instead of relying on Reflaxe's default output system.

		Files should be saved using `output.saveFile(path, content)`
	**/
	public function generateFilesManually() {
	}

	// =======================================================
	// * Extra Files
	// =======================================================
	public var extraFiles(default, null): Map<String, Map<Int, String>> = [];

	/**
		Set all the content for an arbitrary file added to the
		output folder.
	**/
	public function setExtraFile(path: OutputPath, content: String = "") {
		extraFiles.set(path.toString(), [0 => content]);
	}

	/**
		Check if an extra file exists.
	**/
	public function extraFileExists(path: OutputPath): Bool {
		final pathString = path.toString();
		return extraFiles.exists(pathString);
	}

	/**
		Set all the content for a file if it doesn't exist yet.
	**/
	public function setExtraFileIfEmpty(path: OutputPath, content: String = "") {
		if(!extraFileExists(path)) {
			setExtraFile(path, content);
		}
	}

	/**
		Returns the contents of the file if it exists.

		`priority` dictates where the content is appended relative to
		other calls to these functions.

		Returns an empty string if nothing exists.
	**/
	public function getExtraFileContent(path: OutputPath, priority: Int = 0): String {
		final pathString = path.toString();
		return if(!extraFiles.exists(pathString)) {
			"";
		} else {
			final current = extraFiles.get(pathString);
			if(current != null) {
				current.exists(priority) ? (current[priority] ?? "") : "";
			} else {
				"";
			}
		}
	}

	/**
		Set the content or append it if it already exists.

		`priority` dictates where the content is appended relative to
		other calls to these functions.
	**/
	public function replaceInExtraFile(path: OutputPath, content: String, priority: Int = 0) {
		final pathString = path.toString();
		if(!extraFiles.exists(pathString)) {
			extraFiles.set(pathString, []);
		}
		final current = extraFiles.get(pathString);
		if(current != null) {
			current[priority] = content;
			extraFiles.set(pathString, current);
		}
	}

	/**
		Set the content or append it if it already exists.

		`priority` dictates where the content is appended relative to
		other calls to these functions.
	**/
	public function appendToExtraFile(path: OutputPath, content: String, priority: Int = 0) {
		replaceInExtraFile(path, getExtraFileContent(path, priority) + content, priority);
	}

	// =======================================================
	// * File Placement Overrides
	// =======================================================
	var fileNameOverride: Null<String> = null;
	var fileDirOverride: Null<String> = null;

	/**
		Use while compiling a module type (typically through one of the
		`BaseCompiler` override methods like `compileClassImpl`) to set
		the name of the file that will contain the output being generated.

		Setting to an empty `String` or `null` will result in the default
		file name being used.
	**/
	public function setOutputFileName(name: Null<String>) {
		fileNameOverride = name;
	}

	/**
		Use while compiling a module type (typically through one of the
		`BaseCompiler` override methods like `compileClassImpl`) to set
		the name of the file that will contain the output being generated.

		Subdirectories can be used with the forward slash.

		Setting to an empty `String` or `null` will result
		in the file being generated in the top directory
		(the output directory).
	**/
	public function setOutputFileDir(dir: Null<String>) {
		fileDirOverride = dir;
	}

	/**
		Returns the "main" typed expression for the program.

		For example, if `-main MyClass` is set in the project, the expression
		will be: `MyClass.main()`.

		Please note if using Haxe v4.2.5 or below, the main class must be
		defined using `-D mainClass`. For example: `-D mainClass=MyClass`.
	**/
	public function getMainExpr(): Null<TypedExpr> {
		#if macro
		return Context.getMainExpr();
		#else
		return null;
		#end
	}

	/**
		Extracts the `ModuleType` of the main class based on `getMainExpr` function.
	**/
	public function getMainModule(): Null<ModuleType> {
		final mainExpr = getMainExpr();

		if(mainExpr == null) {
			return null;
		}

		// The main expression should(?) always be a call to a static function.
		return switch(mainExpr.expr) {
			case TCall(callExpr, _): {
				switch(callExpr.expr) {
					case TField(_, fa): {
						switch(fa) {
							case FStatic(clsRef, _): TClassDecl(clsRef);
							case _: null;
						}
					}
					case _: null;
				}
			}
			case _: null;
		}
	}

	/**
		Store and reference the typeUsage Map for the current class or
		enum being compiled.
	**/
	var typeUsage: Null<TypeUsageMap> = null;

	public function getTypeUsage(): Null<TypeUsageMap> {
		return typeUsage;
	}

	/**
		Stores a reference to the ModuleType currently being compiled.
	**/
	var currentModule: Null<ModuleType> = null;

	/**
		Public getter for `currentModule`.
	**/
	public function getCurrentModule(): Null<ModuleType> {
		return currentModule;
	}

	/**
		Called before compileClass, compileEnum, etc. to set up
		fields to be referenced.
	**/
	public function setupModule(mt: Null<ModuleType>) {
		currentModule = mt;
		typeUsage = (mt != null && options.trackUsedTypes) ? TypeUsageTracker.trackTypesInModuleType(mt) : null;
	}

	/**
		A function required to be overriden by your compiler class.

		Compiles the provided class. Defined in `GenericCompiler`.
		Override this to configure the behavior.
	**/
	public abstract function compileClass(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Void;

	/**
		A function required to be overriden by your compiler class.

		Compiles the provided enum. Defined in `GenericCompiler`.
		Override this to configure the behavior.
	**/
	public abstract function compileEnum(enumType: EnumType, options: Array<EnumOptionData>): Void;

	/**
		A function intended to be overriden by your compiler class.

		Compiles the provided typedef. Defined in `GenericCompiler`.
		It ignores all typedefs by default since Haxe redirects all types automatically.
	**/
	public abstract function compileTypedef(classType: DefType): Void;

	/**
		A function intended to be overriden by your compiler class.

		Compiles the provided abstract. Defined in `GenericCompiler`.
		It ignores all abstracts by default since Haxe converts them to function calls.
	**/
	public abstract function compileAbstract(classType: AbstractType): Void;

	// =======================================================
	// * Reserved Variable Names
	// =======================================================
	var reservedVarNameMap: Null<Map<String, Bool>> = null;

	/**
		Moves the `options.reservedVarNames` values into a `Map`.
	**/
	function setupReservedVarNames() {
		if(options.reservedVarNames.length == 0) return;

		reservedVarNameMap = [];
		for(name in options.reservedVarNames) {
			reservedVarNameMap[name] = true;
		}
	}

	/**
		Manually adds a reserved variable name that cannot be used
		in the output.
	**/
	public function addReservedVarName(name: String) {
		if(reservedVarNameMap == null) {
			reservedVarNameMap = [];
		}
		reservedVarNameMap[name] = true;
	}

	/**
		Compiles the provided variable name.
		Ensures it does not match any of the reserved variable names.
	**/
	public function compileVarName(name: String, expr: Null<TypedExpr> = null, field: Null<ClassField> = null): String {
		if(reservedVarNameMap != null) {
			while(reservedVarNameMap.exists(name)) {
				name = "_" + name;
			}
		}
		return name;
	}

	/**
		Compiles the Haxe metadata to the target's equivalent.

		This function will always return `null` unless  `allowMetaMetadata`
		is `true` or `metadataTemplates` contains at least one entry.
	**/
	public function compileMetadata(metaAccess: Null<MetaAccess>, target: haxe.display.Display.MetadataTarget): Null<String> {
		return MetadataCompiler.compileMetadata(options, metaAccess, target);
	}

	/**
		Each expression is assigned a "type" (represented by an `Int`).

		When generating code, expressions of the same type are kept close together,
		while expressions of different types are separated by a new line.

		This helps make the code output look human-written.
		Used in `compileExpressionsIntoLines`.

		This can be overriden if you want.
	**/
	function expressionType(expr: Null<TypedExpr>): Int {
		if(expr == null) {
			return 0;
		}
		return switch(expr.expr) {
			case TConst(_) |
				TLocal(_) |
				TArray(_, _) |
				TVar(_, _) |
				TTypeExpr(_) |
				TEnumParameter(_, _, _) |
				TEnumIndex(_) |
				TIdent(_): 0;
			
			case TBinop(_, _, _) |
				TCall(_, _) |
				TUnop(_, _, _) |
				TCast(_, _) |
				TField(_, _): 1;
			
			case TObjectDecl(_): 2;
			case TArrayDecl(_): 3;
			case TNew(_, _, _): 4;
			case TFunction(_): 5;
			case TBlock(_): 6;
			case TFor(_, _, _): 7;
			case TIf(_, _, _): 8;
			case TWhile(_, _, _): 9;
			case TSwitch(_, _, _): 10;
			case TTry(_, _): 11;
			case TReturn (_): 12;
			case TBreak | TContinue: 13;
			case TThrow(_): 14;
			case TMeta(_, e): expressionType(e);
			case TParenthesis(e): expressionType(e);
		}
	}

	/**
		Used internally with `addModuleTypeForCompilation` for the `manualDCE` option.

		A stack of `ModuleType`s yet to be processed.
	**/
	public var dynamicTypeStack: Array<ModuleType> = [];

	/**
		Used internally with `addModuleTypeForCompilation` for the `manualDCE` option.

		A list of `ModuleType` unique identifiers that have been queued once.
	**/
	public var dynamicTypesHandled: Array<String> = [];

	/**
		This function is to be used in conjunction with the `manualDCE` option.

		With `manualDCE` enabled, types encountered while compiling should
		be passed to this function to be added to the compilation queue.

		Any repeats will NOT be re-queued, you are safe (as expected) to spam
		this function as much as you want.

		You should essentially call this for:
		 - The type of every variable compiled.
		 - The type of every expression compiled.
		 - All argument and return types for every function compiled.

		Use `addTypeForCompilation` to pass a `haxe.macro.Type` instead.
	**/
	public function addModuleTypeForCompilation(mt: ModuleType) {
		final id = mt.getUniqueId();
		if(!dynamicTypesHandled.contains(id)) {
			dynamicTypesHandled.push(id);
			dynamicTypeStack.push(mt);
		}
	}

	/**
		See `addModuleTypeForCompilation`.

		Works the same as `addModuleTypeForCompilation` but takes a 
		`haxe.macro.Type` instead of `haxe.macro.ModuleType`.

		Returns `false` if the `haxe.macro.Type` couldn't be converted
		to `haxe.macro.ModuleType`.
	**/
	public function addTypeForCompilation(type: Type): Bool {
		final moduleType = type.toModuleType();
		if(moduleType != null) {
			addModuleTypeForCompilation(moduleType);
			return true;
		}
		return false;
	}

	/**
		Used in `compileNativeFunctionCodeMeta` and `compileNativeTypeCodeMeta`.
	**/
	function extractStringFromMeta(meta: MetaAccess, name: String): Null<{ entry: MetadataEntry, code: String }> {
		return if(meta.maybeHas(name)) {
			final entry = meta.maybeExtract(name)[0];

			// Prevent null safety error from `entry.params`.
			@:nullSafety(Off)
			if(entry == null || entry.params == null || entry.params.length == 0) {
				#if eval
				Context.error("One string argument expected containing the native code.", entry.pos);
				#end
				return null;
			}

			// Prevent null safety error from `entry.params[0]` as function will return if `entry.params.length == 0`.
			@:nullSafety(Off)
			final code = switch(entry.params[0].expr) {
				case EConst(CString(s, _)): s;
				case _: {
					#if eval
					Context.error("One string argument expected.", entry.pos);
					#else
					"";
					#end
				}
			}

			{
				entry: entry,
				code: code
			};
		} else {
			null;
		}
	}

	/**
		Given a `haxe.macro.Position`, generates an error at the position
		stating: "Could not generate expression".
	**/
	public function onExpressionUnsuccessful(pos: Position) {
		return err("Could not generate expression.", pos);
	}

	/**
		Generates an "injection" expression if possible.

		```haxe
		// For example:
		generateInjectionExpression("const booty <= (1,2)");

		// Returns a dynamically-typed `TypedExpr` for the expression:
		untyped __LANG__("const booty <= (1,2)");
		```
	**/
	public function generateInjectionExpression(content: String, position: Null<Position> = null): TypedExpr {
		if(options.targetCodeInjectionName == null) {
			throw "`targetCodeInjectionName` option must be defined to use this function.";
		}

		position ??= Context.currentPos();

		return {
			expr: TCall({
				expr: TIdent(options.targetCodeInjectionName),
				pos: position.trustMe(),
				t: TDynamic(null)
			}, [
				{
					expr: TConst(TString(content)),
					pos: position.trustMe(),
					t: TDynamic(null)
				}
			]),
			pos: position.trustMe(),
			t: TDynamic(null)
		}
	}
}

#end
