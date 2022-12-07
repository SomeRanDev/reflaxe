package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.conversion.ExprOptimizer;
import reflaxe.conversion.EverythingIsExprConversion;
import reflaxe.output.OutputManager;

import reflaxe.helpers.ModuleTypeHelper;

using reflaxe.helpers.ClassTypeHelper;

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
	// This string is appended to the filename for each output file.
	public var fileOutputExtension: String = ".hxoutput";

	// -------------------------------------------------------
	// This is the define which must exist for this compiler to function.
	// If "null", no define is required, but this is not recommended.
	// Typically, the "output directory" define is used here.
	public var requireDefine: Null<String> = null;

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
	// * abstract functions
	//
	// Override in custom compiler to control it
	// =======================================================
	public abstract function compileClass(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String>;
	public abstract function compileEnum(classType: EnumType, constructs: Map<String, EnumField>): Null<String>;
	public abstract function compileExpression(expr: TypedExpr): Null<String>;

	public function compileTypedef(classType: DefType): Null<String> { return null; }
	public function compileAbstract(classType: AbstractType): Null<String> { return null; }

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
	public function generateFilesManually() {
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
	// EverythingIsExprConversion if required.
	// =======================================================
	public function compileClassFuncExpr(expr: TypedExpr): String {
		if(!options.normalizeEIE) {
			return compileClassVarExpr(expr);
		}
		final eiec = new EverythingIsExprConversion(expr, null);
		final convertedExpr = eiec.convertedExpr();
		return compileClassVarExpr(convertedExpr);
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
