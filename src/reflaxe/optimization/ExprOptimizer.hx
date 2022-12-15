// =======================================================
// * ExprOptimizer
//
// Converts block-like expressions to a list of expressions.
// Non block-like expressions are returned as an array
// of expressions only containing themselves.
//
// Useful for quickly converting the single expression
// of a function to a list of expressions which is how
// most non-Haxe languages handle function content.
// =======================================================

package reflaxe.optimization;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;

class ExprOptimizer {
	public static function optimizeAndUnwrap(expr: TypedExpr): Array<TypedExpr> {
		var el = unwrapBlock(optimizeBlocks(expr));
		el = UnnecessaryBlockRemover.optimize(el);
		el = UnnecessaryVarDeclRemover.optimize(el);
		return el;
	}

	public static function unwrapBlock(expr: TypedExpr): Array<TypedExpr> {
		return switch(expr.expr) {
			case TBlock(exprList): exprList;
			case _: [expr.copy()];
		}
	}

	public static function optimizeBlocks(expr: TypedExpr): TypedExpr {
		return switch(expr.expr) {
			case TBlock(exprList): {
				if(exprList.length == 1) {
					return exprList[0];
				} else {
					for(i in 0...exprList.length) {
						exprList[i] = optimizeBlocks(exprList[i]);
					}
					return {
						expr: TBlock(exprList),
						pos: expr.pos,
						t: expr.t
					};
				}
			}
			case _: expr.copy();
		}
	}
}

#end
