// =======================================================
// * TypedExprHelper
//
// Helpful functions for TypedExpr class.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

class TypedExprHelper {
	public static function copy(e: TypedExpr, newDef: Null<TypedExprDef> = null): TypedExpr {
		return {
			expr: newDef != null ? newDef : e.expr,
			pos: e.pos,
			t: e.t
		}
	}
}

#end
