// =======================================================
// * TypedExprHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.FieldAccessHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.TypeHelper;

/**
	Helpful functions for `TypedExpr` class.
**/
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
			case _: expr;
		}
	}

	public static function wrapParenthesis(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TParenthesis(e): e;
			case _: { expr: TParenthesis(expr), pos: expr.pos, t: expr.t };
		}
	}

	/**
		Only wraps with parenthesis if the expression is order-sensitive.
	**/
	public static function wrapParenthesisIfOrderSensitive(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TBinop(_, _, _) | TUnop(_, _, _): wrapParenthesis(expr);
			case _: expr;
		}
	}

	public static function unwrapBlock(expr: TypedExpr): Array<TypedExpr> {
		return switch(expr.expr) {
			case TBlock(exprList): exprList;
			case _: [copy(expr)];
		}
	}

	public static function ensureBlock(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TBlock(_): expr;
			case _: copy(expr, TBlock([expr]));
		}
	}

	public static function unwrapMeta(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TParenthesis(e): {
				unwrapMeta(e);
			}
			case TMeta(_, e): {
				unwrapMeta(e);
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

	public static function hasMeta(expr: TypedExpr, name: String): Bool {
		return switch(expr.expr) {
			case TParenthesis(e): {
				hasMeta(e, name);
			}
			case TMeta(m, e): {
				if(m.name == name) true;
				else hasMeta(e, name);
			}
			case e: false;
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
						case FStatic(_, fieldRef): {
							switch(fieldRef.get().type) {
								case TFun(args, _): {
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

	/**
		If this is an expression that is being called, this function
		checks if it has any type parameters applied and returns them.
	**/
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

	public static function isThisExpr(e: TypedExpr): Bool {
		return switch(unwrapParenthesis(e).expr) {
			case TConst(TThis): true;
			case _: false;
		}
	}

	public static function getFieldAccess(expr: TypedExpr, unwrapCall: Bool = false): Null<FieldAccess> {
		return switch(unwrapParenthesis(expr).expr) {
			case TCall(e, _) if(unwrapCall): getFieldAccess(e);
			case TField(_, fa): fa;
			case _: null;
		}
	}

	public static function getFieldAccessExpr(expr: TypedExpr, unwrapCall: Bool = false): Null<TypedExpr> {
		return switch(unwrapParenthesis(expr).expr) {
			case TCall(e, _) if(unwrapCall): getFieldAccessExpr(e);
			case TField(e, _): e;
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

	public static function getClassField(expr: TypedExpr, unwrapCall: Bool = false): Null<ClassField> {
		return getFieldAccess(expr, unwrapCall)?.getClassField();
	}

	public static function isStaticCall(expr: TypedExpr, classPath: String, funcName: String, allowNoCall: Bool = false): Null<Array<TypedExpr>> {
		return switch(unwrapParenthesis(expr).expr) {
			case TCall(callExpr, callArgs): {
				if(isStaticField(callExpr, classPath, funcName)) {
					callArgs;
				} else {
					null;
				}
			}
			case _ if(allowNoCall && isStaticField(expr, classPath, funcName)): {
				[];
			}
			case _: null;
		}
	}

	public static function isStaticField(expr: TypedExpr, classPath: String, funcName: String, unwrapCasts = false): Bool {
		return switch(getFieldAccess(unwrapCasts ? unwrapUnsafeCasts(expr) : unwrapParenthesis(expr))) {
			case FStatic(clsRef, cfRef): {
				if(clsRef.get().matchesDotPath(classPath) && cfRef.get().name == funcName) {
					true;
				} else {
					false;
				}
			}
			case _: false;
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
				TIdent(_) |
				TFunction(_): false;

			case TBinop(OpAssign | OpAssignOp(_) | OpInterval | OpArrow | OpIn, _, _): true;

			case TBinop(_, e1, e2) | TArray(e1, e2):
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
		}
	}
}

#end
