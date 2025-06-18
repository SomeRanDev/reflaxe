// =======================================================
// * ReflectCompiler
// =======================================================

package reflaxe;

#if (macro || reflaxe_runtime)

// avoid conflict with haxe.macro.Type after https://github.com/HaxeFoundation/haxe/pull/11168
import Type as HaxeType;

import haxe.display.Display.MetadataTarget;
import haxe.ds.ReadOnlyArray;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.BaseCompiler;
import reflaxe.compiler.NullTypeEnforcer;
import reflaxe.config.Define;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionArg;
import reflaxe.data.EnumOptionData;
import reflaxe.input.ClassHierarchyTracker;
import reflaxe.input.ModuleUsageTracker;

using reflaxe.helpers.ArrayHelper;
using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.TypeHelper;

/**
	The heart of Reflaxe.

	This singleton implements the generation by calling
	functions at various compiler phases.
**/
class ReflectCompiler {
	// =======================================================
	// * Public Members
	// =======================================================
	public static var Compilers: Array<BaseCompiler> = [];

	public static function Start() {
		#if (haxe_ver < "4.3.0")
		Sys.println("Reflaxe requires Haxe version 4.3.0 or greater.");
		return;
		#elseif eval
		static var called = false;
		if(!called) {
			if(#if eval !Context.defined("display") #else true #end) {
				Context.onAfterTyping(onAfterTyping);
				Context.onAfterGenerate(onAfterGenerate);
				checkServerCache();
			}
			called = true;
		} else {
			throw "reflaxe.ReflectCompiler.Start() called multiple times.";
		}
		#end
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

		final metaDesc: haxe.macro.Compiler.MetadataDescription = {
			metadata: name,
			doc: doc,
			params: params,
			platforms: [Cross],
			targets: targets
		};

		#if macro
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
	// * Caching System
	// =======================================================
	#if !reflaxe.disallow_build_cache_check
	public static var isCachedRebuild = false;
	static var rebuiltClasses: Null<Array<ClassType>> = null;
	#end

	#if !reflaxe.disallow_build_cache_check
	@:persistent static var isCachedRun = false;
	#end

	public static function checkServerCache() {
		#if !reflaxe.disallow_build_cache_check
		if(#if eval !Context.defined("display") #else true #end) {
			if(!isCachedRun) {
				isCachedRun = true;
			} else {
				rebuiltClasses = [];
				#if eval
				Compiler.addGlobalMetadata("", "@:build(reflaxe.ReflectCompiler.addToBuildCache())");
				#end
			}
		}
		#end
	}

	#if !reflaxe.disallow_build_cache_check
	static function addToBuildCache(): Null<Array<Field>> {
		final cls = #if eval Context.getLocalClass() #else null #end;
		if(cls != null && rebuiltClasses != null) {
			rebuiltClasses.push(cls.get());
		}
		return null;
	}
	#end

	// =======================================================
	// * Plugin System
	// =======================================================
	static var initCallbacks: Null<Array<Dynamic>> = null;

	/**
		Call this to access the BaseCompiler that's about to be used.
		This can be used to add callbacks to the hooks if desired.
	**/
	public static function onCompileBegin<T: BaseCompiler>(callback: (T) -> Void) {
		if(initCallbacks == null) initCallbacks = [];
		initCallbacks.push(callback);
	}

	static function callInitCallbacks<T: BaseCompiler>(compiler: T) {
		if(initCallbacks != null) {
			for(c in initCallbacks) {
				Reflect.callMethod({}, c, [compiler]);
			}
		}
	}

	// =======================================================
	// * Private Members
	// =======================================================
	static var haxeProvidedModuleTypes: Null<Array<ModuleType>>;

	static function onAfterTyping(moduleTypes: Array<ModuleType>) {
		haxeProvidedModuleTypes = moduleTypes;
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
			if(#if eval !Context.defined("display") #else true #end) {
				startCompiler(validCompilers[0]);
			}
		} else if(validCompilers.length > 1) {
			tooManyCompilersError(validCompilers);
		}
	}

