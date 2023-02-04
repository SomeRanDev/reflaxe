// =======================================================
// * ModuleUsageTracker
//
// Class required for Reflaxe's "Smart DCE" feature.
//
// This class attempts to parse through the list of "to be compiled"
// module types Haxe produces post-typing, and cuts them down
// to a smaller selection for cleaner output.
// =======================================================

package reflaxe.input;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.TypeHelper;

typedef CommonModuleTypeData = {
	pack: Array<String>,
	pos: Position,
	module: String,
	name: String
}

class ModuleUsageTracker {
	var allModuleTypes: Array<ModuleType>;
	var compiler: BaseCompiler;

	var outputTypes: Array<ModuleType>;
	var outputTypeMap: Map<String, Bool>;

	public function new(types: Array<ModuleType>, compiler: BaseCompiler) {
		allModuleTypes = types;
		this.compiler = compiler;

		outputTypes = [];
		outputTypeMap = [];
	}

	public function filteredTypes(): Array<ModuleType> {
		final userTypes = nonStdTypes();
		for(ut in userTypes) {
			addUsedModuleType(ut);
		}
		return outputTypes;
	}

	function nonStdTypes(): Array<ModuleType> {
		return allModuleTypes.filter(t -> !isStdType(t));
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

	// -------------------------------------------------------
	// Convoluted, hacky method of testing whether a ModuleType
	// is a member of the Haxe standard library. If the 
	// Position of the ModuleType is an absolute path that 
	// contains "std" right before the expected module file
	// path, it's likely a member of the standard lib.
	static function isStdType(type: ModuleType): Bool {
		final pos = Context.getPosInfos(type.getPos());
		if(!haxe.io.Path.isAbsolute(pos.file)) {
			return false;
		}
		final modulePath = type.getModule();
		final stdFilePathBegin = StringTools.replace(modulePath, ".", "/");
		final stdFilePath = "std/" + stdFilePathBegin + ".hx";
		return StringTools.endsWith(pos.file, stdFilePath);
	}
}

#end
