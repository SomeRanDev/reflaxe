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

	// A static variable or function from this type is used.
	var StaticAccess = 4;

	// This type is constructed in an expression (i.e. "new ThisType").
	var Constructed = 8;

	// This type is used as a parameter or return type for a function in the class. 
	var FunctionDeclaration = 16;

	// A variable field with this type exists.
	var VariableDeclaration = 32;

	// This type is extended or implemented from.
	var ExtendedFrom = 64;

	public static function LevelCount() return 7;

	@:op(A>B) function gt(o:TypeUsageLevel): Bool;
	@:op(A<B) function lt(o:TypeUsageLevel): Bool;
	@:op(A>=B) function gte(o:TypeUsageLevel): Bool;
	@:op(A<=B) function lte(o:TypeUsageLevel): Bool;
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

		var addType: Null<(Null<Type>, TypeUsageLevel) -> Void> = null;

		// Helper function for tracking ModuleType.
		function addModuleType(mt: Null<ModuleType>, level: TypeUsageLevel) {
			if(mt == null) return;
			final id = mt.getUniqueId();
			var newType = true;

			if(!modules.exists(id)) {
				modules.set(id, { m: mt, level: level });
			} else if((modules.get(id).level & level) == 0) {
				modules.get(id).level |= level;
			} else {
				newType = false;
			}

			if(newType) {
				switch(mt) {
					case TAbstract(a): {
						addType(Context.followWithAbstracts(TypeHelper.fromModuleType(mt)), level);
					}
					case _:
				}
			}
		}

		// Helper function for tracking Type.
		addType = function(t: Null<Type>, level: TypeUsageLevel) {
			if(t == null) return;
			final typeMt = t.toModuleType();
			if(typeMt != null) {
				addModuleType(typeMt, level);
			}

			switch(t) {
				// If the type is a function, we must extract the declaration types and add those.
				case TFun(args, ret): {
					for(a in args) {
						addType(a.t, level);
					}
					addType(ret, level);
					addType(functionType, level);
				}

				// If an anonymous structure, extract the types of the fields.
				case TAnonymous(anonRef): {
					for(f in anonRef.get().fields) {
						addType(f.type, level);
					}
				}

				case _: {}
			}

			// If there are any type parameters in use, be sure to include them as well.
			final params = t.getParams();
			if(params != null) {
				for(p in params) {
					addType(p, level);
				}
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

		// Helper function adding all the types contained in the expression.
		// Recursively applies to all expressions contained within.
		function addTypedExpr(te: TypedExpr) {
			// If it's a static field access, add the type being accessed.
			switch(te.expr) {
				case TField(_, fa): {
					switch(fa) {
						case FStatic(clsRef, clsFieldRef): {
							addType(TypeHelper.fromModuleType(TClassDecl(clsRef)), StaticAccess);
						}
						case _:
					}
				}
				case _:
			}

			// Add the expression's type to the appropriate usage level.
			switch(te.expr) {
				case TNew(clsRef, params, el): {
					addType(TInst(clsRef, params), Constructed);
				}
				case TVar(tvar, maybeExpr): {
					addType(tvar.t, VariableType);
				}
				case _: {
					addType(te.t, Expression);
				}
			}

			// Iterate through all the sub-expressions.
			haxe.macro.TypedExprTools.iter(te, addTypedExpr);
		}

		// Helper function for tracking ClassField.
		function addClassField(clsField: ClassField, isStatic: Bool = false) {
			final e = clsField.expr();
			if(e != null) {
				addTypedExpr(e);
			}
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
				//Context.follow(TypeHelper.fromModuleType(moduleType))
				addType(defType.get().type, ExtendedFrom);
			}

			case TAbstract(a): {
				addType(Context.followWithAbstracts(TypeHelper.fromModuleType(moduleType)), ExtendedFrom);
			}
		}

		// Format the final result.
		final result: TypeUsageMap = [];
		for(i in 0...TypeUsageLevel.LevelCount()) {
			final level = Std.int(Math.pow(2, i));
			result.set(cast level, []);
		}
		for(id => moduleData in modules) {
			for(i in 0...TypeUsageLevel.LevelCount()) {
				final level = Std.int(Math.pow(2, i));
				if((moduleData.level & level) != 0) {
					result[level].push(moduleData.m);
				}
			}
		}

		return result;
	}
}

#end
