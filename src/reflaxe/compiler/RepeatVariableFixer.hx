// =======================================================
// * RepeatVariableFixer
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TVarHelper;
using reflaxe.helpers.TypedExprHelper;

/**
	Scans an expression, presumably a block containing
	multiple expressions, and ensures not a single variable
	name is repeated or redeclared.

	Whether variables of the same name are allowed to be
	redeclarated in the same scope or a subscope.
**/
class RepeatVariableFixer {
	/**
		The original expression passed
	**/
	var expr: TypedExpr;

	/**
		The original expression extracted as a TBlock list
	**/
	var originalExpr: TypedExpr;

	/**
		If another instance of RepeatVariableFixer created
		this one, it can be referenced from here.
	**/
	var parent: Null<RepeatVariableFixer>;

	/**
		A list of all the already declared variable names.
	**/
	var varNames: Map<String, Bool>;

	/**
		A map of newly generated TVars, referenced by their id.
	**/
	var varReplacements: Map<Int, TVarOverride>;

	/**
		The compiler being used.
	**/
	var compiler: BaseCompiler;

	public function new(expr: TypedExpr, parent: Null<RepeatVariableFixer> = null, initVarNames: Null<Array<String>> = null, compiler: BaseCompiler) {
		originalExpr = expr;
		
		this.expr = expr;
		this.parent = parent;
		this.compiler = compiler;

		varNames = [];
		if(initVarNames != null) {
			for(name in initVarNames) {
				varNames.set(name, true);
			}
		}

		varReplacements = [];
	}

	public function fixRepeatVariables(): TypedExpr {
		final exprList = switch(originalExpr.expr) {
			case TBlock(exprs): exprs;
			case _: [originalExpr];
		}

		for(expr in exprList) {
			switch(expr.expr) {
				case TVar(tvar, maybeExpr): {
					var name = tvar.name;
					while(varExists(name)) {
						final regex = ~/[\w\d_]+(\d+)/i;
						if(regex.match(name)) {
							final m = regex.matched(1);
							final num = Std.parseInt(m);
							if(num != null) {
								name = name.substring(0, name.length - m.length) + (num + 1);
							}
						} else {
							name += "2";
						}
					}

					varNames.set(name, true);

					if(name != tvar.name) {
						final copyTVar = tvar.copy(name);
						varReplacements.set(copyTVar.id, copyTVar);
						compiler.setTVarOverride(tvar, copyTVar);
						continue;
					} else {
						handleExpression(expr);
					}
				}
				case TBlock(_): {
					handleBlock(expr);
					continue;
				}
				case _: {
					handleExpression(expr);
				}
			}
		}

		return originalExpr;
	}

	function handleExpression(expr: TypedExpr): TypedExpr {
		function mapSubExprs(subExpr: TypedExpr) {
			switch(subExpr.expr) {
				case TBlock(_): {
					return handleBlock(subExpr);
				}
				case _:
			}
			return haxe.macro.TypedExprTools.map(subExpr, mapSubExprs);
		}

		return haxe.macro.TypedExprTools.map(expr, mapSubExprs);
	}

	function handleBlock(subExpr: TypedExpr): TypedExpr {
		final rvf = new RepeatVariableFixer(subExpr, this, null, compiler);
		final result = rvf.fixRepeatVariables();
		return result;
	}

	function varExists(name: String) {
		return if(varNames.exists(name)) {
			true;
		} else if(parent != null) {
			parent.varExists(name);
		} else {
			false;
		}
	}

	function varReplacement(id: Int): Null<TVarOverride> {
		return if(varReplacements.exists(id)) {
			varReplacements.get(id);
		} else if(parent != null) {
			parent.varReplacement(id);
		} else {
			null;
		}
	}
}

#end