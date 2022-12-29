package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.compiler.TargetCodeInjection;
import reflaxe.compiler.MetadataCompiler;
import reflaxe.helpers.ModuleTypeHelper;
import reflaxe.optimization.ExprOptimizer;
import reflaxe.output.OutputManager;
import reflaxe.output.OutputPath;

using reflaxe.helpers.ClassTypeHelper;
using reflaxe.helpers.NullableMetaAccessHelper;

// =======================================================
// * BaseCompilerFileOutputType
//
// An enum for dictating how the compiler outputs the
// target source files.
// =======================================================
enum BaseCompilerFileOutputType {
	// -------------------------------------------------------
	// Do not automatically generate output.
	Manual;

	// -------------------------------------------------------
	// All output is combined into a single output file.
	SingleFile;

	// -------------------------------------------------------
	// A new source file is generated for each Haxe module.
	// Each file will contain at least one class, maybe more.
	FilePerModule;

	// -------------------------------------------------------
	// A new source file is generated for each Haxe class. 
	FilePerClass;
}

// =======================================================
// * BaseCompilerOptions
//
// A structure that contains all the options for
// configuring the BaseCompiler's behavior.
// =======================================================
@:structInit
class BaseCompilerOptions {
	// -------------------------------------------------------
	// How the source code files are outputted.
	public var fileOutputType: BaseCompilerFileOutputType = FilePerClass;

	// -------------------------------------------------------
	// This String is appended to the filename for each output file.
	public var fileOutputExtension: String = ".hxoutput";

	// -------------------------------------------------------
	// This is the define that decides where the output is placed.
	// For example, this define will place the output in the "out" directory.
	//
	// -D hxoutput=out
	//
	public var outputDirDefineName: String = "hxoutput";

	// -------------------------------------------------------
	// If "fileOutputType" is SingleFile, this is the name of
	// the file generated if a directory is provided.
	public var defaultOutputFilename: String = "output";

	// -------------------------------------------------------
	// A list of type paths that will be ignored and not generated.
	// Useful in cases where you can optimize the generation of
	// certain Haxe classes to your target's native syntax.
	//
	// For example, ignoring `haxe.iterators.ArrayIterator` and
	// generating to the target's native for-loop.
	public var ignoreTypes: Array<String> = [];

	// -------------------------------------------------------
	// A list of variable names that cannot be used in the
	// generated output. If these are used in the Haxe source,
	// an underscore is appended to the name in the output.
	public var reservedVarNames: Array<String> = [];

	// -------------------------------------------------------
	// The name of the function used to inject code directly
	// to the target. Set to `null` to disable this feature.
	public var targetCodeInjectionName: Null<String> = null;

	// -------------------------------------------------------
	// If "true", null safety will be enforced for all the code
	// compiled to the target. Useful for ensuring null is only
	// used on types explicitly marked as nullable.
	public var enforceNullSafety: Bool = true;

	// -------------------------------------------------------
	// If "true", typedefs will be converted to their internal
	// class or enum type before being processed and generated.
	public var unwrapTypedefs: Bool = true;

	// -------------------------------------------------------
	// Whether Haxe's "Everything is an Expression" is normalized.
	public var normalizeEIE: Bool = true;

	// -------------------------------------------------------
	// Whether variables of the same name are allowed to be
	// redeclarated in the same scope or a subscope.
	public var preventRepeatVars: Bool = true;

	// -------------------------------------------------------
	// Whether variables captured by lambdas are wrapped in
	// an Array. Useful as certain targets can't capture and
	// modify a value unless stored by reference.
	public var wrapLambdaCaptureVarsInArray: Bool = false;

	// -------------------------------------------------------
	// If "true", during the EIE normalization phase, all
	// instances of null coalescence are converted to a
	// null-check if statement.
	public var convertNullCoal: Bool = false;

	// -------------------------------------------------------
	// If "true", during the EIE normalization phase, all
	// instances of prefix/postfix increment and decrement
	// are converted to a Binop form.
	//
	// Helpful on Python-like targets that do not support
	// the `++` or `--` operators.
	public var convertUnopIncrement: Bool = false;

	// -------------------------------------------------------
	// If "true", only the module containing the "main"
	// function and any classes it references are compiled.
	// Otherwise, Haxe's less restrictive output type list is used.
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
	// If "false", an error is thrown if a function without
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

	// -------------------------------------------------------
	// If "true", the @:meta will be automatically handled
	// for classes, enums, and class fields. This meta works
	// like it does for Haxe/C#, allowing users to define
	// metadata/annotations/attributes in the target output.
	//
	// @:meta(my_meta) var field = 123;
	//
	// For example, the above Haxe code converts to the below
	// output code. Use "autoNativeMetaFormat" to configure
	// how the native metadata is formatted.
	//
	// [my_meta]
	// let field = 123;
	public var allowMetaMetadata: Bool = true;

