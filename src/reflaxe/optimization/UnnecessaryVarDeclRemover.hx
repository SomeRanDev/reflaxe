// =======================================================
// * UnnecessaryVarDeclRemover
//
// Removes unnecessary variable declarations for variables
// that are unused until a reassignment later in the same scope.
// =======================================================

package reflaxe.optimization;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.ModuleTypeHelper;

class UnnecessaryVarDeclRemover {
	var exprList: Array<TypedExpr>;

	public static function optimize(list: Array<TypedExpr>): Array<TypedExpr> {
		final ubr = new UnnecessaryVarDeclRemover(list);
		return ubr.removeUnnecessaryVarDecls();
	}

	public function new(list: Array<TypedExpr>) {
		exprList = list;
	}

	public function removeUnnecessaryVarDecls(): Array<TypedExpr> {
		final result = [];

		var removableVars: Array<{tvar: TVar, index: Int}> = [];
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
					var successful = false;
					for(v in removableVars) {
						if(v.tvar.id == tvar.id) {
							// push alternative expression
							final copyExpr = expr.copy();
							copyExpr.expr = TVar(tvar, e);
							result.push(copyExpr);

							// remove original declaration
							result.splice(v.index , 1);
							for(_v in removableVars) {
								if(_v.index > v.index) {
									_v.index--;
								}
							}

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
					copyExpr.expr = TBlock(optimize(el));
					result.push(copyExpr);
				}
				case _: {
					haxe.macro.TypedExprTools.iter(expr, function(e: TypedExpr) {
						switch(e.expr) {
							case TLocal(tvar): {
								final len = result.length;
								removableVars = removableVars.filter(function(v) {
									return v.tvar.id == tvar.id;
								});
							}
							case _:
						}
					});
				}
			}
			result.push(expr);
		}

		return result;
	}

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