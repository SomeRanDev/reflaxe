// =======================================================
// * UnnecessaryBlockRemover
//
// Removes unnecessary blocks that do not introduce
// conflicting variable declarations.
// =======================================================

package reflaxe.optimization;

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
		final multiUseVarNames = findMultiUseVarNames();

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
						if(multiUseVarNames.contains(name) || requiredNames.contains(name)) {
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

	// We need to be careful when merging blocks since this optimization runs after
	// the "RepeatVariableFixer". It's possible a block may be merged containing
	// a variable declaration with the same name as another declaration in a
	// subsequent block.
	//
	// To prevent this, this code searches for variable declarations that share
	// the same name and returns a list of names that are declared multiple times.
	function findMultiUseVarNames(): Array<String> {
		final varInstanceCount: Map<String, Array<Int>> = [];

		function exprIter(e: TypedExpr) {
			switch(e.expr) {
				case TVar(tvar, maybeExpr): {
					if(!varInstanceCount.exists(tvar.name)) varInstanceCount.set(tvar.name, []);
					varInstanceCount.get(tvar.name).push(tvar.id);
				}
				case _:
			}
			haxe.macro.TypedExprTools.iter(e, exprIter);
		}
		for(e in exprList) {
			haxe.macro.TypedExprTools.iter(e, exprIter);
		}
		
		final result = [];
		for(name => useCount in varInstanceCount) {
			if(useCount.length > 1) {
				result.push(name);
			}
		}

		return result;
	}
}

#end
