// =======================================================
// * ExpressionModifier
// =======================================================

package reflaxe.input;

#if (macro || reflaxe_runtime)

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

/**
	Sometimes a specific expression or expression pattern
	needs to be modified pre-typing to function with
	the compiler target.

	This class can be used in an initialization macro
	to set up `@:build` macros to modify the desired expression.
**/
class ExpressionModifier {
	static var modifications: Array<(Expr) -> Null<Expr>> = [];

	public static function mod(exprFunc: (Expr) -> Null<Expr>): Void {
		if(modifications.length == 0) {
			#if macro
			Compiler.addGlobalMetadata("", "@:build(reflaxe.input.ExpressionModifier.applyMods())");
			#end
		}

		modifications.push(exprFunc);
	}

	public static function applyMods(): Null<Array<Field>> {
		#if eval
		final fields = Context.getBuildFields();

		for(i in 0...fields.length) {
			final f = fields[i];
			switch(f.kind) {
				case FFun(fun): {
					if(fun.expr != null) {
						fun.expr = applyModsToExpr(fun.expr);
					}
				}
				case _:
			}
		}

		return fields;
		#else
		return [];
		#end
	}

	static function applyModsToExpr(e: Expr): Expr {
		var wasModded = false;
		var currentExpr = e;
		for(mod in modifications) {
			final result = mod(e);
			if(result != null) {
				currentExpr = result;
				wasModded = true;
			}
		}
		if(wasModded) {
			return currentExpr;
		}
		return haxe.macro.ExprTools.map(currentExpr, applyModsToExpr);
	}
}

#end
