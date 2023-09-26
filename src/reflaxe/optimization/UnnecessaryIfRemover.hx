// =======================================================
// * UnnecessaryBlockRemover
// =======================================================

package reflaxe.optimization;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;

/**
	Removes unnecessary blocks that do not introduce
	conflicting variable declarations.
**/
class UnnecessaryIfRemover {
	public static function optimize(el: Array<TypedExpr>): Array<TypedExpr> {
		final result = [];
		for(e in el) {
			result.push(removeIfs(e));
		}
		return result;
	}

	static function removeIfs(e: TypedExpr): TypedExpr {
		switch(e.expr) {
			case TIf(econd, eif, eelse): {
				switch(econd.unwrapParenthesis().expr) {
					case TConst(TBool(true)): {
						return eif;
					}
					case TConst(TBool(false)): {
						if(eelse != null) {
							return eelse;
						} else {
							return {
								expr: TBlock([]),
								pos: e.pos,
								t: e.t
							}
						}
					}
					case _: {}
				}
			}
			case _: {}
		}
		return haxe.macro.TypedExprTools.map(e, removeIfs);
	}
}

#end
