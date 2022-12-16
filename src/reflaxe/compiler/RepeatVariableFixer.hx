// =======================================================
// * RepeatVariableFixer
//
// Scans an expression, presumably a block containing
// multiple expressions, and ensures not a single variable
// name is repeated or redeclared.
//
// Whether variables of the same name are allowed to be
// redeclarated in the same scope or a subscope.
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TVarHelper;
using reflaxe.helpers.TypedExprHelper;

class RepeatVariableFixer {
	// The original expression passed
	var expr: TypedExpr;

	// The original expression extracted as a TBlock list
	var exprList: Array<TypedExpr>;

	// If another instance of RepeatVariableFixer created
	// this one, it can be referenced from here.
	var parent: Null<RepeatVariableFixer>;

	// A list of all the already declared variable names.
	var varNames: Map<String, Bool>;

	// A map of newly generated TVars, referenced by their id.
	var varReplacements: Map<Int, TVar>;

	public function new(expr: TypedExpr, parent: Null<RepeatVariableFixer> = null, initVarNames: Null<Array<String>> = null) {
		this.expr = expr;
		this.parent = parent;

		exprList = switch(expr.expr) {
			case TBlock(exprs): exprs.map(e -> e.copy());
			case _: [expr.copy()];
		}

		varNames = [];
		if(initVarNames != null) {
			for(name in initVarNames) {
				varNames.set(name, true);
			}
		}

		varReplacements = [];
	}

	public function fixRepeatVariables(): TypedExpr {
		final result = [];

		for(expr in exprList) {
			switch(expr.expr) {
				case TVar(tvar, maybeExpr): {
					var name = tvar.name;
					while(varExists(name)) {
						final regex = ~/[\w\d_]+(\d+)/i;
						if(regex.match(name)) {
							final m = regex.matched(1);
							final num = Std.parseInt(m);
							name = name.substring(0, name.length - m.length) + (num + 1);
						} else {
							name += "2";
						}
					}

					varNames.set(name, true);

					if(name != tvar.name) {
						final copyTVar = tvar.copy(name);
						varReplacements.set(copyTVar.id, copyTVar);
						final temp = expr.copy(TVar(copyTVar, maybeExpr));
						result.push(temp);
						continue;
					} else {
						result.push(expr);
					}
				}
				case TBlock(_): {
					result.push(handleBlock(expr));
					continue;
				}
				case _: {
					function mapSubExprs(subExpr: TypedExpr) {
						switch(subExpr.expr) {
							case TBlock(_): {
								return handleBlock(subExpr);
							}
							case TLocal(tvar): {
								final replacement = varReplacement(tvar.id);
								if(replacement != null) {
									return subExpr.copy(TLocal(replacement));
								}
							}
							case _:
						}
						return haxe.macro.TypedExprTools.map(subExpr, mapSubExprs);
					}

					expr = haxe.macro.TypedExprTools.map(expr, mapSubExprs);

					result.push(expr);
				}
			}
		}

		return expr.copy(TBlock(result));
	}

	function handleBlock(subExpr: TypedExpr): TypedExpr {
		final rvf = new RepeatVariableFixer(subExpr, this);
		return rvf.fixRepeatVariables();
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

	function varReplacement(id: Int): Null<TVar> {
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