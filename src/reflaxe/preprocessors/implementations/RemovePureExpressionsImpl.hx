// =======================================================
// * RemovePureExpressions
// =======================================================
package reflaxe.preprocessors.implementations;

#if (macro || reflaxe_runtime)
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.Exception;
import haxe.macro.TypedExprTools;

using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TVarHelper;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;
using Lambda;

/**
	Walks the expression tree and removes pure (side-effect-free)
	expressions from blocks that are not used as values.
**/
class RemovePureExpressionsImpl {
	/**
		Entry point. Processes the unwrapped block elements of a function body.
	**/
	public static function process(list:Array<TypedExpr>):Array<TypedExpr> {
		var processed = [for (e in list) processRecursive(e)];
		var result = OptimizerTexpr.blockElement(true, [], processed);
		result.reverse();
		return result;
	}

	/**
		Recursively walks the expression tree. At each `TBlock`,
		removes pure expressions from its element list via `blockElement`.
	**/
	static function processRecursive(expr:TypedExpr):TypedExpr {
		var mapped = haxe.macro.TypedExprTools.map(expr, processRecursive);
		return switch (mapped.expr) {
			case TBlock(el):
				var result = OptimizerTexpr.blockElement(true, [], el);
				result.reverse();
				mapped.copy(TBlock(result));
			case _:
				mapped;
		};
	}
}

/**
	Provides purity detection for fields, classes, and field accesses
	based on `@:pure` metadata annotations.
**/
@:allow(RemovePureExpressionsImpl)
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

/**
	Core optimization logic ported from the Haxe compiler's `optimizerTexpr.ml`
	and `analyzerTexpr.ml`. Provides side-effect detection and block-level
	pure expression removal.
**/
@:allow(RemovePureExpressionsImpl)
private class OptimizerTexpr {
	/**
		Returns `true` if the expression has observable side effects
		(e.g. function calls, assignments, increments, throws).
		Pure field calls and constructors annotated with `@:pure`
		are not considered side-effecting.
	**/
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
					case TArray(_), TEnumParameter(_), TEnumIndex(_), TCast(_, null), TBinop(_, _, _), TUnop(_, _, _), TParenthesis(_), TMeta(_), TWhile(_),
						TField(_, _), TIf(_), TTry(_), TSwitch(_), TArrayDecl(_), TBlock(_), TObjectDecl(_), TVar(_):
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

	/**
		Processes a block's element list, removing pure (side-effect-free)
		expressions that don't contribute to the program state. The result
		is built in reverse order and must be reversed by the caller.
	**/
	public static function blockElement(loopBottom:Bool, acc:Array<TypedExpr>, el:Array<TypedExpr>):Array<TypedExpr> {
		function loop(acc:Array<TypedExpr>, el:Array<TypedExpr>):Array<TypedExpr> {
			if (el.length == 0)
				return acc;

			var head = el[0];
			var tail = el.slice(1);

			switch (head.expr) {
				case TBinop(OpAssign, { expr: TLocal(v1) }, { expr: TLocal(v2) }) if (v1 == v2):
					return loop(acc, tail);
				case TBinop(op, _, _) if (op.match(OpAssignOp(_)) || op == OpAssign):
					return loop([head].concat(acc), tail);
				case TUnop(op, _, _) if (op == OpIncrement || op == OpDecrement):
					return loop([head].concat(acc), tail);
				//case TLocal(_): if (!config.local_dce):
				//	return loop([head].concat(acc), tail);
				case TLocal(v):
					return loop(acc, tail);
				case TField(_, fa) if (!PurityState.isPureFieldAccess(fa)):
					return loop([head].concat(acc), tail);
				case TFunction(_), TConst(_), TTypeExpr(_):
					return loop(acc, tail);
				case TMeta(meta, _) if (PurityState.getPurityFromMeta(meta) == Pure):
					return loop(acc, tail);
				// Pure field call
				//case TCall({ expr: TField(e1, fa) }, el1) if (PurityState.isPureFieldAccess(fa) && config.local_dce):
				//	return loop(acc, [e1].concat(el1).concat(tail));
				// Pure constructor
				//case TNew(c, tl, el1) if (c.get().constructor != null && PurityState.isPure(PurityState.getPurity(c.get(), c.get().constructor.get())) && config.local_dce):
				//	return loop(acc, el1.concat(tail));
				case TIf({ expr: TConst(TBool(t)) }, e1, e2):
					if (t)
						return loop(acc, [e1].concat(tail));
					else
						return switch (e2) {
							case null: loop(acc, tail);
							case e: loop(acc, [e].concat(tail));
						}
				case TSwitch(e, cases, edef):
					var opt = checkConstantSwitch({e: e, cases: cases, edef: edef});
					if (opt != null)
						return loop(acc, [opt].concat(tail));
					else
						return loop([head].concat(acc), tail);
				case TParenthesis(e1), TMeta(_, e1), TCast(e1, null), TField(e1, _), TUnop(_, _, e1), TEnumIndex(e1), TEnumParameter(e1, _, _):
					return loop(acc, [e1].concat(tail));

				case TArray(e1, e2), TBinop(_, e1, e2):
					//if (!hasSideEffects(e1) && !hasSideEffects(e2))
					//	return loop(acc, tail);
					return loop(acc, [e1, e2].concat(tail));

				case TArrayDecl(el1):
					return loop(acc, el1.concat(tail));

				case TCall({ expr: TField(_, FEnum(_)) }, el1):
					return loop(acc, el1.concat(tail));

				case TObjectDecl(fl):
					var values = [for (f in fl) f.expr];
					return loop(acc, values.concat(tail));

				case TIf(e1, e2, null) if (!hasSideEffects(e2)):
					return loop(acc, [e1].concat(tail));

				case TIf(e1, e2, e3) 
					if (e3 != null && !hasSideEffects(e2) && !hasSideEffects(e3)):
					return loop(acc, [e1].concat(tail));

				case TBlock([e1]):
					return loop(acc, [e1].concat(tail));

				case TBlock([]):
					return loop(acc, tail);

				case TBlock(el1):
					var r:Array<TypedExpr> = [];
					r = OptimizerTexpr.blockElement(true, r, el1);
					r.reverse();
					return loop(acc, r.concat(tail));

				case TContinue if (loopBottom):
					return loop([], tail);

				case _:
					return loop([head].concat(acc), tail);
			}
		}

		return loop(acc, el);
	}

