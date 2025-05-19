// =======================================================
// * ModuleUsageTracker
// =======================================================

package reflaxe.input;

#if (macro || reflaxe_runtime)

import haxe.ds.ReadOnlyArray;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Type;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.TypeHelper;

/**
	Class required for Reflaxe's "Smart DCE" feature.

	This class attempts to parse through the list of "to be compiled"
	module types Haxe produces post-typing, and cuts them down
	to a smaller selection for cleaner output.
**/
class ModuleUsageTracker {
	var allModuleTypes: ReadOnlyArray<ModuleType>;
	var compiler: BaseCompiler;

	var outputTypes: Array<ModuleType>;
	var outputTypeMap: Map<String, Bool>;

	public function new(types: ReadOnlyArray<ModuleType>, compiler: BaseCompiler) {
		allModuleTypes = types;
		this.compiler = compiler;

		outputTypes = [];
		outputTypeMap = [];
	}

	public function filteredTypes(stdMeta: Null<Array<String>> = null): Array<ModuleType> {
		final userTypes = nonStdTypes(stdMeta);
		for(ut in userTypes) {
			addUsedModuleType(ut);
		}
		return outputTypes;
	}

	public function nonStdTypes(stdMeta: Null<Array<String>> = null): Array<ModuleType> {
		return allModuleTypes.filter(t -> {
			return !t.getCommonData().isReflaxeExtern() && !isStdType(t, stdMeta);
		});
	}

	// =======================================================
	// Type tracking
	// =======================================================
	function addUsedModuleType(moduleType: Null<ModuleType>) {
		if(moduleType == null || hasModuleType(moduleType)) {
			return;
		}

		outputTypes.push(moduleType);
		outputTypeMap[moduleTypeId(moduleType)] = true;

		switch(moduleType) {
			case TClassDecl(clsRef): {
				final cls = clsRef.get();
				if(cls.superClass != null) {
					addUsedModuleType(TClassDecl(cls.superClass.t));
				}
				final fields = cls.fields.get().concat(cls.statics.get());
				for(f in fields) {
					addUsedType(f.type);

					final te = f.expr();
					if(te != null) {
						addUsedExpr(te);
					}
				}
			}
			case TEnumDecl(enumRef): {
				final enm = enumRef.get();
				for(_ => f in enm.constructs) {
					addUsedType(f.type);
				}
			}
			case TTypeDecl(defTypeRef) if(compiler.options.unwrapTypedefs): {
				final result = unwrapTypedef(defTypeRef.get());
				if(result != null) {
					addUsedModuleType(result);
				}
			}
			case TAbstract(abRef): {
				addUsedType(abRef.get().type);
			}
			case _:
		}
	}

	function unwrapTypedef(defType: DefType): Null<ModuleType> {
		final type = defType.type;
		final anonModuleType = type.convertAnonToModuleType();
		return if(anonModuleType != null) {
			anonModuleType;
		} else {
			type.toModuleType();
		}
	}

	function addUsedType(type: Type) {
		final params = type.getParams();
		if(params != null) {
			for(p in params) {
				addUsedType(p);
			}
		}
		
		switch(type) {
			case TFun(args, ret): {
				for(a in args) addUsedType(a.t);
				addUsedType(ret);
			}
			case TAnonymous(a): {
				for(field in a.get().fields) {
					addUsedType(field.type);
				}
			}
			case TDynamic(t): {
				if(t != null) {
					addUsedType(t);
				}
			}
			case _: {
				final mt = TypeHelper.toModuleType(type);
				if(mt != null) {
					addUsedModuleType(mt);
				}
			}
		}
	}

	function addUsedExpr(expr: TypedExpr) {
		haxe.macro.TypedExprTools.iter(expr, checkExprForTypes);
	}

	function checkExprForTypes(expr: TypedExpr) {
		addUsedType(expr.t);
		haxe.macro.TypedExprTools.iter(expr, checkExprForTypes);
	}

	static function moduleTypeId(moduleType: ModuleType): String {
		final data = ModuleTypeHelper.getCommonData(moduleType);
		return data.module + "|" + data.name;
	}

	static function typeId(type: Type): String {
		final mt = TypeHelper.toModuleType(type);
		return if(mt != null) {
			moduleTypeId(mt);
		} else {
			"";
		}
	}

	function hasModuleType(moduleType: ModuleType): Bool {
		final id = moduleTypeId(moduleType);
		return outputTypeMap.exists(id) && outputTypeMap[id] == true;
	}

	function hasType(type: Type): Bool {
		final mt = TypeHelper.toModuleType(type);
		return if(mt != null) {
			hasModuleType(mt);
		} else {
			false;
		}
	}

	/**
		Checks whether a ModuleType is a member of either the Haxe standard library
		or the standard library of the target (using the `customStdMeta` option).
	**/
	static function isStdType(type: ModuleType, stdMeta: Null<Array<String>> = null): Bool {
		final cd = type.getCommonData();
		if(cd.hasMeta(":coreApi") || cd.hasMeta(":pseudoCoreApi")) {
			return true;
		}

		if(stdMeta != null) {
			for(m in stdMeta) {
				if(cd.hasMeta(m)) {
					return true;
				}
			}
		}

		var onStdPath = false;
		#if macro
		for(path in Compiler.getConfiguration().stdPath) {
			if(StringTools.startsWith(Context.getPosInfos(cd.pos).file, path)) {
				onStdPath = true;
				break;
			}
		}
		#end

		return onStdPath;
	}
}

#end
