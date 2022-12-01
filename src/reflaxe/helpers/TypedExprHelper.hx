// =======================================================
// * TypedExprHelper
//
// Helpful functions for TypedExpr class.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

class TypedExprHelper {
	public static function copy(e: TypedExpr): TypedExpr {
		return {
			expr: e.expr,
			pos: e.pos,
			t: e.t
		}
	}
}

#end
