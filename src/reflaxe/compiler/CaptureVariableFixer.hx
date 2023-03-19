// =======================================================
// * CaptureVariableFixer
//
// Wraps a variable in an array when accessed from a lambda.
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TVarHelper;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

class CaptureVariableFixer {
	// The original expression passed
	var expr: TypedExpr;

	// The original expression extracted as a TBlock list
	var exprList: Array<TypedExpr>;

	// Tracks whether within a lambda in fixCaptureExpr
	var isInLambda: Bool = false;

	// Maps TVars outside a lambda to their ID
	var nonLambdaVars: Map<Int, TVar>;

	// The list of TVar IDs to add @:arrayWrap to
	var arrayWrapVarIds: Array<Int>;

	// Placeholder Position
	#if eval
	var tempPos: Position;
	#end

	// Constructor
	public function new(expr: TypedExpr, parent: Null<RepeatVariableFixer> = null, initVarNames: Null<Array<String>> = null) {
		this.expr = expr;

		exprList = switch(expr.expr) {
			case TBlock(exprs): exprs.map(e -> e.copy());
			case _: [expr.copy()];
		}

		nonLambdaVars = [];
		arrayWrapVarIds = [];

		#if eval
		tempPos = PositionHelper.unknownPos();
		#end
	}

	// Applies the changes to the supplied expression.
	public function fixCaptures(): TypedExpr {
		for(e in exprList) {
			fixCaptureExpr(e);
		}
		for(e in exprList) {
			addMetaToLocals(e);
		}
		return {
			expr: TBlock(exprList),
			pos: expr.pos,
			t: expr.t
		};
	}

	// Finds all variables declared outside a lambda but referenced within one.
	// The IDs of all these variables are stored in "arrayWrapVarIds".
	function fixCaptureExpr(e: TypedExpr) {
		switch(e.expr) {
			case TFunction(tfunc): {
				final original = isInLambda;
				isInLambda = true;
				haxe.macro.TypedExprTools.iter(e, fixCaptureExpr);
				isInLambda = original;
			}
			case TVar(tvar, _): {
				if(!isInLambda && !nonLambdaVars.exists(tvar.id)) {
					nonLambdaVars.set(tvar.id, tvar);
				}
			}
			case TLocal(tvar): {
				if(isInLambda && nonLambdaVars.exists(tvar.id)) {
					nonLambdaVars.remove(tvar.id);
					arrayWrapVarIds.push(tvar.id);
				}
			}
			case _:
		}
		haxe.macro.TypedExprTools.iter(e, fixCaptureExpr);
	}

	// Add @:arrayWrap meta to all instances of "arrayWrapVarIds" TVars.
	function addMetaToLocals(e: TypedExpr) {
		final typeAndTVar = switch(e.expr) {
			case TLocal(tvar): { type: e.t, tvar: tvar };
			case TVar(tvar, _): { type: tvar.t, tvar: tvar };
			case _: null;
		}
		if(typeAndTVar != null) {
			final t = typeAndTVar.type;
			final tvar = typeAndTVar.tvar;
			if(t != null && t.isPrimitive() && arrayWrapVarIds.contains(tvar.id)) {
				#if eval
				tvar.meta.maybeAdd(":arrayWrap", [], tempPos);
				#end
			}
		}
		
		haxe.macro.TypedExprTools.iter(e, addMetaToLocals);
	}
}

#end
