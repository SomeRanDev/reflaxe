package reflaxe.preprocessors.implementations;

// =======================================================
// * UnnecessaryVarDeclRemover
// =======================================================

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.TypedExprHelper;

/**
	Removes unnecessary variable declarations for variables
	that are unused until a reassignment later in the same scope.
**/
class MarkUnusedVariablesImpl {
	var exprList: Array<TypedExpr>;

	public static function mark(list: Array<TypedExpr>): Array<TypedExpr> {
		final muv = new MarkUnusedVariablesImpl(list);
		var result = muv.markUnusedLocalVariables();
		while(muv.foundUnused) {
			result = muv.markUnusedLocalVariables();
		}
		return result;
	}

	public function new(list: Array<TypedExpr>) {
		exprList = list;
	}

	var foundUnused: Bool = false;
	var tvarMap: Map<Int, Null<TVar>> = [];
	var tvarPos: Map<Int, Position> = [];

	/**
		Returns a modified version of the input expressions with the optimization applied.
	**/
	public function markUnusedLocalVariables(): Array<TypedExpr> {
		foundUnused = false;
		tvarMap = [];
		tvarPos = [];

		for(e in exprList) {
			iter(e);
		}

		for(id => tvar in tvarMap) {
			if(tvar != null) {
				if(!tvar.meta.maybeHas("-reflaxe.unused")) {
					tvar.meta.maybeAdd("-reflaxe.unused", [], tvarPos.get(id).trustMe());
					foundUnused = true;
				}
			}
		}

		return exprList;
	}

	function iter(te: TypedExpr) {
		switch(te.expr) {
			case TVar(tvar, maybeExpr): {
				if(tvarMap.exists(tvar.id)) {
					throw "Logic error";
				}
				if(tvar.meta.maybeHas("-reflaxe.unused")) {
					if(maybeExpr != null && !maybeExpr.isMutator()) {
						return;
					}
				} else {
					tvarMap.set(tvar.id, tvar);
					tvarPos.set(tvar.id, te.pos);
				}
			}
			case TLocal(tvar): {
				if(tvarMap.exists(tvar.id)) {
					tvarMap.set(tvar.id, null);
				}
			}
			case _:
		}

		haxe.macro.TypedExprTools.iter(te, iter);
	}
}

#end
