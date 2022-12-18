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
}

#end
