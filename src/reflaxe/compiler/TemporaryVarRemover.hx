package reflaxe.compiler;

import haxe.macro.Type;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypedExprHelper;

class TemporaryVarRemover {
	/**
		The original expression passed.
	**/
	var expr: TypedExpr;

	/**
		The original expression extracted as a TBlock list.
	**/
	var exprList: Array<TypedExpr>;

	/**
		The `TemporaryVarRemover` that created this instance.
	**/
	var parent: Null<TemporaryVarRemover>;

	/**
		A map of all the variables that are being removed.
	**/
	var tvarMap: Map<Int, TypedExpr> = [];

	/**
		A reference to a map that tracks the variable usage count.
		May not be available.
	**/
	var varUsageCount: Null<Map<Int, Int>>;

	public function new(expr: TypedExpr, varUsageCount: Null<Map<Int, Int>> = null, parent: Null<TemporaryVarRemover> = null) {
		this.expr = expr;
		this.varUsageCount = varUsageCount;
		this.parent = parent;

		exprList = switch(expr.expr) {
			case TBlock(exprs): exprs.map(e -> e.copy());
			case _: [expr.copy()];
		}
	}

	/**
		Generate copy of `expr` with temporaries removed.
	**/
	public function fixTemporaries(): TypedExpr {
		function mapTypedExpr(mappedExpr, noReplacements): TypedExpr {
			switch(mappedExpr.expr) {
				case TLocal(v) if(!noReplacements): {
					final e = findReplacement(v.id);
					if(e != null) return e;
				}
				case TBlock(_): {
					final tvr = new TemporaryVarRemover(mappedExpr, varUsageCount, this);
					return tvr.fixTemporaries();
				}
				case _:
			}
			return haxe.macro.TypedExprTools.map(mappedExpr, e -> mapTypedExpr(e, noReplacements));
		}

		final result = [];

		var hasOverload = false;

		for(i in 0...exprList.length) {
			if(i < exprList.length - 1) {
				switch(exprList[i].expr) {
					case TVar(tvar, maybeExpr) if(isField(maybeExpr) && getVariableUsageCount(tvar.id) < 2): {
						switch(tvar.t) {
							case TInst(clsRef, _) if(clsRef.get().hasMeta(":avoid_temporaries")): {
								tvarMap.set(tvar.id, mapTypedExpr(maybeExpr.trustMe(), false));
								hasOverload = true;
								continue;
							}
							case _:
						}
					}
					case _:
				}
			}

			result.push(mapTypedExpr(exprList[i], parent == null && !hasOverload));
		}

		return expr.copy(TBlock(result));
	}

	/**
		Returns `true` if the expression is an identifier or field access.
	**/
	static function isField(expr: Null<TypedExpr>): Bool {
		if(expr == null) return false;

		return switch(expr.expr) {
			case TParenthesis(e): isField(e);
			case TField(_, _): true;
			case _: false;
		}
	}

	/**
		If the variable ID exists in the map for this instance of any of
		the parents, its expression will be returned. `null` otherwise.
	**/
	function findReplacement(variableId: Int): Null<TypedExpr> {
		if(tvarMap.exists(variableId)) {
			return tvarMap.get(variableId).trustMe();
		} else if(parent != null) {
			final e = parent.findReplacement(variableId);
			if(e != null) return e;
		}
		return null;
	}

	/**
		Returns the number of usages for the variable if possible.
	**/
	function getVariableUsageCount(variableId: Int): Int {
		return if(varUsageCount != null && varUsageCount.exists(variableId)) {
			varUsageCount.get(variableId) ?? 0;
		} else {
			0;
		}
	}
}
