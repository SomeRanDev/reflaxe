package reflaxe.compiler;

import haxe.macro.Type;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.TypedExprHelper;

class TemporaryVarRemover {
	/**
		The original expression passed
	**/
	var expr: TypedExpr;

	/**
		The original expression extracted as a TBlock list
	**/
	var exprList: Array<TypedExpr>;

	public function new(expr: TypedExpr) {
		this.expr = expr;

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
		final tvarMap: Map<Int, TypedExpr> = [];

		for(i in 0...exprList.length) {
			if(i < exprList.length - 1) {
				switch(exprList[i].expr) {
					case TVar(tvar, maybeExpr) if(isField(maybeExpr)): {
						switch(tvar.t) {
							case TInst(clsRef, _) if(clsRef.get().hasMeta(":avoid_temporaries")): {
								tvarMap.set(tvar.id, maybeExpr);
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

		function mapTypedExpr(mappedExpr) {
			switch(mappedExpr.expr) {
				case TLocal(v) if(tvarMap.exists(v.id)): {
					return tvarMap.get(v.id);
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
}
