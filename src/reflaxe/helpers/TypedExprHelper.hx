// =======================================================
// * TypedExprHelper
//
// Helpful functions for TypedExpr class.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.TypeHelper;

class TypedExprHelper {
	public static function equals(e: TypedExpr, other: TypedExpr): Bool {
		#if macro
		return haxe.macro.TypedExprTools.toString(e) == haxe.macro.TypedExprTools.toString(other);
		#else
		return false;
		#end
	}

	public static function make(e: TypedExprDef, t: Type, pos: Null<Position> = null): TypedExpr {
		return {
			expr: e,
			t: t,
			pos: pos ?? PositionHelper.unknownPos()
		}
	}

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

	public static function isNullExpr(e: TypedExpr): Bool {
		return switch(unwrapParenthesis(e).expr) {
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

	public static function isDynamicAccess(expr: TypedExpr): Null<String> {
		return switch(unwrapParenthesis(expr).expr) {
			case TField(e, fa): {
				switch(fa) {
					case FDynamic(s): s;
					case _: null;
				}
			}
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

	/**
		Returns `false` if it's impossible for the `TypedExpr` to modify
		the state of the program. For example: it's a number literal
		or identifier.

		Not guarenteed to modify state if returns `true`, just possible.
		For example: calls function.

		Helpful for optimizing.
	**/
	public static function isMutator(expr: TypedExpr): Bool {
		return switch(expr.expr) {
			case TConst(_) |
				TLocal(_) |
				TField(_, _) |
				TTypeExpr(_) |
				TIdent(_): false;

			case TBinop(_, e1, e2):
				isMutator(e1) || isMutator(e2);

			case TParenthesis(e) |
				TCast(e, _) |
				TMeta(_, e) |
				TEnumParameter(e, _, _) |
				TEnumIndex(e): isMutator(e);

			case TObjectDecl(fields): {
				for(f in fields) {
					if(isMutator(f.expr)) return true;
				}
				false;
			}
			case TArrayDecl(el) | TBlock(el): {
				for(e in el) {
					if(isMutator(e)) return true;
				}
				false;
			}

			case TCall(_, _) |
				TNew(_, _, _) |
				TUnop(OpIncrement | OpDecrement | OpSpread, _, _) |
				TVar(_, _) |
				TReturn(_) |
				TBreak |
				TContinue |
				TThrow(_): true;

			case TUnop(_, _, _): false;

			case TFor(_, e1, e2): {
				isMutator(e1) || isMutator(e2);
			}

			case TIf(econd, eif, eelse): {
				isMutator(econd) || isMutator(eif) || (eelse != null && isMutator(eelse));
			}

			case TWhile(econd, e, _): {
				isMutator(econd) || isMutator(e);
			}

			case TSwitch(e, cases, edef): {
				if(isMutator(e) || (edef != null && isMutator(edef))) {
					true;
				} else {
					for(c in cases) {
						if(isMutator(c.expr)) return true;
					}
					false;
				}
			}

			case TTry(e, catches): {
				if(isMutator(e)) true;
				else {
					for(c in catches) {
						if(isMutator(c.expr)) return true;
					}
					false;
				}
			}

			case _: false;
		}
	}
}

#end
