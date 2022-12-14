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

	public static function getDeclarationMeta(e: TypedExpr): Null<MetaAccess> {
		return switch(e.expr) {
			case TField(_, fa): fa.getFieldAccessNameMeta().meta;
			case TVar(tvar, _): tvar.meta;
			case TEnumParameter(_, ef, _): ef.meta;
			case TMeta(_, e1): getDeclarationMeta(e1);
			case TParenthesis(e1): getDeclarationMeta(e1);
			case _: null;
		}
	}
}

#end
