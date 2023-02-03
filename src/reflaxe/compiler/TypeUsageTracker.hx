package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.BaseCompiler;

using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.TypeHelper;

typedef TypeUsageMap = Map<TypeUsageLevel, Array<ModuleType>>;

enum abstract TypeUsageLevel(Int) from Int to Int {
	// An expression of this type exists.
	var Expression = 1;

	// A local variable declaration with this type exists in an expression.
	var VariableType = 2;

	// This type is constructed in an expression (i.e. "new ThisType").
	var Constructed = 4;

	// This type is used as a parameter or return type for a function in the class. 
	var FunctionDeclaration = 8;

	// A variable field with this type exists.
	var VariableDeclaration = 16;

	// This type is extended or implemented from.
	var ExtendedFrom = 32;
}

class TypeUsageTracker {
	// We want to track instances where an explicit "function type" needs to be declared.
	// This can be helpful in cases where an import is required for a function wrapper object.
	//
	// For example, `#include <functional>` is required when using `std::function` in C++.
	//
	// For this purpose, we use haxe.Function in the result Maps. Obtaining a reference
	// to `haxe.Function` is not easy, so we obtain it once in `init` and store here.
	static var functionType: Type;

	// Called at start of Reflaxe
	public static function init() {
		// Store `haxe.Function` Type in "functionType"
		for(funcType in Context.getModule("haxe.Function")) {
			switch(funcType) {
				case TAbstract(t, params): {
					if(t.get().name == "Function") {
						functionType = funcType;
					}
				}
				case _: {}
			}
		}
	}

	// Get all the ModuleTypes by a single ModuleType.
	public static function trackTypesInModuleType(moduleType: ModuleType): TypeUsageMap {
		final modules: Map<String, { m: ModuleType, level: Int }> = [];

		// Helper function for tracking ModuleType.
		function addModuleType(mt: ModuleType, level: TypeUsageLevel) {
			final id = mt.getUniqueId();
			if(!modules.exists(id)) {
				modules.set(id, { m: mt, level: level });
			} else {
				modules.get(id).level |= level;
			}
		}

		// Helper function for tracking Type.
		function addType(t: Type, level: TypeUsageLevel) {
			addModuleType(t.toModuleType(), level);

			switch(t) {
				// If the type is a function, we must extract the declaration types and add those.
				case TFun(args, ret): {
					for(a in args) {
						addType(a.t, level);
					}
					addType(ret, level);
					addType(functionType, level);
				}

				// If there are any type parameters in use, be sure to include them as well.
				case TEnum(_, params) |
					TInst(_, params) |
					TType(_, params) |
					TAbstract(_, params): {
					for(p in params) {
						addType(p, level);
					}
				}

				case _: {}
			}
		}

		// Helper function for tracking type that must be TFun
		function addFunction(t: Type) {
			switch(t) {
				case TFun(args, ret): {
					for(a in args) {
						addType(a.t, FunctionDeclaration);
					}
					addType(ret, FunctionDeclaration);
				}
				case _: {}
			}
		}

		// Helper function for tracking ClassField.
		function addClassField(clsField: ClassField, isStatic: Bool = false) {
			switch(clsField.kind) {
				case FVar(read, write): {
					addType(clsField.type, VariableDeclaration);
				}
				case FMethod(k): {
					addFunction(clsField.type);
				}
			}
		}

		switch(moduleType) {
			case TClassDecl(c): {
				final cls = c.get();

				// Super Class
				if(cls.superClass != null) {
					addModuleType(TClassDecl(cls.superClass.t), ExtendedFrom);
					for(t in cls.superClass.params) {
						addType(t, ExtendedFrom);
					}
				}

				// Interfaces
				for(i in cls.interfaces) {
					addModuleType(TClassDecl(i.t), ExtendedFrom);
					for(t in i.params) {
						addType(t, ExtendedFrom);
					}
				}

				// Constructor
				if(cls.constructor != null) {
					addClassField(cls.constructor.get());
				}

				// Fields
				for(field in cls.fields.get()) {
					addClassField(field);
				}

				// Static Fields
				for(field in cls.statics.get()) {
					addClassField(field, true);
				}
			}

			case TEnumDecl(e): {
				final enm = e.get();

				for(name => field in enm.constructs) {
					addFunction(field.type);
				}
			}

			case TTypeDecl(defType): {
				addType(Context.follow(TType(defType, [])), ExtendedFrom);
			}

			case TAbstract(a): {
				addType(Context.followWithAbstracts(TAbstract(a, [])), ExtendedFrom);
			}
		}

		// Format the final result.
		final result: TypeUsageMap = [];
		for(id => moduleData in modules) {
			for(i in 0...5) {
				final level: TypeUsageLevel = cast Math.pow(2, i);
				if((moduleData.level & level) != 0) {
					if(!result.exists(level)) {
						result.set(level, []);
					}
					result[level].push(moduleData.m);
				}
			}
		}

		return result;
	}
}

#end
