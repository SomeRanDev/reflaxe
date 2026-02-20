// =======================================================
// * RemoveUnusedBlockResults
// =======================================================

package reflaxe.preprocessors.implementations;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TVarHelper;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;
using Lambda;

/**
	Removes or converts the final expression value of blocks whose value is not used by the surrounding code.
**/
class RemoveUnusedBlockResultsImpl {

	public static function process(root:TypedExpr):TypedExpr {
		return transform(root, true);
	}

	static function ensureBlock(e:TypedExpr):TypedExpr {
		return switch(e.expr) {
			case TBlock(_): e;
			default: TBlock([e]).make(e.t, e.pos);
		}
	}

	static function transform(e:TypedExpr, isResultUsed:Bool):TypedExpr {
		return switch(e.expr) {
			case TBlock(el):
				if (el.length == 0)
					e;
				else {
					var transformedExprs = [];
					for(i in 0...el.length) {
						var isLast = i == el.length - 1;
						var childUsed = isLast ? isResultUsed : false;
						transformedExprs.push(transform(el[i], childUsed));
					}
					
					var filteredExprs = [];
					for (i in 0...transformedExprs.length) {
						var expr = transformedExprs[i];
						var isLast = i == transformedExprs.length - 1;
						
						if (isStatement(expr) || !isPure(expr) || (isLast && isResultUsed))
							filteredExprs.push(expr);
					}
					
					TBlock(filteredExprs).make(e.t, e.pos);
				}
			
			case TIf(econd, eif, eelse):
				TIf(
					transform(econd, true),
					transform(ensureBlock(eif), isResultUsed),
					eelse != null ? transform(ensureBlock(eelse), isResultUsed) : null
				).make(e.t, e.pos);
			
			case TSwitch(e1, cases, edef):
				var cases2 = [];
				for (c in cases)
					cases2.push({values: c.values, expr: transform(ensureBlock(c.expr), isResultUsed)});

				TSwitch(
					transform(e1, true),
					cases2,
					edef != null ? transform(ensureBlock(edef), isResultUsed) : null
				).make(e.t, e.pos);
			
			case TTry(e1, catches):
				var newCatches = [];
				for (c in catches)
					newCatches.push({v: c.v, expr: transform(ensureBlock(c.expr), isResultUsed)});
					
				TTry(
					transform(ensureBlock(e1), isResultUsed),
					newCatches
				).make(e.t, e.pos);
			
			case TWhile(econd, ebody, normalWhile):
				TWhile(
					transform(econd, true),
					transform(ebody, false),
					normalWhile
				).make(e.t, e.pos);
			
			case TFor(v, e1, e2):
				TFor(
					v,
					transform(e1, true),
					transform(e2, false)
				).make(e.t, e.pos);

			case TVar(v, expr):
				TVar(v, expr != null ? transform(expr, false) : null).make(e.t, e.pos);
			
			case TReturn(expr):
				TReturn(expr != null ? transform(expr, true) : null).make(e.t, e.pos);
			
			case TThrow(expr):
				TThrow(transform(expr, true)).make(e.t, e.pos);
			
			case _:
				haxe.macro.TypedExprTools.map(e, child -> transform(child, true));
		}
	}

	static function isStatement(e:TypedExpr):Bool {
		return switch(e.expr) {
			case TVar(_, _) | TWhile(_, _, _) | TFor(_, _, _) | TBreak | TContinue | TReturn(_) | TThrow(_): true;
			case _: false;
		}
	}

	static function isPure(e:TypedExpr):Bool {
		return switch(e.expr) {
			case TConst(_) | TLocal(_) | TBreak | TContinue | TTypeExpr(_) | TIdent(_): true;
			case TBinop(op, e1, e2):
				switch(op) {
					case OpAssign | OpAssignOp(_): false;
					default: isPure(e1) && isPure(e2);
				}
			case TUnop(op, pre, e1):
				switch(op) {
					case OpIncrement | OpDecrement: false;
					default: isPure(e1);
				}
			case TArray(e1, e2): isPure(e1) && isPure(e2);
			case TArrayDecl(el): el.foreach(isPure);
			case TObjectDecl(fields): fields.foreach(f -> isPure(f.expr));
			case TEnumParameter(e1, ef, i): isPure(e1);
			case TEnumIndex(e1): isPure(e1);
			case TField(e1, fa): isPure(e1);
			case TParenthesis(e1): isPure(e1);
			case TIf(e1, e2, e3): isPure(e1) && isPure(e2) && (e3 == null || isPure(e3));
			case TSwitch(e1, cases, e2): isPure(e1) && cases.foreach(c -> isPure(c.expr)) && (e2 == null || isPure(e2));
			case TTry(e1, catches): isPure(e1) && catches.foreach(c -> isPure(c.expr));
			case TCast(e1, mt): isPure(e1);
			case TMeta(m, e1): isPure(e1);
			case TBlock(el): el.foreach(e -> isPure(e));
			default: false;
		}
	}
}

#end
