// =======================================================
// * TypedExprHelper
//
// Helpful functions for TypedExpr class.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.ClassTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.TypeHelper;

class TypedExprHelper {
	public static function copy(e: TypedExpr, newDef: Null<TypedExprDef> = null): TypedExpr {
		return {
			expr: newDef != null ? newDef : e.expr,
			pos: e.pos,
			t: e.t
		}
	}

	public static function unwrapParenthesis(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TParenthesis(e): {
				unwrapParenthesis(e);
			}
			case e: expr;
		}
	}

	public static function unwrapUnsafeCasts(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TParenthesis(e): {
				unwrapUnsafeCasts(e);
			}
			case TCast(e, maybeModuleType): {
				if(maybeModuleType == null) {
					unwrapUnsafeCasts(e);
				} else {
					expr;
				}
			}
			case _: expr;
		}
	}

	public static function getDeclarationMeta(e: TypedExpr, arguments: Null<Array<TypedExpr>> = null): Null<{ thisExpr: Null<TypedExpr>, meta: Null<MetaAccess> }> {
		return switch(e.expr) {
			case TField(ethis, fa): {
				var thisExpr = ethis;

				// This might be a static function from an abstract.
				// In that case, the "this" expression would be the first argument.
				if(arguments != null) {
					switch(fa) {
						case FStatic(clsRef, fieldRef): {
							switch(fieldRef.get().type) {
								case TFun(args, ret): {
									// If a static function, and the first argument is "this",
									// we can assume it's an abstract function.
									if(args.length > 0 && args[0].name == "this") {
										thisExpr = arguments[0];
									}
								}
								case _: {}
							}
						}
						case _: {}
					}
				}
				
				{
					thisExpr: thisExpr,
					meta: fa.getFieldAccessNameMeta().meta
				};
			}
			case TVar(tvar, _): { thisExpr: e, meta: tvar.meta };
			case TEnumParameter(_, ef, _): { thisExpr: e, meta: ef.meta };
			case TMeta(_, e1): getDeclarationMeta(e1, arguments);
			case TParenthesis(e1): getDeclarationMeta(e1, arguments);
			case TNew(clsTypeRef, _, _): {
				final c = clsTypeRef.get().constructor;
				if(c != null) {
					{ thisExpr: null, meta: c.get().meta };
				} else {
					null;
				}
			}
			case _: null;
		}
	}

	// If this is an expression that is being called, this function
	// checks if it has any type parameters applied and returns them.
	public static function getFunctionTypeParams(e: TypedExpr, overrideReturnType: Null<Type> = null): Null<Array<Type>> {
		final classField = getClassField(e);
		return if(classField != null) {
			final t = switch(e.t) {
				case TFun(args, ret) if(overrideReturnType != null): {
					TFun(args, overrideReturnType);
				}
				case _: e.t;
			}
			t.findResolvedTypeParams(classField);
		} else {
			null;
		}
	}

	public static function isNull(e: TypedExpr): Bool {
		return switch(e.expr) {
			case TConst(TNull): true;
			case _: false;
		}
	}

	public static function getFieldAccess(expr: TypedExpr): Null<FieldAccess> {
		return switch(unwrapParenthesis(expr).expr) {
			case TField(e, fa): fa;
			case _: null;
		}
	}

	public static function getClassField(expr: TypedExpr): Null<ClassField> {
		return switch(getFieldAccess(expr)) {
			case FInstance(_, _, cfRef): cfRef.get();
			case FStatic(_, cfRef): cfRef.get();
			case FAnon(cfRef): cfRef.get();
			case FClosure(_, cfRef): cfRef.get();
			case _: null;
		}
	}

	public static function isStaticCall(expr: TypedExpr, classPath: String, funcName: String): Null<Array<TypedExpr>> {
		return switch(unwrapParenthesis(expr).expr) {
			case TCall(callExpr, callArgs): {
				switch(getFieldAccess(callExpr)) {
					case FStatic(clsRef, cfRef): {
						if(clsRef.get().matchesDotPath(classPath) && cfRef.get().name == funcName) {
							callArgs;
						} else {
							null;
						}
					}
					case _: null;
				}
			}
			case _: null;
		}
	}
}

#end