	static function findEnabledCompilers(): Array<BaseCompiler> {
		final validCompilers = [];
		#if eval
		#if (haxe_ver > "5.0.0")
		final outputPath = switch(Compiler.getConfiguration().platform) {
			case CustomTarget(_): Compiler.getOutput();
			case _: "";
		}
		#end
		for(compiler in Compilers) {
			final outputDirDef = compiler.options.outputDirDefineName;
			final outputDir = Context.definedValue(outputDirDef);
			if(Context.defined(outputDirDef) && outputDir.length > 0) {
				compiler.setOutputDir(outputDir);
				validCompilers.push(compiler);
			#if (haxe_ver > "5.0.0")
			} else if(outputPath.length > 0) {
				compiler.setOutputDir(outputPath);
				validCompilers.push(compiler);
			#end
			} else {
				final compilerName = HaxeType.getClassName(HaxeType.getClass(compiler));
				final pos = Context.currentPos();
				final msg = 'The $compilerName compiler is enabled; however, the output directory (-D $outputDirDef) is not defined.';
				Context.error(msg, pos);
			}
		}
		#end
		return validCompilers;
	}

	static function tooManyCompilersError(compilers: Array<BaseCompiler>) {
		#if eval
		final compilerList = compilers.map(c -> HaxeType.getClassName(HaxeType.getClass(c))).join(" | ");
		final pos = Context.currentPos();
		final msg = 'Multiple compilers have been enabled, only one may be active per build: $compilerList';
		Context.error(msg, pos);
		#end
	}

	static function startCompiler(compiler: BaseCompiler) {
		#if (eval && reflaxe_measure)
		final start = new reflaxe.debug.MeasurePerformance();
		#end

		useCompiler(compiler);

		#if (eval && reflaxe_measure)
		start.measure("Reflaxe target compiled in %MILLI% milliseconds");
		#end
	}

	static function useCompiler(compiler: BaseCompiler) {
		// Copy over types provided by Haxe compiler
		final moduleTypes = compiler.filterTypes(haxeProvidedModuleTypes != null ? haxeProvidedModuleTypes.copy() : []);

		// Track Hierarchy
		if(compiler.options.trackClassHierarchy) {
			ClassHierarchyTracker.processAllClasses(moduleTypes);
		}

		// Apply other type filters
		final moduleTypes = applyModuleFilters(moduleTypes);

		// Start
		callInitCallbacks(compiler);
		compiler.onCompileStart();

		// Compile
		addClassesToCompiler(compiler, moduleTypes);

		// End
		compiler.onCompileEnd();
		for(callback in compiler.compileEndCallbacks) {
			callback();
		}

		// Compile any additional modules that
		// may be required after `onCompileEnd`.
		if(isManualDCE(compiler)) {
			dynamicallyAddModulesToCompiler(compiler);
		}

		// Generate files
		generateFiles(compiler);
		compiler.onOutputComplete();
	}

	/**
		Filters types based on defines and build cache.
	**/
	static function applyModuleFilters(moduleTypes: Array<ModuleType>) {
		final moduleTypes = applyDefineFilters(moduleTypes);
		final moduleTypes = applyBuildCacheCheckFilter(moduleTypes);
		return moduleTypes;
	}

	static function applyDefineFilters(moduleTypes: Array<ModuleType>) {
		#if (eval && reflaxe.only_generate)
		final allowedPacks = try { haxe.Json.parse(Context.definedValue(Define.OnlyGenerate)); } catch(_) { []; }
		return moduleTypes.filter(mt -> {
			final pack = mt.getCommonData().pack.join(".");
			for(allowed in allowedPacks) {
				if(StringTools.startsWith(pack, allowed)) {
					return true;
				}
			}
			return false;
		});
		#elseif (eval && reflaxe.generate_everything_except)
		final disallowedPacks = try { haxe.Json.parse(Context.definedValue(Define.GenerateEverythingExcept)); } catch(_) { []; }
		return moduleTypes.filter(mt -> {
			final pack = mt.getCommonData().pack.join(".");
			for(allowed in disallowedPacks) {
				if(StringTools.startsWith(pack, allowed)) {
					return false;
				}
			}
			return true;
		});
		#else
		return moduleTypes;
		#end
	}

