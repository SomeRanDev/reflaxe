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
	// -------------------------------------------------------
	// Stores the original, provided expression
	public var haxeExpr: TypedExpr;

	// -------------------------------------------------------
	// Stores the sub-expression list if the original is a TBlock
	// Otherwise, is an array of length one containing "haxeExpr"
	public var topScopeArray: Array<TypedExpr>;
	var index: Int = 0;

	// -------------------------------------------------------
	// If this expression is not null, the final expression of
	// "topScopeArray" needs to be modified into an assignment
	// expression assigning the final expression to "assigneeExpr"
	//
	// Used to convert `var a = { 123; }` into `var a; { a = 123 }`
	// the latter being the standard syntax most languages use.
	public var assigneeExpr: Null<TypedExpr>;

	// -------------------------------------------------------
	// If this "EverythingIsExprConversion" was created from another
	// "EverythingIsExprConversion", this is a reference to that
	// original object.
	//
	// This is so we have one consistent object to manage the 
	// new temporary variables names that are being created.
	public var parent: Null<EverythingIsExprConversion> = null;

	// -------------------------------------------------------
	// TODO, write overly eloborate comment here
	public var nameGenerator: TempVariableNameGenerator;

	static var variableId = 0;

	public function new(expr: TypedExpr, assignee: Null<TypedExpr> = null) {
		haxeExpr = expr.copy();

		topScopeArray = switch(haxeExpr.expr) {
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
			// -------------------------------------------------------
			// Process the current expression, and if we get a 
			// modified TypedExprDef, we use it to make a copy
			// of the existing TypedExpr with the new definition.
			final expr = topScopeArray[index];
			final newExprDef = processExpr(expr);
			if(newExprDef != null) {
				topScopeArray[index] = {
					expr: newExprDef,
					pos: expr.pos,
					t: expr.t
				};
			}

			// -------------------------------------------------------
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

	// -------------------------------------------------------
	// Depending on the expression, we can determine
	// which expressions are treated like "values" in
	// the Haxe code.
	//
	// An infinite while loop is used to locally replicate
	// a recursive-like system when necessary.
	function processExpr(expr: TypedExpr): Null<TypedExprDef> {
		return switch(expr.expr) {
			case TArray(e1, e2): {
				TArray(
					handleValueExpr(e1, "array"),
					handleValueExpr(e2, "index")
				);
			}
			case TBinop(op, e1, e2): {
				TBinop(
					op,
					handleValueExpr(e1, "left"),
					handleValueExpr(e2, "right")
				);
			}
			case TField(e, field): {
				TField(handleValueExpr(e), field);
			}
			case TParenthesis(e): {
				TParenthesis(expr.copy(processExpr(e)));
			}
			case TObjectDecl(fields): {
				final newFields = [];
				for(field in fields) {
					newFields.push({ name: field.name, expr: handleValueExpr(field.expr) });
				}
				TObjectDecl(newFields);
			}
			case TArrayDecl(el): {
				TArrayDecl(handleValueExprList(el));
			}
			case TCall(expr, el): {
				TCall(
					handleValueExpr(expr),
					handleValueExprList(el)
				);
			}
			case TNew(c, params, el): {
				TNew(c, params, handleValueExprList(el));
			}
			case TUnop(op, postfix, expr): {
				TUnop(op, postfix, handleValueExpr(expr));
			}
			case TFunction(tfunc): {
				final newTFunc = Reflect.copy(tfunc);
				newTFunc.expr = handleNonValueBlock(tfunc.expr);
				TFunction(newTFunc);
			}
			case TVar(tvar, expr): {
				TVar(tvar, handleValueExpr(expr));
			}
			case TBlock(exprs): {
				handleNonValueBlock(expr).expr;
			}
			case TFor(v, e1, e2): {
				TFor(
					v,
					handleValueExpr(e1),
					handleNonValueBlock(e2)
				);
			}
			case TIf(econd, ifExpr, elseExpr): {
				TIf(
					handleValueExpr(econd, "cond"),
					handleNonValueBlock(ifExpr),
					elseExpr != null ? handleNonValueBlock(elseExpr) : null
				);
			}
			case TWhile(econd, expr, normalWhile): {
				TWhile(
					handleValueExpr(econd, "cond"),
					handleNonValueBlock(expr),
					normalWhile
				);
			}
			case TSwitch(expr, cases, edef): {
				final newCases = [];
				for(c in cases) {
					newCases.push({ values: c.values, expr: handleNonValueBlock(c.expr) });
				}
				TSwitch(
					handleValueExpr(expr),
					newCases,
					handleNonValueBlock(edef)
				);
			}
			case TReturn(expr): {
				TReturn(handleValueExpr(expr, "result"));
			}
			case TMeta(m, e): {
				TMeta(m, handleValueExpr(e));
			}
			case TThrow(e): {
				TThrow(handleValueExpr(e, "error"));
			}
			case TTry(e, catches): {
				final newCatches = [];
				for(c in catches) {
					newCatches.push({ v: c.v, expr: handleNonValueBlock(c.expr) });
				}
				TTry(handleNonValueBlock(e), newCatches);
			}
			case _: {
				null;
			}
		}
	}

	// -------------------------------------------------------
	// Private function that is called on expressions that
	// are expected to return a value no matter what.
	//
	// If the expression is a "block-like" expression,
	// we call "standardizeSubscopeValue" to transform it
	// into a variable declaraion and scoped block that
	// modifies the aforementioned variable.
	function handleValueExpr(e: TypedExpr, varNameOverride: Null<String> = null): TypedExpr {
		if(isBlocklikeExpr(e)) {
			final newExpr = standardizeSubscopeValue(e, index, varNameOverride);
			if(newExpr != null) {
				index += 2;
				return newExpr;
			}
		} else {
			final newExprDef = processExpr(e);
			if(newExprDef != null) {
				return e.copy(newExprDef);
			}
		}
		return e.copy();
	}

	// -------------------------------------------------------
	// Same as handleValueExpr, but works on Array of TypedExpr.
	function handleValueExprList(el: Array<TypedExpr>): Array<TypedExpr> {
		final newExprs = [];
		for(e in el) {
			newExprs.push(handleValueExpr(e));
		}
		return newExprs;
	}

	// -------------------------------------------------------
	// If a top-level, "block-like" expression is encountered
	// that is not expected to provide a value, we can simply
	// recursively use our "EverythingIsExprConversion" class
	// to tranverse it and handle its sub-expressions.
	function handleNonValueBlock(e: TypedExpr): TypedExpr {
		final eiec = new EverythingIsExprConversion(e, isLastExpression() ? assigneeExpr : null);
		return eiec.convertedExpr();
	}

	// -------------------------------------------------------
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

	function standardizeSubscopeValue(e: TypedExpr, index: Int, varNameOverride: Null<String> = null): Null<TypedExpr> {
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

		return e.copy(tvarExprDef);
	}
}

#end
