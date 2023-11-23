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

	public function new(expr: TypedExpr, parent: Null<TemporaryVarRemover> = null) {
		this.expr = expr;
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
		final result = [];

		for(i in 0...exprList.length) {
			if(i < exprList.length - 1) {
				switch(exprList[i].expr) {
					case TVar(tvar, maybeExpr) if(isField(maybeExpr)): {
						switch(tvar.t) {
							case TInst(clsRef, _) if(clsRef.get().hasMeta(":avoid_temporaries")): {
								tvarMap.set(tvar.id, maybeExpr.trustMe());
								continue;
							}
							case _:
						}
					}
					case _:
				}
			}

			result.push(exprList[i]);
		}

		function mapTypedExpr(mappedExpr): TypedExpr {
			switch(mappedExpr.expr) {
				case TLocal(v): {
					final e = findReplacement(v.id);
					if(e != null) return e;
				}
				case TBlock(exprs): {
					final tvr = new TemporaryVarRemover(mappedExpr, this);
					return tvr.fixTemporaries();
				}
				case _:
			}
			return haxe.macro.TypedExprTools.map(mappedExpr, mapTypedExpr);
		}

		return expr.copy(TBlock(result.map(mapTypedExpr)));
	}

	/**
		Returns `true` if the expression is an identifier or field access.
	**/
	static function isField(expr: Null<TypedExpr>): Bool {
		if(expr == null) return false;

		return switch(expr.expr) {
			case TParenthesis(e): isField(e);
			case TField(e, _): true;
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
}