	static function extractConstantValue(e:TypedExpr):Null<TypedExpr> {
		switch (e.expr) {
	   		case TConst(ct):
				switch (ct) {
					case TInt(_), TFloat(_), TString(_), TBool(_), TNull:
						return e;
					case TThis, TSuper:
						return null;
				}
			case TField(_, FStatic(c, cf)):
				switch (cf.get().kind) {
					case FVar(read, write) if (write == AccNever):
						if (cf.get().expr != null)
							return extractConstantValue(cf.get().expr());
						else
							return null;
					default:
				}
				return null;
			case TField(_, FEnum(_)):
				return e;
			case TParenthesis(e1):
				return extractConstantValue(e1);
			default:
				return null;
		}
	}


	static function checkConstantSwitch(sw:{e:TypedExpr, cases:Array<TSwitchCase>, edef:Null<TypedExpr>}):Null<TypedExpr> {
		function loop(e1:TypedExpr, cases:Array<TSwitchCase>):Null<TypedExpr> {
			for (case_ in cases) {
				var resolved:Array<TypedExpr> = [];
				for (e2 in case_.values) {
					var c = extractConstantValue(e2);
					if (c == null)
						return null;
					resolved.push(c);
				}

				for (e2 in resolved)
					if (e1.equals(e2))
						return case_.expr;
			}

			return sw.edef;
		}

		function isEmpty(e:TypedExpr):Bool {
			return switch (e.expr) {
				case TBlock([]): true;
				default: false;
			}
		}

		function isEmptyDefault():Bool {
			if (sw.edef == null)
				return true;

			return isEmpty(sw.edef);
		}

		var subject = sw.e;

		switch (subject.expr) {

			case TConst(ct):
				switch (ct) {
					case TSuper, TThis:
						return null;
					default:
						return loop(subject, sw.cases);
				}

			default:
				var allEmpty = true;
				for (case_ in sw.cases)
					if (!isEmpty(case_.expr)) {
						allEmpty = false;
						break;
					}

				if (allEmpty && isEmptyDefault())
					return sw.e;

				return null;
		}
	}
}

/**
	Helper type, this way we don't have to pass the original TSwitch texpr,
	skipping the need to re-capture the parameters.
**/
typedef TSwitchCase = {values:Array<TypedExpr>, expr:TypedExpr}

/**
	Represents the purity level of a class, field, or expression.
**/
enum Purity {
	Pure;
	Impure;
	MaybePure;
	InferredPure;
	ExpectPure(pos:Position);
}

#end
