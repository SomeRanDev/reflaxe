// =======================================================
// * ExprHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;

/**
	Quick static extensions to help with `Expr`.
**/
class ExprHelper {
	public static function getConstString(e: Expr): String {
		return switch(e.expr) {
			case EConst(CString(s, _)): s;
			case _: "";
		}
	}

	public static function unwrapParenthesisMetaAndStoredType(e: Expr): Expr {
		return switch(e.expr) {
			case EMeta({ name: ":storedTypedExpr" }, _): {
				final e2 = Context.getTypedExpr(Context.typeExpr(e));
				unwrapParenthesisMetaAndStoredType(e2);
			}
			case EMeta(_, e2) | EParenthesis(e2): unwrapParenthesisMetaAndStoredType(e2);
			case _: e;
		}
	}
}

#end
