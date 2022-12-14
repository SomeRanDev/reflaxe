// =======================================================
// * UnnecessaryBlockRemover
//
// 
// =======================================================

package reflaxe.conversion;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.ModuleTypeHelper;

class UnnecessaryBlockRemover {
	var exprList: Array<TypedExpr>;

	var requiredNames: Array<String>;
	var declaredVars: Array<String>;

	public static function optimize(list: Array<TypedExpr>): Array<TypedExpr> {
		final ubr = new UnnecessaryBlockRemover(list);
		return ubr.removeUnnecessaryBlocks();
	}

	public function new(list: Array<TypedExpr>) {
		exprList = list;
		requiredNames = [];
		declaredVars = [];
	}

	public function removeUnnecessaryBlocks(): Array<TypedExpr> {
		for(e in exprList) {
			trackExpr(e);
		}

		final result = [];
		for(i in 0...exprList.length) {
			final e = exprList[i];
			switch(e.expr) {
				case TBlock(el): {
					final ubr = new UnnecessaryBlockRemover(el);
					final newExprList = ubr.removeUnnecessaryBlocks();
					var shouldMerge = true;
					for(name in ubr.declaredVars) {
						if(requiredNames.contains(name)) {
							shouldMerge = false;
							break;
						}
					}

					if(shouldMerge) {
						for(expr in newExprList) {
							result.push(expr.copy());
						}
					} else {
						result.push(e);
					}
				}
				case _: {
					result.push(e);
				}
			}
		}

		return result;
	}

	function trackExpr(e: TypedExpr) {
		switch(e.expr) {
			case TBlock(_): return;
			case TLocal(v): addRequiredName(v.getNameOrNative());
			case TTypeExpr(m): addRequiredName(m.getNameOrNative());
			case TVar(v, _): {
				final n = v.getNameOrNative();
				//addRequiredName(n);
				addDeclaredVars(n);
			}
			case TEnumParameter(_, ef, _): addRequiredName(ef.getNameOrNative());
			case TIdent(s): addRequiredName(s);
			case _:
		}
		haxe.macro.TypedExprTools.iter(e, trackExpr);
	}

	function addRequiredName(n: String) {
		if(!requiredNames.contains(n)) {
			requiredNames.push(n);
		}
	}

	function addDeclaredVars(n: String) {
		if(!declaredVars.contains(n)) {
			declaredVars.push(n);
		}
	}
}

#end
