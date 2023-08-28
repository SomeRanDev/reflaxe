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
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.ModuleTypeHelper;

class UnnecessaryBlockRemover {
	var exprList: Array<TypedExpr>;

	var requiredNames: Array<String>;
	var declaredVars: Array<String>; 
	var multiUseVarNames: Null<Array<String>>;

	public static function optimize(list: Array<TypedExpr>): Array<TypedExpr> {
		final ubr = new UnnecessaryBlockRemover(list);
		return ubr.removeUnnecessaryBlocks();
	}

	public function new(list: Array<TypedExpr>, parentMultiUseVarNames: Null<Array<String>> = null) {
		exprList = list;
		requiredNames = [];
		declaredVars = [];
		multiUseVarNames = parentMultiUseVarNames;
	}

	public function removeUnnecessaryBlocks(): Array<TypedExpr> {
		if(multiUseVarNames == null) {
			multiUseVarNames = findMultiUseVarNames();
		}

		for(e in exprList) {
			trackExpr(e);
		}

		return handleBlockList(exprList);
	}

	// Track all variable declarations and uses for future use
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

	// Add variable name that is used in this block.
	function addRequiredName(n: String) {
		if(!requiredNames.contains(n)) {
			requiredNames.push(n);
		}
	}

	// Add variable name that is declared in this block.
	function addDeclaredVars(n: String) {
		if(!declaredVars.contains(n)) {
			declaredVars.push(n);
		}
	}

	// Take a list of expressions and merge any possible blocks.
	function handleBlockList(exprList: Array<TypedExpr>): Array<TypedExpr> {
		final result = [];
		for(i in 0...exprList.length) {
			final expr = exprList[i];
			switch(expr.expr) {
				case TBlock([]): {}
				case TBlock(el): {
					// Merge the possible sub-expression blocks for this sub-block.
					final ubr = new UnnecessaryBlockRemover(el, multiUseVarNames);
					final newExprList = ubr.removeUnnecessaryBlocks();

					// Check if merge should occur
					var shouldMerge = true;
					for(name in ubr.declaredVars) {
						// If a variable is used in multiple blocks, or this this
						// variable name is required elsewhere, we do not merge.
						if(multiUseVarNames.trustMe().contains(name) || requiredNames.contains(name)) {
							shouldMerge = false;
							break;
						}
					}

					if(shouldMerge) {
						// "Merge" the expressions of this block into
						// the main-block's new list of expressions.
						for(expr in newExprList) {
							result.push(expr.copy());
						}
					} else {
						result.push(expr);
					}
				}
				case _: {
					result.push(findNewBlock(expr));
				}
			}
		}

		return result;
	}

	// If the expression isn't a block, iterate
	// through the sub-expressions to find one.
	function findNewBlock(e: TypedExpr): TypedExpr {
		return switch(e.expr) {
			// Find a new block to act as our "base".
			// Only blocks inside a block need to be merged.
			case TBlock(el): {
				return {
					expr: TBlock(handleBlockList(el)),
					pos: e.pos,
					t: e.t
				};
			}
			case _: haxe.macro.TypedExprTools.map(e, findNewBlock);
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
				case TVar(tvar, _): {
					if(!varInstanceCount.exists(tvar.name)) varInstanceCount.set(tvar.name, []);
					final count = varInstanceCount.get(tvar.name);
					if(count != null) {
						count.push(tvar.id);
					}
				}
				case _:
			}
			haxe.macro.TypedExprTools.iter(e, exprIter);
		}
		for(e in exprList) {
			exprIter(e);
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