	static function applyBuildCacheCheckFilter(moduleTypes: Array<ModuleType>) {
		#if !reflaxe.disallow_build_cache_check
		if(rebuiltClasses != null) {
			final result = moduleTypes.filter(mt -> {
				switch(mt) {
					case TClassDecl(_.get() => c): {
						for(cls in rebuiltClasses) {
							if(cls.name == c.name && cls.module == c.module && cls.pack.equals(c.pack)) {
								return true;
							}
						}
					}
					case _:
				}
				return false;
			});

			// If anything is filtered out, we ARE doing a cache rebuild.
			if(result.length != moduleTypes.length) {
				isCachedRebuild = true;
			}

			return result;
		}
		#end
		return moduleTypes;
	}

	static function getAllModulesTypesForCompiler(compiler: BaseCompiler, moduleTypes: ReadOnlyArray<ModuleType>): ReadOnlyArray<ModuleType> {
		return if(compiler.options.ignoreTypes.length > 0) {
			final ignoreTypes = compiler.options.ignoreTypes;
			moduleTypes.filter(function(moduleType) {
				return !ignoreTypes.contains(moduleType.getPath());
			});
		} else {
			moduleTypes;
		}
	}

	static function getAllKeepTypes(compiler: BaseCompiler, moduleTypes: ReadOnlyArray<ModuleType>): ReadOnlyArray<ModuleType> {
		final tracker = new ModuleUsageTracker(moduleTypes, compiler);
		return tracker.nonStdTypes().filter(m -> m.getCommonData().meta.has(":keep"));
	}

	/**
		Used internally for `getAllIncludedTypes`.
	**/
	static var noValueHaxeCompilerArguments = [
		"--no-output", "--interp", "--run", "-v", "--verbose", "--debug", "-debug", "--prompt", "-prompt",
		"--no-traces", "--display", "--times", "--no-inline", "--no-opt", "--flash-strict", "--version", "-version", 
		"-h", "--help", "-help", "--help-defines", "--help-user-defines", "--help-metas", "--help-user-metas",
		"--haxelib-global",
	];

	/**
		The intent of this is to return all types included directly via command
		line arguments or `.hxml`.

		Unfortunately, there is no official method to obtain these types, so
		the Haxe compiler arguments are re-parsed to find them.

		This function may be flawed, so please report if a type or package that should
		be included is not returned from this!!
	**/
	static function getAllIncludedTypes(compiler: BaseCompiler, moduleTypes: ReadOnlyArray<ModuleType>): ReadOnlyArray<ModuleType> {
		final compilerArguments = #if macro Compiler.getConfiguration().args #else [] #end;

		var i = 0;
		final includedPaths = [];
		while(i < compilerArguments.length) {
			final arg = compilerArguments[i];
			if(StringTools.startsWith(arg, "-")) {
				if(noValueHaxeCompilerArguments.contains(arg)) {
					i++;
				} else {
					// This is a argument has a value, so skip the next one.
					i += 2;
				}
			} else {
				// No named argument, so this must be an included module or pack.
				includedPaths.push(arg);
				i++;
			}
		}

		final tracker = new ModuleUsageTracker(moduleTypes, compiler);
		return tracker.nonStdTypes().filter(m -> {
			for(path in includedPaths) {
				if(m.getCommonData().startsWithDotPath(path)) {
					return true;
				}
			}
			return false;
		});
	}

	static function addClassesToCompiler(compiler: BaseCompiler, moduleTypes: Array<ModuleType>) {
		if(isManualDCE(compiler)) {
			for(m in getAllKeepTypes(compiler, moduleTypes)) {
				compiler.addModuleTypeForCompilation(m);
			}

			for(m in getAllIncludedTypes(compiler, moduleTypes)) {
				compiler.addModuleTypeForCompilation(m);
			}

			dynamicallyAddModulesToCompiler(compiler);
		} else {
			addModulesToCompiler(compiler, getAllModulesTypesForCompiler(compiler, moduleTypes));
		}
	}

	static function dynamicallyAddModulesToCompiler(compiler: BaseCompiler) {
		while(compiler.dynamicTypeStack.length > 0) {
			final temp = compiler.dynamicTypeStack;
			compiler.dynamicTypeStack = [];
			addModulesToCompiler(compiler, temp);
		}
	}

