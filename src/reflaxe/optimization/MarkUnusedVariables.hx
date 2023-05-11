package reflaxe.optimization;

// =======================================================
// * UnnecessaryVarDeclRemover
//
// Removes unnecessary variable declarations for variables
// that are unused until a reassignment later in the same scope.
// =======================================================

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.TypedExprHelper;

class MarkUnusedVariables {
	var exprList: Array<TypedExpr>;

	public static function mark(list: Array<TypedExpr>): Array<TypedExpr> {
		final muv = new MarkUnusedVariables(list);
		return muv.markUnusedLocalVariables();
	}

	public function new(list: Array<TypedExpr>) {
		exprList = list;
	}

	var tvarMap: Map<Int, Null<TVar>> = [];
	var tvarPos: Map<Int, Position> = [];

	// Returns a modified version of the input expressions with the optimization applied.
	public function markUnusedLocalVariables(): Array<TypedExpr> {
		for(e in exprList) {
			iter(e);
		}

		for(id => tvar in tvarMap) {
			if(tvar != null) {
				tvar.meta.maybeAdd("-reflaxe.unused", [], tvarPos.get(id).trustMe());
			}
		}

		return exprList;
	}

	function iter(te: TypedExpr) {
		switch(te.expr) {
			case TVar(tvar, _): {
				if(tvarMap.exists(tvar.id)) {
					throw "Logic error";
				}
				tvarMap.set(tvar.id, tvar);
				tvarPos.set(tvar.id, te.pos);
			}
			case TLocal(tvar): {
				if(tvarMap.exists(tvar.id)) {
					tvarMap.set(tvar.id, null);
				}
			}
			case _:
		}

		return haxe.macro.TypedExprTools.map(te, iter);
	}
}

#end
