// =======================================================
// * ExprHelper
//
// Quick static extensions to help with Expr.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;

class ExprHelper {
	public static function getConstString(e: Expr): String {
		return switch(e.expr) {
			case EConst(CString(s, _)): s;
			case _: "";
		}
	}
}

#end
