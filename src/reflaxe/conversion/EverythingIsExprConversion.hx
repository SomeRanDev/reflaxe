// =======================================================
// * EverythingIsExprConversion
//
// Converts block-like expressions that return a value into
// an equivalent expression that does not rely on Haxe's
// "Everything is an Expression" feature.
//
// View this page for more info on Haxe's "Everything is an Expression".
// https://code.haxe.org/category/principles/everything-is-an-expression.html
// =======================================================

package reflaxe.conversion;

#if (macro || reflaxe_runtime)

using reflaxe.helpers.TypedExprHelper;

import haxe.macro.Type;

class EverythingIsExprConversion {
	// Stores the original, provided expression
	public var haxeExpr: TypedExpr;

	// Stores the sub-expression list if the original is a TBlock
	// Otherwise, is an array of length one containing "haxeExpr"
	public var topScopeArray: Array<TypedExpr>;
	var index: Int = 0;

	// If this expression is not null, the final expression of
	// "topScopeArray" needs to be modified into an assignment
	// expression assigning the final expression to "assigneeExpr"
	//
	// Used to convert `var a = { 123; }` into `var a; { a = 123 }`
	// the latter being the standard syntax most languages use.
	public var assigneeExpr: Null<TypedExpr>;

	// If this "EverythingIsExprConversion" was created from another
	// "EverythingIsExprConversion", this is a reference to that
	// original object.
	//
	// This is so we have one consistent object to manage the 
	// new temporary variables names that are being created.
	public var parent: Null<EverythingIsExprConversion> = null;

	// TODO, write overly eloborate comment here
	public var nameGenerator: TempVariableNameGenerator;

	static var variableId = 0;

	public function new(expr: TypedExpr, assignee: Null<TypedExpr> = null) {
		haxeExpr = expr.copy();

		topScopeArray = switch(expr.expr) {
			case TBlock(exprs): exprs.map(e -> e.copy());
			case _: [haxeExpr];
		}

		if(assignee != null) {
			assigneeExpr = assignee.copy();
		} else {
			assigneeExpr = null;
		}

		nameGenerator = new TempVariableNameGenerator();
	}

	public function convertedExpr(): TypedExpr {
		index = 0;
		while(index < topScopeArray.length) {
			var expr = topScopeArray[index];

			// Depending on the expression, we can determine
			// which expressions are treated like "values" in
			// the Haxe code.
			//
			// An infinite while loop is used to locally replicate
			// a recursive-like system when necessary.
			processExpr(expr);

			// If this is the last expression in the block, and this block is
			// expected to result in a value, we modify this final expression
			// to assign to the provided "assignee" expression.
			//
			// The only exception is if this final expression is "block-like".
			// In which case, the "assignee" is handed down to this next
			// block scope expression.
			if(assigneeExpr != null && isLastExpression()) {
				final old = topScopeArray[index];
				if(!isBlocklikeExpr(old)) {
					topScopeArray[index] = {
						expr: TBinop(OpAssign, assigneeExpr, old),
						pos: assigneeExpr.pos,
						t: assigneeExpr.t
					}
				}
			}

			index++;
		}

		return { expr: TBlock(topScopeArray), pos: haxeExpr.pos, t: haxeExpr.t };
	}

	function isLastExpression() {
		return index == (topScopeArray.length - 1);
	}

	function processExpr(expr: TypedExpr) {
		switch(expr.expr) {
			case TArray(e1, e2): {
				handleValueExpr(e1, "array");
				handleValueExpr(e2, "index");
			}
			case TBinop(_, e1, e2): {
				handleValueExpr(e1, "left");
				handleValueExpr(e2, "right");
			}
			case TField(e, _): {
				handleValueExpr(e);
			}
			case TParenthesis(e): {
				processExpr(e);
			}
			case TObjectDecl(fields): {
				for(field in fields) {
					handleValueExpr(field.expr);
				}
			}
			case TArrayDecl(el): {
				for(e in el) {
					handleValueExpr(e);
				}
			}
			case TCall(expr, el): {
				handleValueExpr(expr);
				for(e in el) {
					handleValueExpr(e);
				}
			}
			case TNew(_, _, el): {
				for(e in el) {
					handleValueExpr(e);
				}
			}
			case TUnop(_, _, expr): {
				handleValueExpr(expr);
			}
			case TFunction(tfunc): {
				handleNonValueBlock(tfunc.expr);
			}
			case TVar(tvar, expr): {
				handleValueExpr(expr);
			}
			case TBlock(exprs): {
				handleNonValueBlock(expr);
			}
			case TFor(_, e1, e2): {
				handleValueExpr(e1);
				handleNonValueBlock(e2);
			}
			case TIf(econd, ifExpr, elseExpr): {
				handleValueExpr(econd, "cond");
				handleNonValueBlock(ifExpr);
				if(elseExpr != null) {
					handleNonValueBlock(elseExpr);
				}
			}
			case TWhile(econd, expr, _): {
				handleValueExpr(econd, "cond");
				handleNonValueBlock(expr);
			}
			case TSwitch(expr, cases, edef): {
				handleValueExpr(expr);
				for(c in cases) {
					handleNonValueBlock(c.expr);
				}
				handleNonValueBlock(edef);
			}
			case _: {
			}
		}
	}

	// Private function that is called on expressions that
	// are expected to return a value no matter what.
	//
	// If the expression is a "block-like" expression,
	// we call "standardizeSubscopeValue" to transform it
	// into a variable declaraion and scoped block that
	// modifies the aforementioned variable.
	function handleValueExpr(e: TypedExpr, varNameOverride: Null<String> = null) {
		if(isBlocklikeExpr(e)) {
			if(standardizeSubscopeValue(e, index, varNameOverride)) {
				index += 2;
			}
		} else {
			processExpr(e);
		}
	}

	// If a top-level, "block-like" expression is encountered
	// that is not expected to provide a value, we can simply
	// recursively use our "EverythingIsExprConversion" class
	// to tranverse it and handle its sub-expressions.
	function handleNonValueBlock(e: TypedExpr) {
		final eiec = new EverythingIsExprConversion(e, isLastExpression() ? assigneeExpr : null);
		e.expr = eiec.convertedExpr().expr;
	}

	// If the expression is a type of syntax that is typically
	// not an expression in other languages, but instead an
	// "expression holder", this returns true.
	function isBlocklikeExpr(e: TypedExpr) {
		return switch(e.expr) {
			case TBlock(_): true;
			case TIf(_, _, _): true;
			case TSwitch(_, _, _): true;
			case TTry(_, _): true;
			case _: false;
		}
	}

	function standardizeSubscopeValue(e: TypedExpr, index: Int, varNameOverride: Null<String> = null): Bool {
		var varName = nameGenerator.generateName(e.t, varNameOverride);

		final varAssignExpr = { expr: TConst(TNull), pos: e.pos, t: e.t };
		final tvar = {
			t: e.t,
			name: varName,
			meta: cast [],
			id: 9000000 + (variableId++),
			extra: { params: [], expr: varAssignExpr },
			capture: false
		};

		final tvarExprDef = TLocal(tvar);

		final idExpr = {
			expr: tvarExprDef,
			pos: e.pos,
			t: e.t
		};

		final eiec = new EverythingIsExprConversion(e, idExpr);
		
		final varExpr = {
			expr: TVar(tvar, varAssignExpr),
			pos: e.pos,
			t: e.t
		}

		topScopeArray.insert(index, varExpr);
		topScopeArray.insert(index + 1, eiec.convertedExpr());
		e.expr = tvarExprDef;

		return true;
	}
}

#end
