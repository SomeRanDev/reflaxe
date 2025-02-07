// =======================================================
// * UnnecessaryBlockRemover
// =======================================================

package reflaxe.preprocessors.implementations;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;

/**
	Removes unnecessary if statements that are hardcoded with `true` or `false`.

	This...
	```haxe
	if(true) {
		trace("Hello!");
	}

	if(false) {
		trace("Goodbye!");
	}
	```

	...would be converted to this:
	```haxe
	trace("Hello");
	```
**/
class RemoveConstantBoolIfsImpl {
	public static function process(el: Array<TypedExpr>): Array<TypedExpr> {
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
						return removeIfs(eif);
					}
					case TConst(TBool(false)): {
						if(eelse != null) {
							return removeIfs(eelse);
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
