// =======================================================
// * ReflectCompiler
//
// Manages everything.
// =======================================================

package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.display.Display.MetadataTarget;
import haxe.display.Display.Platform;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.BaseCompiler;
import reflaxe.compiler.EverythingIsExprSanitizer;
import reflaxe.compiler.RepeatVariableFixer;
import reflaxe.compiler.CaptureVariableFixer;
import reflaxe.compiler.TypeUsageTracker;
import reflaxe.input.ModuleUsageTracker;

using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.TypeHelper;

class ReflectCompiler {
	// =======================================================
	// * Public Members
	// =======================================================
	public static var Compilers: Array<BaseCompiler> = [];

	public static function Start() {
		Context.onAfterTyping(onAfterTyping);
		Context.onAfterGenerate(onAfterGenerate);
	}

	public static function AddCompiler(compiler: BaseCompiler, options: Null<BaseCompilerOptions> = null) {
		if(!Compilers.contains(compiler)) {
			Compilers.push(compiler);
		}
		if(options != null) {
			compiler.setOptions(options);
		}
	}

	public static function MetaTemplate(name: String, doc: String, disallowMultiple: Bool = false, paramTypes: Null<Array<MetaArgumentType>> = null, targets: Null<Array<MetadataTarget>> = null, compileFunc: Null<(MetadataEntry, Array<String>) -> Null<String>> = null) {
		final params = if(paramTypes != null && paramTypes.length > 0) {
			paramTypes.map(function(p): String return p);
		} else {
			[];
		}

		final metaDesc: #if (haxe_ver >= "4.3.0") haxe.macro.Compiler.MetadataDescription #else Dynamic #end = {
			metadata: name,
			doc: doc,
			params: params,
			platforms: [Cross],
			targets: targets
		};

		#if (haxe_ver >= "4.3.0")
		haxe.macro.Compiler.registerCustomMetadata(metaDesc);
		#end

