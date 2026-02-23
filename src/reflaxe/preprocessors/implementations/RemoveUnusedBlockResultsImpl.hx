// =======================================================
// * RemoveUnusedBlockResults
// =======================================================
package reflaxe.preprocessors.implementations;

import haxe.Exception;
import haxe.macro.TypedExprTools;
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
	public static function process(list:Array<TypedExpr>):Array<TypedExpr> {
		// public static function process(expr: TypedExpr): TypedExpr {
		final result = [];

		for (i in 0...list.length) {
			var e = list[i];
			var sideEff = OptimizerTexpr.hasSideEffects(e);
			if (sideEff)
				result.push(e);
			else if (i == list.length - 1)
				result.push(e);
			else 
				result.push(TBinop(OpAssign, TIdent("--[=[").make(e.t, e.pos), 
			TBinop(OpAssign, e, TIdent("]=]--").make(e.t, e.pos)).make(e.t, e.pos)
			).make(e.t, e.pos));
		}

		return result;
	}
}

@:allow(RemoveUnusedBlockResultsImpl)
private class PurityState {
	public static function getPurityFromMeta(mt:MetadataEntry):Purity {
		if (mt == null || mt.params == null || mt.params.length == 0)
			return MaybePure;
		return switch (mt.params[0].expr) {
			case EConst(CIdent(ident)): switch (ident) {
					case "true" | "inferredPure": Pure;
					case "false": Impure;
					case "expect": ExpectPure(mt.pos);
					default: MaybePure;
				}
			case _: MaybePure;
		}
	}

	public static function isPure(purity:Purity):Bool {
		return switch (purity) {
			case Pure | InferredPure: true;
			case ExpectPure(_): true;
			case Impure | MaybePure: false;
		}
	}

	public static function getPurity(c:ClassType, cf:ClassField):Purity {
		final cPurity = getPurityFromMeta(c.meta.extract(":pure")[0]);
		if (isPure(cPurity))
			return cPurity;

		final cfPurity = getPurityFromMeta(cf.meta.extract(":pure")[0]);
		return cfPurity;
	}

	public static function isPureFieldAccess(fa:FieldAccess):Bool
		return switch (fa) {
			case FInstance(c, _, cf) | FStatic(c, cf):
				isPure(getPurity(c.get(), cf.get()));
			case FAnon(cf) | FClosure(null, cf):
				isPure(getPurityFromMeta(cf.get().meta.extract(":pure")[0]));
			case FClosure(c, cf):
				isPure(getPurity(c.c.get(), cf.get()));
			case FEnum(_, _): true;
			case FDynamic(_): false;
		}
}

@:allow(OptimizerTexpr)
private class ExitLoopException {public function new() {}}

@:allow(RemoveUnusedBlockResultsImpl)
private class OptimizerTexpr {
	public static function hasSideEffects(expr:TypedExpr):Bool {
		final exitObj = new ExitLoopException();
		try {
			function loop(e:TypedExpr) {
				switch (e.expr) {
					case TConst(_), TLocal(_), TTypeExpr(_), TFunction(_), TIdent(_):
						return;
					case TCall({expr: TField(e1, fa)}, el) if (PurityState.isPureFieldAccess(fa)):
						loop(e1);
						for (arg in el)
							loop(arg);
						return;
					case TNew(c, _, el) if (c.get().constructor.get() != null
						&& PurityState.isPure(PurityState.getPurity(c.get(), c.get().constructor.get()))):
						for (arg in el)
							loop(arg);
						return;
					case TField(_, fa) if (!PurityState.isPureFieldAccess(fa)):
						throw exitObj;
					case TNew(_) | TCall(_):
						throw exitObj;
					case TBinop(op, _, _) if (op.match(OpAssignOp(_)) || op == OpAssign):
						throw exitObj;
					case TUnop(op, _, _) if (op == OpIncrement || op == OpDecrement):
						throw exitObj;
					case TReturn(_), TBreak, TContinue, TThrow(_):
						throw exitObj;
					case TCast(_, m) if (m != null):
						throw exitObj;
					case TVar(_):
						throw exitObj;
					case TArray(_), TEnumParameter(_), TEnumIndex(_), TCast(_, null), TBinop(_, _, _), TUnop(_, _, _), TParenthesis(_), TMeta(_), TWhile(_),
						TField(_, _), TIf(_), TTry(_), TSwitch(_), TArrayDecl(_), TBlock(_), TObjectDecl(_):
						TypedExprTools.iter(e, loop);
						return;
					default:
						return;
				}
			}
			loop(expr);
			return false;
		} catch (e:ExitLoopException) {
			if (e == exitObj)
				return true;
			throw e;
		} catch (e:Exception) {
			throw e;
		}
	}
}

enum Purity {
	Pure;
	Impure;
	MaybePure;
	InferredPure;
	ExpectPure(pos:Position);
}

#end
