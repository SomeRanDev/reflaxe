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

import reflaxe.helpers.Context;

using reflaxe.helpers.TypedExprHelper;

class ExprOptimizer {
	public static function optimizeAndUnwrap(expr: TypedExpr): Array<TypedExpr> {
		var el = unwrapBlock(flattenSingleExprBlocks(expr));
		el = UnnecessaryIfRemover.optimize(el);
		el = UnnecessaryBlockRemover.optimize(el);
		el = UnnecessaryVarDeclRemover.optimize(el);
		el = UnnecessaryVarAliasRemover.optimize(el);
		el = MarkUnusedVariables.mark(el);
		return el;
	}

	public static function unwrapBlock(expr: TypedExpr): Array<TypedExpr> {
		return switch(expr.expr) {
			case TBlock(exprList): exprList;
			case _: [expr.copy()];
		}
	}

	public static function flattenSingleExprBlocks(expr: TypedExpr): TypedExpr {
		var result = expr;

		switch(expr.expr) {
			case TBlock(exprList): {
				if(exprList.length == 1) {
					result = exprList[0];
				}
			}
			case _: 
		}

		return haxe.macro.TypedExprTools.map(result, flattenSingleExprBlocks);
	}
}

#end