	// -------------------------------------------------------
	// If "allowMetaMetadata" is enabled, this configures
	// how the metadata is generated for the output.
	// Use "{}" to represent the metadata content.
	//
	// autoNativeMetaFormat: "[[@{}]]"
	//
	// For example, setting this option to the String above
	// would cause Haxe @:meta to be converted like below:
	//
	// @:meta(my_meta)   -->   [[@my_meta]]
	public var autoNativeMetaFormat: Null<String> = null;

	// -------------------------------------------------------
	// A list of metadata unique for the target.
	//
	// It's not necessary to fill this out as metadata can
	// just be read directly from the AST. However, supplying
	// it here allows Reflaxe to validate the meta automatically,
	// ensuring the correct number/type of arguments are used.
	public var metadataTemplates: Array<{
		meta: #if (haxe_ver >= "4.3.0") MetadataDescription #else Dynamic #end,
		disallowMultiple: Bool,
		paramTypes: Null<Array<MetaArgumentType>>,
		compileFunc: Null<(MetadataEntry, Array<String>) -> Null<String>>
	}> = [];
}

// =======================================================
// * MetaArgumentType
//
// The metadata argument type that can be configured
// in "metadataTemplates" for BaseCompilerOptions.
// =======================================================
enum abstract MetaArgumentType(String) to String {
	var Bool = "bool";
	var Number = "number";
	var String = "string";
	var Identifier = "ident";
	var Array = "array";
	var Anything = "any";
	var Optional = "any?";
}

// =======================================================
// * ClassFieldVars
// * ClassFieldFuncs
//
// Typedefs used for storing ClassFields and their
// unwrapped data.
// =======================================================
typedef ClassFieldVars = Array<{ isStatic: Bool, read: VarAccess, write: VarAccess, field: ClassField }>;
typedef ClassFieldFuncs = Array<{ isStatic: Bool, kind: MethodKind, tfunc: TFunc, field: ClassField }>;