		return {
			meta: metaDesc,
			disallowMultiple: disallowMultiple,
			paramTypes: paramTypes,
			compileFunc: compileFunc
		};
	}

	// =======================================================
	// * Private Members
	// =======================================================
	static var moduleTypes: Array<ModuleType>;

	static function onAfterTyping(mtypes: Array<ModuleType>) {
		moduleTypes = mtypes;
	}

	static function onAfterGenerate() {
		checkCompilers();
	}

	static function checkCompilers() {
		if(Compilers.length <= 0) {
			return;
		}

		final validCompilers = findEnabledCompilers();
		if(validCompilers.length == 1) {
			useCompiler(validCompilers[0]);
		} else if(validCompilers.length > 1) {
			tooManyCompilersError(validCompilers);
		}
	}

	static function findEnabledCompilers(): Array<BaseCompiler> {
		final validCompilers = [];
		for(compiler in Compilers) {
			final outputDirDef = compiler.options.outputDirDefineName;
			final outputDir = Context.definedValue(outputDirDef);
			if(Context.defined(outputDirDef) && outputDir.length > 0) {
				compiler.setOutputDir(outputDir);
				validCompilers.push(compiler);
			} else {
				final compilerName = Type.getClassName(Type.getClass(compiler));
				final pos = Context.currentPos();
				final msg = 'The $compilerName compiler is enabled; however, the output directory (-D $outputDirDef) is not defined.';
				Context.error(msg, pos);
			}
		}
		return validCompilers;
	}

	static function tooManyCompilersError(compilers: Array<BaseCompiler>) {
		final compilerList = compilers.map(c -> Type.getClassName(Type.getClass(c))).join(" | ");
		final pos = Context.currentPos();
		final msg = 'Multiple compilers have been enabled, only one may be active per build: $compilerList';
		Context.error(msg, pos);
	}

	static function useCompiler(compiler: BaseCompiler) {
		compiler.onCompileStart();
		addClassesToCompiler(compiler);
		compiler.onCompileEnd();
		generateFiles(compiler);
		compiler.onOutputComplete();
	}
 
	static function getAllModulesTypesForCompiler(compiler: BaseCompiler): Array<ModuleType> {
		final result = if(compiler.options.smartDCE) {
			final tracker = new ModuleUsageTracker(moduleTypes, compiler);
			tracker.filteredTypes();
		} else {
			moduleTypes;
		}

		return if(compiler.options.ignoreTypes.length > 0) {
			final ignoreTypes = compiler.options.ignoreTypes;
			result.filter(function(moduleType) {
				return !ignoreTypes.contains(moduleType.getPath());
			});
		} else {
			result;
		}
	}

	static function addClassesToCompiler(compiler: BaseCompiler) {
		if(compiler.options.dynamicDCE) {
			dynamicallyAddModulesToCompiler(compiler);
		} else {
			addModulesToCompiler(compiler, getAllModulesTypesForCompiler(compiler));
		}
	}

	static function dynamicallyAddModulesToCompiler(compiler: BaseCompiler) {
		final tracker = new ModuleUsageTracker(moduleTypes, compiler);
		compiler.dynamicTypeStack = tracker.nonStdTypes();
		compiler.dynamicTypesHandled = compiler.dynamicTypeStack.map(mt -> mt.getUniqueId());
		while(compiler.dynamicTypeStack.length > 0) {
			final temp = compiler.dynamicTypeStack;
			compiler.dynamicTypeStack = [];
			addModulesToCompiler(compiler, temp);
		}
	}

	static function addModulesToCompiler(compiler: BaseCompiler, modules: Array<ModuleType>) {
		final classDecls: Array<Ref<ClassType>> = [];
		final enumDecls: Array<Ref<EnumType>> = [];
		final defDecls: Array<Ref<DefType>> = [];
		final abstractDecls: Array<Ref<AbstractType>> = [];

		for(moduleType in modules) {
			switch(moduleType) {
				case TClassDecl(clsTypeRef): {
					classDecls.push(clsTypeRef);
				}
				case TEnumDecl(enumTypeRef): {
					enumDecls.push(enumTypeRef);
				}
				case TTypeDecl(defTypeRef): {
					defDecls.push(defTypeRef);
				}
				case TAbstract(abstractRef): {
					abstractDecls.push(abstractRef);
				}
			}
		}

		for(clsRef in classDecls) {
			final cls = clsRef.get();
			compiler.setupModule(TClassDecl(clsRef));
			if(compiler.shouldGenerateClass(cls)) {
				compiler.addClassOutput(cls, transpileClass(cls, compiler));
			}
		}

		for(enumRef in enumDecls) {
			final enm = enumRef.get();
			compiler.setupModule(TEnumDecl(enumRef));
			if(compiler.shouldGenerateEnum(enm)) {
				compiler.addEnumOutput(enm, transpileEnum(enm, compiler));
			}
		}

		for(defRef in defDecls) {
			final def = defRef.get();
			compiler.setupModule(TTypeDecl(defRef));
			compiler.addTypedefOutput(def, compiler.compileTypedef(def));
		}

		for(abstractRef in abstractDecls) {
			final ab = abstractRef.get();
			compiler.setupModule(TAbstract(abstractRef));
			compiler.addAbstractOutput(ab, compiler.compileAbstract(ab));
		}

		compiler.setupModule(null);
	}

	static function generateFiles(compiler: BaseCompiler) {
		compiler.generateFiles();
	}

	// =======================================================
	// * transpileClass
	// =======================================================
	static function transpileClass(cls: ClassType, compiler: BaseCompiler): Null<String> {
		final varFields: ClassFieldVars = [];
		final funcFields: ClassFieldFuncs = [];

		final ignoreExterns = compiler.options.ignoreExterns;

		final addField = function(field: ClassField, isStatic: Bool) {
			if(ignoreExterns && field.isExtern) {
				return;
			}

			switch(field.kind) {
				case FVar(readVarAccess, writeVarAccess): {
					if(shouldGenerateVar(field, compiler, isStatic, readVarAccess, writeVarAccess)) {
						varFields.push({
							isStatic: isStatic,
							read: readVarAccess,
							write: writeVarAccess,
							field: field
						});
					}
				}
				case FMethod(methodKind): {
					if(shouldGenerateFunc(field, compiler, isStatic, methodKind)) {
						final tfunc = findTFunc(field);
						if(tfunc != null) {
							funcFields.push({
								isStatic: isStatic,
								kind: methodKind,
								tfunc: preprocessFunction(compiler, field, tfunc),
								field: field
							});
						} else {
							if(!compiler.options.ignoreBodilessFunctions) {
								Context.warning("Function information not found.", field.pos);
							}
						}
					}
				}
			}
		}

		if(cls.constructor != null) {
			final field = cls.constructor.get();
			addField(field, false);
		}

		for(field in cls.fields.get()) {
			addField(field, false);
		}

		for(field in cls.statics.get()) {
			addField(field, true);
		}
	
		return compiler.compileClass(cls, varFields, funcFields);
	}

	static function preprocessFunction(compiler: BaseCompiler, field: ClassField, tfunc: TFunc): TFunc {
		if(compiler.options.normalizeEIE) {
			final eiec = new EverythingIsExprSanitizer(tfunc.expr, compiler, null);
			tfunc.expr = eiec.convertedExpr();
		}
		if(compiler.options.preventRepeatVars) {
			final rvf = new RepeatVariableFixer(tfunc.expr, null, tfunc.args.map(a -> a.v.name));
			tfunc.expr = rvf.fixRepeatVariables();
		}
		if(compiler.options.wrapLambdaCaptureVarsInArray) {
			final cfv = new CaptureVariableFixer(tfunc.expr);
			tfunc.expr = cfv.fixCaptures();
		}
		return tfunc;
	}

	// =======================================================
	// * transpileEnum
	// =======================================================
	static function transpileEnum(enm: EnumType, compiler: BaseCompiler): Null<String> {
		final options = [];
		for(name => field in enm.constructs) {
			final args = switch(field.type) {
				case TFun(args, ret): args;
				case _: [];
			}
			options.push({
				name: name,
				field: field,
				args: args
			});
		}
		return compiler.compileEnum(enm, options);
	}

	// =======================================================
	// * shouldGenerateVar
	// * shouldGenerateFunc
	// =======================================================
	static function shouldGenerateVar(field: ClassField, compiler: BaseCompiler, isStatic: Bool, read: VarAccess, write: VarAccess): Bool {
		if(!compiler.shouldGenerateClassField(field)) {
			return false;
		}
		return if(field.meta.maybeHas(":isVar")) {
			true;
		} else {
			switch([read, write]) {
				case [AccNormal | AccNo, AccNormal | AccNo]: true;
				case _: !compiler.options.ignoreNonPhysicalFields;
			}
		}
	}

	static function shouldGenerateFunc(field: ClassField, compiler: BaseCompiler, isStatic: Bool, kind: MethodKind): Bool {
		return compiler.shouldGenerateClassField(field);
	}

	// =======================================================
	// * findTFunc
	// =======================================================
	static function findTFunc(field: ClassField): Null<TFunc> {
		return if(field.expr() != null) {
			switch(field.expr().expr) {
				case TFunction(tfunc): tfunc;
				case _: null;
			}
		} else {
			null;
		}
	}
}

#end
