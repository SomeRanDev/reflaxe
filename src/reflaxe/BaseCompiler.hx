package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.compiler.TargetCodeInjection;
import reflaxe.compiler.MetadataCompiler;
import reflaxe.compiler.TypeUsageTracker;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.helpers.ModuleTypeHelper;
import reflaxe.optimization.ExprOptimizer;
import reflaxe.output.OutputManager;
import reflaxe.output.OutputPath;

using StringTools;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
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
	Used for `BaseCompilerOptions.wrapFunctionReferences`.
**/
enum LambdaWrapType {
	/**
		Reflaxe will never wrap function references.
	**/
	Never;

	/**
		Reflaxe will ONLY wrap function fields that use
		`@:native`, `@:nativeFunctionCode`, or whatever
		is listed in the `wrapFunctionMetadata` option.
	**/
	NativeMetaOnly;

	/**
		Reflaxe will wrap both extern function references
		and `wrapFunctionMetadata` metadata fields.

		This includes both functions marked `extern` and
		functions from `extern` classes.
	**/
	ExternOnly;

	/**
		Reflaxe will wrap all function references.
	**/
	Yes;
}

/**
	A structure that contains all the options for
	configuring the BaseCompiler's behavior.
**/
@:structInit
class BaseCompilerOptions {
	/**
		How the source code files are outputted.
	**/
	public var fileOutputType: BaseCompilerFileOutputType = FilePerClass;

	/**
		This String is appended to the filename for each output file.
	**/
	public var fileOutputExtension: String = ".hxoutput";

	/**
		This is the define that decides where the output is placed.
		For example, this define will place the output in the "out" directory.

		-D hxoutput=out
	**/
	public var outputDirDefineName: String = "hxoutput";

	/**
		If "fileOutputType" is SingleFile, this is the name of
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
		If "true", null safety will be enforced for all the code
		compiled to the target. Useful for ensuring null is only
		used on types explicitly marked as nullable.
	**/
	public var enforceNullTyping: Bool = true;

	/**
		If "true", typedefs will be converted to their internal
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
		an Array. Useful as certain targets can't capture and
		modify a value unless stored by reference.
	**/
	public var wrapLambdaCaptureVarsInArray: Bool = false;

	/**
		If "true", during the EIE normalization phase, all
		instances of null coalescence are converted to a
		null-check if statement.
	**/
	public var convertNullCoal: Bool = false;

	/**
		If "true", during the EIE normalization phase, all
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
			var fcc = String.fromCharCode
		
		Gets converted to this:
			var fcc = function(i: Int): String {
				return String.fromCharCode(i);
			}
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
		If "true", only the module containing the "main"
		function and any classes it references are compiled.
		Otherwise, Haxe's less restrictive output type list is used.
	**/
	public var smartDCE: Bool = false;

	/**
		If "true", any std module is only compiled if explicitly
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
		If "true", a map of all the ModuleTypes mapped by their
		relevence to the implementation are provided to
		BaseCompiler's compileClass and compileEnum.
		Useful for generating "import-like" content.
	**/
	public var trackUsedTypes: Bool = false;

	/**
		If "true", functions from `ClassHierarchyTracker` will
		be available for use. This requires some processing
		prior to the start of compilation, so opting out is an option.
	**/
	public var trackClassHierarchy: Bool = true;

	/**
		If "true", any old output files that are not generated
		in the most recent compilation will be deleted.
		A text file containing all the current output files is
		saved in the output directory to help keep track. 

		This feature is ignored when "fileOutputType" is SingleFile.
	**/
	public var deleteOldOutput: Bool = true;

	/**
		If "false", an error is thrown if a function without
		a body is encountered. Typically this occurs when
		an umimplemented Haxe API function is encountered.
	**/
	public var ignoreBodilessFunctions: Bool = false;

	/**
		If "true", extern classes and fields are not passed to BaseCompiler.
	**/
	public var ignoreExterns: Bool = true;

	/**
		If "true", properties that are not physical properties
		are not passed to BaseCompiler. (i.e. both their
		read and write rules are "get", "set", or "never").
	**/
	public var ignoreNonPhysicalFields: Bool = true;