// =======================================================
// * BaseCompiler
//
// The super class all compilers should extend from.
// The behavior of how the Haxe AST is transpiled is
// configured by implementing the abstract methods.
// =======================================================
abstract class BaseCompiler {
	// =======================================================
	// * Abstract Functions
	//
	// Override in custom compiler to control it.
	// =======================================================
	public abstract function compileClassImpl(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String>;
	public abstract function compileEnumImpl(classType: EnumType, constructs: Map<String, EnumField>): Null<String>;
	public abstract function compileExpressionImpl(expr: TypedExpr): Null<String>;

	// =======================================================
	// * Conditional Overridables
	//
	// Override these in custom compiler to filter types.
	// =======================================================
	public function shouldGenerateClass(cls: ClassType): Bool {
		if(cls.isTypeParameter()) {
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
	// * new
	// =======================================================
	public function new() {}

	// =======================================================
	// * err
	// =======================================================
	function err(msg: String, pos: Null<Position> = null) {
		if(pos == null) pos = Context.currentPos();
		Context.error(msg, pos);
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

	// -------------------------------------------------------
	// If you wish to code how files are generated yourself,
	// override this function in child class and set
	// options.fileOutputType to "Manual".
	//
	// Files should be saved using `output.saveFile(path, content)`
	public function generateFilesManually() {
	}

	// =======================================================
	// * Extra Files
	// =======================================================
	public var extraFiles(default, null): Map<String, String> = [];

	function setExtraFile(path: OutputPath, content: String = "") {
		extraFiles.set(path.toString(), content);
	}

	function appendToExtraFile(path: OutputPath, content: String) {
		final pathString = path.toString();
		if(!extraFiles.exists(pathString)) {
			extraFiles.set(pathString, "");
		}
		final current = extraFiles.get(pathString);
		extraFiles.set(pathString, current + content);
	}

	// =======================================================
	// * Class Management
	// =======================================================
	public var classes(default, null): Array<{ cls: CommonModuleTypeData, output: String }> = [];

	public function addClassOutput(cls: ClassType, output: Null<String>) {
		onClassAdded(cls, output);
		if(output != null) {
			classes.push({
				cls: cls,
				output: output
			});
		}
	}

	public function addEnumOutput(en: EnumType, output: Null<String>) {
		onEnumAdded(en, output);
		if(output != null) {
			classes.push({
				cls: en,
				output: output
			});
		}
	}

	public function addTypedefOutput(def: DefType, output: Null<String>) {
		onTypedefAdded(def, output);
		if(output != null) {
			classes.push({
				cls: def,
				output: output
			});
		}
	}

	public function addAbstractOutput(abt: AbstractType, output: Null<String>) {
		onAbstractAdded(abt, output);
		if(output != null) {
			classes.push({
				cls: abt,
				output: output
			});
		}
	}

	// =======================================================
	// * compileClass
	//
	// Compiles the provided class.
	// Override compileClassImpl to configure the behavior.
	// =======================================================
	public function compileClass(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String> {
		return compileClassImpl(classType, varFields, funcFields);
	}

	// =======================================================
	// * compileEnum
	//
	// Compiles the provided enum.
	// Override compileEnumImpl to configure the behavior.
	// =======================================================
	public function compileEnum(enumType: EnumType, constructs: Map<String, EnumField>): Null<String> {
		return compileEnumImpl(enumType, constructs);
	}

	// =======================================================
	// * compileTypedef
	//
	// Compiles the provided typedef.
	// Ignores by default as Haxe redirects all types automatically.
	// =======================================================
	public function compileTypedef(classType: DefType): Null<String> {
		return null;
	}

	// =======================================================
	// * compileAbstract
	//
	// Compiles the provided abstract.
	// Ignores by default as Haxe converts all abstracts
	// to normal function calls automatically.
	// =======================================================
	public function compileAbstract(classType: AbstractType): Null<String> {
		return null;
	}

	// =======================================================
	// * compileExpression
	//
	// Compiles the provided expression.
	// Override compileExpressionImpl to configure the behavior.
	// =======================================================
	public function compileExpression(expr: TypedExpr): Null<String> {
		if(options.targetCodeInjectionName != null) {
			final result = TargetCodeInjection.checkTargetCodeInjection(options.targetCodeInjectionName, expr, this);
			if(result != null) {
				return result;
			}
		}

		return compileExpressionImpl(expr);
	}

	// =======================================================
	// * compileVarName
	//
	// Compiles the provided variable name.
	// Ensures it does not match any of the reserved variable names.
	// =======================================================
	public function compileVarName(name: String, expr: Null<TypedExpr> = null, field: Null<ClassField> = null): String {
		while(options.reservedVarNames.contains(name)) {
			name = "_" + name;
		}
		return name;
	}

	// =======================================================
	// * compileExpressionOrError
	//
	// Compiles the provided expression.
	// Generates an error using `Context.error` if unsuccessful.
	// =======================================================
	public function compileExpressionOrError(expr: TypedExpr): String {
		final result = compileExpression(expr);
		if(result == null) {
			onExpressionUnsuccessful(expr.pos);
		}
		return result;
	}

	public function onExpressionUnsuccessful(pos: Position) {
		err("Could not generate expression", pos);
	}

	// =======================================================
	// * compileClassVarExpr
	//
	// Returns the result of calling "ExprOptimizer.optimizeAndUnwrap"
	// and "compileExpressionsIntoLines" from the "expr".
	// =======================================================
	public function compileClassVarExpr(expr: TypedExpr): String {
		final exprs = ExprOptimizer.optimizeAndUnwrap(expr);
		return compileExpressionsIntoLines(exprs);
	}

	// =======================================================
	// * compileClassFuncExpr
	//
	// Same as "compileClassVarExpr", but also uses 
	// EverythingIsExprSanitizer if required.
	// =======================================================
	public function compileClassFuncExpr(expr: TypedExpr): String {
		return compileClassVarExpr(expr);
	}

	// =======================================================
	// * compileExpressionsIntoLines
	//
	// Convert a list of expressions to lines of output code.
	// The lines of code are spaced out to make it feel like
	// it was human-written.
	// =======================================================
	function compileExpressionsIntoLines(exprList: Array<TypedExpr>): String {
		var currentType = -1;
		final lines = [];
		for(e in exprList) {
			final newType = expressionType(e);
			if(currentType != newType) {
				if(currentType != -1) lines.push("");
				currentType = newType;
			}
			lines.push(compileExpression(e));
		}
		return lines.join("\n");
	}

	// =======================================================
	// * compileMetadata
	//
	// Compiles the Haxe metadata to the target's equivalent.
	// This function will always return `null` unless 
	// "allowMetaMetadata" is true or "metadataTemplates"
	// contains at least one entry.
	// =======================================================
	function compileMetadata(metaAccess: Null<MetaAccess>, target: haxe.display.Display.MetadataTarget): Null<String> {
		return MetadataCompiler.compileMetadata(options, metaAccess, target);
	}

	// =======================================================
	// * expressionType
	//
	// Each expression is assigned a "type" (represented by int).
	// When generating code, expressions of the same type are kept
	// close together, while expressions of different types are
	// separated by a new line.
	//
	// This helps make the code output look human-written.
	// Used in "compileExpressionsIntoLines".
	// =======================================================
	function expressionType(expr: Null<TypedExpr>): Int {
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
}

#end
