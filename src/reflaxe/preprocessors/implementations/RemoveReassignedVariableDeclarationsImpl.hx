// =======================================================
// * RemoveReassignedVariableDeclarationsImpl
// =======================================================

package reflaxe.preprocessors.implementations;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.ModuleTypeHelper;

/**
	Removes unnecessary variable declarations for variables
	that are unused until a reassignment later in the same scope.
**/
class RemoveReassignedVariableDeclarationsImpl {
	var exprList: Array<TypedExpr>;

	public static function process(list: Array<TypedExpr>): Array<TypedExpr> {
		final ubr = new RemoveReassignedVariableDeclarationsImpl(list);
		return ubr.removeUnnecessaryVarDecls();
	}

	public function new(list: Array<TypedExpr>) {
		exprList = list;
	}

	/**
		Returns a modified version of the input expressions with the optimization applied.
	**/
	public function removeUnnecessaryVarDecls(): Array<TypedExpr> {
		final result = [];

		var removableVars: Array<{tvar: TVar, index: Int}> = [];
		var indexesToRemove = [];
		var i = 0;

		while(i < exprList.length) {
			final expr = exprList[i++];
			switch(expr.expr) {
				case TVar(tvar, e): {
					if(!isModifyingExpr(e)) {
						removableVars.push({ tvar: tvar, index: i - 1 });
					}
				}
				case TBinop(OpAssign, { expr: TLocal(tvar) }, e): {
					// Ensure assignment expression does not reference the variable
					// being assigned or any other variables being tracked.
					removableVars = filterRemovableVars(e, removableVars);

					// Check assignment to see if a previously unused,
					// but declared variable is being assigned.
					var successful = false;
					for(v in removableVars) {
						if(v.tvar.id == tvar.id) {
							// push alternative expression
							final copyExpr = expr.copy();
							copyExpr.expr = TVar(tvar, e);
							result.push(copyExpr);

							// remove original declaration
							indexesToRemove.push(v.index);

							successful = true;
							break;
						}
					}
					if(successful) {
						continue;
					}
				}
				case TBlock(el): {
					final copyExpr = expr.copy();
					copyExpr.expr = TBlock(process(el));
					result.push(copyExpr);
					continue;
				}
				case _: {
					removableVars = filterRemovableVars(expr, removableVars);
				}
			}
			result.push(expr);
		}

		return {
			final filteredResult = [];
			for(i in 0...result.length) {
				if(!indexesToRemove.contains(i)) {
					filteredResult.push(result[i]);
				}
			}
			filteredResult;
		}
	}

	/**
		Check the provided expression for any usage of the supplied list of declared variables.
		If any are found, remove them from the list.
	**/
	function filterRemovableVars(expr: TypedExpr, removableVars: Array<{tvar: TVar, index: Int}>) {
		function exprIter(e: TypedExpr) {
			switch(e.expr) {
				case TLocal(tvar): {
					removableVars = removableVars.filter(function(v) {
						return v.tvar.id != tvar.id;
					});
				}
				case _:
			}
			haxe.macro.TypedExprTools.iter(e, exprIter);
		}
		exprIter(expr);
		return removableVars;
	}

	/**
		Check if the expression has any possible effects.
		If not, it should be safe to remove.
	**/
	function isModifyingExpr(e: Null<TypedExpr>): Bool {
		if(e == null) {
			return false;
		}
		return switch(e.expr) {
			case TCall(_, _): true;
			case TNew(_, _, _): true;
			case TReturn(_): true;
			case TBreak | TContinue: true;
			case _: {
				var modifying = false;
				haxe.macro.TypedExprTools.iter(e, function(subExpr: TypedExpr) {
					if(isModifyingExpr(subExpr)) {
						modifying = true;
					}
				});
				modifying;
			}
		}
	}
}

#end