	/**
		If "true", the @:meta will be automatically handled
		for classes, enums, and class fields. This meta works
		like it does for Haxe/C#, allowing users to define
		metadata/annotations/attributes in the target output.

		@:meta(my_meta) var field = 123;

		For example, the above Haxe code converts to the below
		output code. Use "autoNativeMetaFormat" to configure
		how the native metadata is formatted.

		[my_meta]
		let field = 123;
	**/
	public var allowMetaMetadata: Bool = true;

	/**
		If "allowMetaMetadata" is enabled, this configures
		how the metadata is generated for the output.
		Use "{}" to represent the metadata content.

		autoNativeMetaFormat: "[[@{}]]"

		For example, setting this option to the String above
		would cause Haxe @:meta to be converted like below:

		@:meta(my_meta)   -->   [[@my_meta]]
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
	in "metadataTemplates" for BaseCompilerOptions.
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
	// * Abstract Functions
	//
	// Override in custom compiler to control it.
	// =======================================================
	public abstract function compileClassImpl(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<String>;
	public abstract function compileEnumImpl(enumType: EnumType, options: Array<EnumOptionData>): Null<String>;
	public abstract function compileExpressionImpl(expr: TypedExpr, topLevel: Bool): Null<String>;

	// =======================================================
	// * Conditional Overridables
	//
	// Override these in custom compiler to filter types.
	// =======================================================
	public function shouldGenerateClass(cls: ClassType): Bool {
		if(cls.isTypeParameter()) {
			return false;
		}
		if(cls.isExprClass()) {
			return false;
		}
		return !cls.isExtern || !options.ignoreExterns;
	}

	public function shouldGenerateEnum(enumType: EnumType): Bool {
		return !enumType.isExtern || !options.ignoreExterns;
	}

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
	function err(msg: String, pos: Null<Position> = null) {
		#if eval
		if(pos == null) pos = Context.currentPos();
		Context.error(msg, pos);
		#end
	}

	// =======================================================
	// * Options
	// =======================================================
	public var options(default, null): BaseCompilerOptions = {};

	public function setOptions(options: BaseCompilerOptions) {
		this.options = options;
	}

	// =======================================================
	// * Output Directory
	// =======================================================
	public var output(default, null): Null<OutputManager> = null;

	public function setOutputDir(outputDir: String) {
		if(this.output == null) {
			this.output = new OutputManager(this);
		}
		this.output.setOutputDir(outputDir);
	}

	public function generateFiles() {
		if(this.output != null) {
			this.output.generateFiles();
		} else {
			err("Attempted to output without being assigned destination.");
		}
	}

	/**
		If you wish to code how files are generated yourself,
		override this function in child class and set
		options.fileOutputType to "Manual".

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
	function setExtraFile(path: OutputPath, content: String = "") {
		extraFiles.set(path.toString(), [0 => content]);
	}

	/**
		Check if an extra file exists.
	**/
	function extraFileExists(path: OutputPath): Bool {
		final pathString = path.toString();
		return extraFiles.exists(pathString);
	}

	/**
		Set all the content for a file if it doesn't exist yet.
	**/
	function setExtraFileIfEmpty(path: OutputPath, content: String = "") {
		if(!extraFileExists(path)) {
			setExtraFile(path, content);
		}
	}

