// =======================================================
// * ExprOptimizer
// =======================================================

package reflaxe.preprocessors.implementations;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.helpers.Context;

using reflaxe.helpers.TypedExprHelper;

/**
	Converts block expressions with a single expression to the expression.

	This...
	```haxe
	{
		trace("Hello!");
	}
	```

	...would be converted to this:
	```haxe
	trace("Hello!");
	```
**/
class RemoveSingleExpressionBlocksImpl {
	public static function process(expr: TypedExpr): TypedExpr {
		var result = expr;

		switch(expr.expr) {
			case TBlock(exprList): {
				if(exprList.length == 1) {
					result = exprList[0];
				}
			}
			case _: 
		}

		return haxe.macro.TypedExprTools.map(result, process);
	}
}

#end
