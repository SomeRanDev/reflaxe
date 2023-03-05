// =======================================================
// * TypedExprHelper
//
// Helpful functions for TypedExpr class.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.NameMetaHelper;

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

	public static function getDeclarationMeta(e: TypedExpr): Null<{ thisExpr: Null<TypedExpr>, meta: Null<MetaAccess> }> {
		return switch(e.expr) {
			case TField(ethis, fa): { thisExpr: ethis, meta: fa.getFieldAccessNameMeta().meta };
			case TVar(tvar, _): { thisExpr: e, meta: tvar.meta };
			case TEnumParameter(_, ef, _): { thisExpr: e, meta: ef.meta };
			case TMeta(_, e1): getDeclarationMeta(e1);
			case TParenthesis(e1): getDeclarationMeta(e1);
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

	public static function isNull(e: TypedExpr): Bool {
		return switch(e.expr) {
			case TConst(TNull): true;
			case _: false;
		}
	}

	public static function getClassField(expr: TypedExpr): Null<ClassField> {
		return switch(expr.expr) {
			case TParenthesis(e): getClassField(e);
			case TField(e, fa): {
				switch(fa) {
					case FInstance(_, _, cfRef): cfRef.get();
					case FStatic(_, cfRef): cfRef.get();
					case FAnon(cfRef): cfRef.get();
					case FClosure(_, cfRef): cfRef.get();
					case _: null;
				}
			}
			case _: null;
		}
	}
}

#end
