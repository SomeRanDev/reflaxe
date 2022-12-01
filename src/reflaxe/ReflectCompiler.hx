// =======================================================
// * ReflectCompiler
//
// Manages everything.
// =======================================================

package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

using reflaxe.helpers.SyntaxHelper;

import reflaxe.BaseCompiler;

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
			final reqDef = compiler.options.requireDefine;
			if(reqDef == null || Context.defined(reqDef)) {
				final outputDirDef = compiler.options.outputDirDefineName;
				final outputDir = Context.definedValue(outputDirDef);
				if(Context.defined(outputDirDef) && outputDir.length > 0) {
					compiler.setOutputDir(outputDir);
					validCompilers.push(compiler);
				} else {
					final compilerName = Type.getClassName(Type.getClass(compiler));
					final pos = Context.currentPos();
					final errorReason = reqDef != null ? ' because -D $reqDef is defined' : "";
					final msg = 'The $compilerName compiler is enabled$errorReason; however, the output directory (-D $outputDirDef) is not defined.';
					Context.error(msg, pos);
				}
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
		addClassesToCompiler(compiler);
		generateFiles(compiler);
	}

	static function addClassesToCompiler(compiler: BaseCompiler) {
		final classDecls: Array<Ref<ClassType>> = [];
		for(mt in moduleTypes) {
			switch(mt) {
				case TClassDecl(clsTypeRef): {
					classDecls.push(clsTypeRef);
				}
				case _: {}
			}
		}

		for(clsRef in classDecls) {
			final cls = clsRef.get();
			compiler.addClassOutput(cls, transpileClass(cls, compiler));
		}
	}

	static function generateFiles(compiler: BaseCompiler) {
		compiler.generateFiles();
	}

	// =======================================================
	// * transpileClass
	// =======================================================
	static function transpileClass(cls: ClassType, compiler: BaseCompiler): Null<String> {
		final fieldList = cls.fields.get();
		final varFields: ClassFieldVars = [];
		final funcFields: ClassFieldFuncs = [];

		for(field in fieldList) {
			if(compiler.options.ignoreExterns && field.isExtern) {
				continue;
			}

			switch(field.kind) {
				case FVar(readVarAccess, writeVarAccess): {
					if(shouldGenerateVar(field, compiler, readVarAccess, writeVarAccess)) {
						varFields.push({
							read: readVarAccess,
							write: writeVarAccess,
							field: field
						});
					}
				}
				case FMethod(methodKind): {
					if(shouldGenerateFunc(field, compiler, methodKind)) {
						final tfunc = findTFunc(field);
						if(tfunc != null) {
							funcFields.push({
								kind: methodKind,
								tfunc: tfunc,
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
	
		return compiler.compileClass(cls, varFields, funcFields);
	}

	// =======================================================
	// * shouldGenerateVar
	// * shouldGenerateFunc
	// =======================================================
	static function shouldGenerateVar(field: ClassField, compiler: BaseCompiler, read: VarAccess, write: VarAccess): Bool {
		if(!compiler.shouldGenerateClassField(field)) {
			return false;
		}
		return if(field.meta.has(":isVar")) {
			true;
		} else {
			switch([read, write]) {
				case [AccNormal | AccNo, AccNormal | AccNo]: true;
				case _: !compiler.options.ignoreNonPhysicalFields;
			}
		}
	}

	static function shouldGenerateFunc(field: ClassField, compiler: BaseCompiler, kind: MethodKind): Bool {
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