	static function addModulesToCompiler(compiler: BaseCompiler, modules: ReadOnlyArray<ModuleType>) {
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
			if(compiler.options.enforceNullTyping) {
				NullTypeEnforcer.checkClass(cls);
			}
			compiler.setupModule(TClassDecl(clsRef));
			if(compiler.shouldGenerateClass(cls)) {
				transpileClass(cls, compiler);
			}
		}

		for(enumRef in enumDecls) {
			final enm = enumRef.get();
			compiler.setupModule(TEnumDecl(enumRef));
			if(compiler.shouldGenerateEnum(enm)) {
				transpileEnum(enm, compiler);
			}
		}

		for(defRef in defDecls) {
			final def = defRef.get();
			compiler.setupModule(TTypeDecl(defRef));
			compiler.compileTypedef(def);
		}

		for(abstractRef in abstractDecls) {
			final ab = abstractRef.get();
			compiler.setupModule(TAbstract(abstractRef));
			compiler.compileAbstract(ab);
		}

		compiler.setupModule(null);
	}

	static function generateFiles(compiler: BaseCompiler) {
		compiler.generateFiles();
	}

	// =======================================================
	// * DCE helpers
	// =======================================================
	static function isDceOn(): Bool {
		return (#if eval Context.definedValue #else Compiler.getDefine #end ("dce")) != "no";
	}

	static function isManualDCE(compiler: BaseCompiler): Bool {
		return isDceOn() && compiler.options.manualDCE;
	}

	// =======================================================
	// * transpileClass
	// =======================================================
	static function transpileClass(cls: ClassType, compiler: BaseCompiler) {
		final varFields: Array<ClassVarData> = [];
		final funcFields: Array<ClassFuncData> = [];

		final ignoreExterns = compiler.options.ignoreExterns;

		final addField = function(field: ClassField, isStatic: Bool) {
			if(ignoreExterns && field.isExtern) {
				return;
			}

			#if reflaxe_extern_meta
			if(field.hasMeta(":reflaxe_extern")) {
				return;
			}
			#end

			switch(field.kind) {
				case FVar(readVarAccess, writeVarAccess): {
					if(shouldGenerateVar(field, compiler, isStatic, readVarAccess, writeVarAccess)) {
						final data = field.findVarData(cls, isStatic);
						if(data != null) {
							varFields.push(data);
						} else {
							throw "Variable information not found.";
						}
					}
				}
				case FMethod(methodKind): {
					if(shouldGenerateFunc(field, compiler, isStatic, methodKind)) {
						final data = field.findFuncData(cls, isStatic);
						if(data != null) {
							funcFields.push(preprocessFunction(compiler, field, data));
						} else {
							if(!compiler.options.ignoreBodilessFunctions) {
								#if eval
								Context.warning("Function information not found.", field.pos);
								#end
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
	
		compiler.compileClass(cls, varFields, funcFields);
	}

	static function preprocessFunction(compiler: BaseCompiler, field: ClassField, data: ClassFuncData): ClassFuncData {
		if(data.expr == null) {
			return data;
		}
		if(compiler.options.enforceNullTyping) {
			NullTypeEnforcer.modifyExpression(data.expr);
		}
		for(preprocessor in compiler.expressionPreprocessors) {
			preprocessor.process(data, compiler);
		}
		return data;
	}

	// =======================================================
	// * transpileEnum
	// =======================================================
	static function transpileEnum(enm: EnumType, compiler: BaseCompiler) {
		final options = [];
		for(name in enm.names) {
			final field = enm.constructs[name];
			if(field == null) continue;

			final args = switch(field.type) {
				case TFun(args, ret): args;
				case _: [];
			}

			final option = new EnumOptionData(enm, field, name);

			for(a in args) {
				final arg = new EnumOptionArg(option, a.t, a.opt, a.name);
				option.addArg(arg);
			}

			options.push(option);
		}

		compiler.compileEnum(enm, options);
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
				case [AccNormal | AccNo | AccCtor, _]: true;
				case [_, AccNormal | AccNo | AccCtor]: true;
				case _: !compiler.options.ignoreNonPhysicalFields;
			}
		}
	}

	static function shouldGenerateFunc(field: ClassField, compiler: BaseCompiler, isStatic: Bool, kind: MethodKind): Bool {
		return compiler.shouldGenerateClassField(field);
	}
}

#end