	/**
		Returns the contents of the file if it exists.
		The "priority" can be specified to get content
		specifically assigned that priority level.

		Returns an empty string if nothing exists.
	**/
	function getExtraFileContent(path: OutputPath, priority: Int = 0): String {
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
		The "priority" allows for content to be appended
		at different places within the file.
	**/
	function replaceInExtraFile(path: OutputPath, content: String, priority: Int = 0) {
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
		The "priority" allows for content to be appended
		at different places within the file.
	**/
	function appendToExtraFile(path: OutputPath, content: String, priority: Int = 0) {
		replaceInExtraFile(path, getExtraFileContent(path, priority) + content, priority);
	}

	// =======================================================
	// * File Placement Overrides
	// =======================================================
	var fileNameOverride: Null<String> = null;
	var fileDirOverride: Null<String> = null;

	/**
		Use while compiling a module type (typically through
		one of the `BaseCompiler` override methods like
		`compileClassImpl`) to set the name of the file
		that will contain the output being generated.

		Setting to an empty `String` or `null` will result
		in the default file name being used.
	**/
	public function setOutputFileName(name: Null<String>) {
		fileNameOverride = name;
	}

	/**
		Use while compiling a module type (typically through
		one of the `BaseCompiler` override methods like
		`compileClassImpl`) to set the output directory of
		the file containing the output for the type being compiled.

		Subdirectories can be used with the forward slash.

		Setting to an empty `String` or `null` will result
		in the file being generated in the top directory
		(the output directory).
	**/
	public function setOutputFileDir(dir: Null<String>) {
		fileDirOverride = dir;
	}

	// =======================================================
	// * Class Management
	// =======================================================
	public var classes(default, null): Array<{ cls: BaseType, output: String, fileName: Null<String>, dir: Null<String> }> = [];

	function addToClasses(b: BaseType, output: Null<String>) {
		if(output != null) {
			classes.push({
				cls: b,
				output: output,
				fileName: fileNameOverride,
				dir: fileDirOverride
			});

			// Reset these for next time
			fileNameOverride = null;
			fileDirOverride = null;
		}
	}

	public function addClassOutput(cls: ClassType, output: Null<String>) {
		onClassAdded(cls, output);
		addToClasses(cls, output);
	}

	public function addEnumOutput(en: EnumType, output: Null<String>) {
		onEnumAdded(en, output);
		addToClasses(en, output);
	}

	public function addTypedefOutput(def: DefType, output: Null<String>) {
		onTypedefAdded(def, output);
		addToClasses(def, output);
	}

	public function addAbstractOutput(abt: AbstractType, output: Null<String>) {
		onAbstractAdded(abt, output);
		addToClasses(abt, output);
	}

	/**
		Returns the "main" typed expression for the program.
		For example, if `-main MyClass` is set in the project,
		the expression will be: `MyClass.main()`.

		Please note if using Haxe v4.2.5 or below, the main
		class must be defined using `-D mainClass`.
		For example: `-D mainClass=MyClass`.
	**/
	public function getMainExpr(): Null<TypedExpr> {
		#if macro
		return Context.getMainExpr();
		#else
		return null;
		#end
	}

	/**
		Extracts the `ModuleType` of the main class based on
		`getMainExpr` function.
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
		Store and reference the typeUsage Map for the current
		class or enum being compiled.
	**/
	var typeUsage: Null<TypeUsageMap> = null;

	function getTypeUsage(): Null<TypeUsageMap> {
		return typeUsage;
	}

	/**
		Stores a reference to the ModuleType currently being
		compiled.
	**/
	var currentModule: Null<ModuleType> = null;

	function getCurrentModule(): Null<ModuleType> {
		return currentModule;
	}

	/**
		Called before compileClass, compileEnum, etc. to
		setup fields to be referenced.
	**/
	public function setupModule(mt: Null<ModuleType>) {
		currentModule = mt;
		typeUsage = (mt != null && options.trackUsedTypes) ? TypeUsageTracker.trackTypesInModuleType(mt) : null;
	}

	/**
		Compiles the provided class.
		Override compileClassImpl to configure the behavior.
	**/
	public function compileClass(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<String> {
		return compileClassImpl(classType, varFields, funcFields);
	}

	/**
		Compiles the provided enum.
		Override compileEnumImpl to configure the behavior.
	**/
	public function compileEnum(enumType: EnumType, options: Array<EnumOptionData>): Null<String> {
		return compileEnumImpl(enumType, options);
	}

	/**
		Compiles the provided typedef.
		Ignores by default as Haxe redirects all types automatically.
	**/
	public function compileTypedef(classType: DefType): Null<String> {
		return null;
	}

	/**
		Compiles the provided abstract.
		Ignores by default as Haxe converts all abstracts
		to normal function calls automatically.
	**/
	public function compileAbstract(classType: AbstractType): Null<String> {
		return null;
	}

	/**
		Compiles the provided expression.
		Override compileExpressionImpl to configure the behavior.
	**/
	public function compileExpression(expr: TypedExpr, topLevel: Bool = false): Null<String> {
		if(options.targetCodeInjectionName != null) {
			final result = TargetCodeInjection.checkTargetCodeInjection(options.targetCodeInjectionName, expr, this);
			if(result != null) {
				return result;
			}
		}

		return compileExpressionImpl(expr, topLevel);
	}

	/**
		Compiles the provided variable name.
		Ensures it does not match any of the reserved variable names.
	**/
	public function compileVarName(name: String, expr: Null<TypedExpr> = null, field: Null<ClassField> = null): String {
		while(options.reservedVarNames.contains(name)) {
			name = "_" + name;
		}
		return name;
	}

	/**
		Compiles the provided expression.
		Generates an error using `Context.error` if unsuccessful.
	**/
	public function compileExpressionOrError(expr: TypedExpr): String {
		final result = compileExpression(expr, false);
		if(result == null) {
			onExpressionUnsuccessful(expr.pos);
			return "";
		}
		return result;
	}

	public function onExpressionUnsuccessful(pos: Position) {
		err("Could not generate expression", pos);
	}

	/**
		Returns the result of calling "ExprOptimizer.optimizeAndUnwrap"
		and "compileExpressionsIntoLines" from the "expr".
	**/
	public function compileClassVarExpr(expr: TypedExpr): String {
		final exprs = ExprOptimizer.optimizeAndUnwrap(expr);
		return compileExpressionsIntoLines(exprs);
	}

	/**
		Same as "compileClassVarExpr", but also uses 
		EverythingIsExprSanitizer if required.
	**/
	public function compileClassFuncExpr(expr: TypedExpr): String {
		return compileClassVarExpr(expr);
	}

	/**
		Convert a list of expressions to lines of output code.
		The lines of code are spaced out to make it feel like
		it was human-written.
	**/
	function compileExpressionsIntoLines(exprList: Array<TypedExpr>): String {
		var currentType = -1;
		final lines = [];

		injectionAllowed = true;

		for(e in exprList) {
			final newType = expressionType(e);
			if(currentType != newType) {
				if(currentType != -1) lines.push("");
				currentType = newType;
			}

			// Compile expression
			final output = compileExpression(e, true);

			// Add injections
			final preExpr = prefixExpressionContent(e, output);
			if(preExpr != null) {
				for(e in preExpr) {
					lines.push(formatExpressionLine(e));
				}
			}

			// Add compiled expression
			if(output != null) {
				lines.push(formatExpressionLine(output));
			}

			// Clear injection list
			if(injectionContent.length > 0) {
				injectionContent = [];
			}
		}

		injectionAllowed = false;

		return lines.join("\n");
	}

	/**
		Allows for content to be injected before an expression.
		Useful for adding call stack information to output.
	**/
	function prefixExpressionContent(expr: TypedExpr, output: Null<String>): Null<Array<String>> {
		return injectionContent.length > 0 ? injectionContent : null;
	}

	/**
		Stores a list of content to be injected between expressions.
		See `injectExpressionPrefixContent` for implementation.
	**/
	var injectionContent: Array<String> = [];

	/**
		Tracks whether content can be injected while compiling
		an expression.
	**/
	var injectionAllowed: Bool = false;

	/**
		If called while compiling multiple expressions, this
		will inject content prior to the expression currently
		being compiled.
	**/
	function injectExpressionPrefixContent(content: String): Bool {
		return if(injectionAllowed) {
			injectionContent.push(content);
			true;
		} else {
			false;
		}
	}

	/**
		Called for each line generated in the above function
		"compileExpressionsIntoLines". Useful for adding
		required termination characters for expressions that
		are not treated as values (i.e: semicolons).
	**/
	function formatExpressionLine(expr: String): String {
		return expr;
	}

	/**
		Compiles the Haxe metadata to the target's equivalent.
		This function will always return `null` unless 
		"allowMetaMetadata" is true or "metadataTemplates"
		contains at least one entry.
	**/
	public function compileMetadata(metaAccess: Null<MetaAccess>, target: haxe.display.Display.MetadataTarget): Null<String> {
		return MetadataCompiler.compileMetadata(options, metaAccess, target);
	}

	/**
		Each expression is assigned a "type" (represented by int).
		When generating code, expressions of the same type are kept
		close together, while expressions of different types are
		separated by a new line.

		This helps make the code output look human-written.
		Used in "compileExpressionsIntoLines".
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
		These fields are used for the `dynamicDCE` option.
		While enabled, use `addModuleTypeForCompilation` to
		add additional ModuleTypes to be compiled.
	**/
	public var dynamicTypeStack: Array<ModuleType> = [];
	public var dynamicTypesHandled: Array<String> = [];

	public function addModuleTypeForCompilation(mt: ModuleType) {
		final id = mt.getUniqueId();
		if(!dynamicTypesHandled.contains(id)) {
			dynamicTypesHandled.push(id);
			dynamicTypeStack.push(mt);
		}
	}

	/**
		Used in compileNativeFunctionCodeMeta & compileNativeTypeCodeMeta.
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
		This function is for compiling the result of functions
		using the @:nativeFunctionCode meta.
	**/
	public function compileNativeFunctionCodeMeta(callExpr: TypedExpr, arguments: Array<TypedExpr>, typeParams: Null<Array<() -> String>> = null): Null<String> {
		final declaration = callExpr.getDeclarationMeta(arguments);
		if(declaration == null) {
			return null;
		}
		final meta = declaration.meta;
		final data = meta != null ? extractStringFromMeta(meta, ":nativeFunctionCode") : null;
		if(data != null) {
			final code = data.code;
			var result = code;

			if(code.contains("{this}")) {
				final thisExpr = declaration.thisExpr != null ? compileNFCThisExpression(declaration.thisExpr, declaration.meta) : null;
				if(thisExpr == null) {
					if(declaration.thisExpr == null) {
						#if eval
						Context.error("Cannot use {this} on @:nativeFunctionCode meta for constructors.", data.entry.pos);
						#end
					} else {
						onExpressionUnsuccessful(callExpr.pos);
					}
				} else {
					result = result.replace("{this}", thisExpr);
				}
			}

			var argExprs: Null<Array<String>> = null;
			for(i in 0...arguments.length) {
				final key = "{arg" + i + "}";
				if(code.contains(key)) {
					if(argExprs == null) {
						argExprs = arguments.map(function(e) {
							return this.compileExpressionOrError(e);
						});
					}
					if(argExprs[i] == null) {
						onExpressionUnsuccessful(arguments[i].pos);
					} else {
						result = result.replace(key, argExprs[i]);
					}
				}
			}

			if(typeParams != null) {
				for(i in 0...typeParams.length) {
					final key = "{type" + i + "}";
					if(code.contains(key)) {
						result = result.replace(key, typeParams[i]());
					}
				}
			}

			return result;
		}

		return null;
	}

	/**
		This function is for compiling the result of functions
		using the @:nativeVariableCode meta.
	**/
	public function compileNativeVariableCodeMeta(fieldExpr: TypedExpr, varCpp: Null<String> = null): Null<String> {
		final declaration = fieldExpr.getDeclarationMeta();
		if(declaration == null) {
			return null;
		}
		final meta = declaration.meta;
		final data = meta != null ? extractStringFromMeta(meta, ":nativeVariableCode") : null;
		if(data != null) {
			final code = data.code;
			var result = code;

			if(code.contains("{this}")) {
				final thisExpr = declaration.thisExpr != null ? compileNFCThisExpression(declaration.thisExpr, declaration.meta) : null;
				if(thisExpr == null) {
					if(declaration.thisExpr == null) {
						#if eval
						Context.error("Cannot use {this} on @:nativeVariableCode meta for constructors.", data.entry.pos);
						#end
					} else {
						onExpressionUnsuccessful(fieldExpr.pos);
					}
				} else {
					result = result.replace("{this}", thisExpr);
				}
			}

			if(varCpp != null && code.contains("{var}")) {
				result = result.replace("{var}", varCpp);
			}

			return result;
		}

		return null;
	}

	/**
		Compiles the {this} expression for @:nativeFunctionCode.
	**/
	public function compileNFCThisExpression(expr: TypedExpr, meta: Null<MetaAccess>): String {
		return compileExpressionOrError(expr); 
	}

	/**
		This function is for compiling the result of functions
		using the @:nativeTypeCode meta.
	**/
	public function compileNativeTypeCodeMeta(type: Type, typeParams: Null<Array<() -> String>> = null): Null<String> {
		final meta = type.getMeta();
		if(meta == null) {
			return null;
		}

		final data = extractStringFromMeta(meta, ":nativeTypeCode");
		if(data != null) {
			final code = data.code;
			var result = code;

			if(typeParams != null) {
				for(i in 0...typeParams.length) {
					final key = "{type" + i + "}";
					if(code.contains(key)) {
						result = result.replace(key, typeParams[i]());
					}
				}
			}

			return result;
		}

		return null;
	}
}

#end
