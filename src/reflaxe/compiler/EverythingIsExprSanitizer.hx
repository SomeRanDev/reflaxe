// =======================================================
// * EverythingIsExprSanitizer
//
// Converts block-like expressions that return a value into
// an equivalent expression that does not rely on Haxe's
// "Everything is an Expression" feature.
//
// View this page for more info on Haxe's "Everything is an Expression".
// https://code.haxe.org/category/principles/everything-is-an-expression.html
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

using reflaxe.helpers.TypedExprHelper;

import haxe.macro.Type;

class EverythingIsExprSanitizer {
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
	// If this "EverythingIsExprSanitizer" was created from another
	// "EverythingIsExprSanitizer", this is a reference to that
	// original object.
	//
	// This is so we have one consistent object to manage the 
	// new temporary variables names that are being created.
	public var parent: Null<EverythingIsExprSanitizer> = null;

	// -------------------------------------------------------
	// TODO, write overly eloborate comment here
	public var nameGenerator: TempVarNameGenerator;

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

		nameGenerator = new TempVarNameGenerator();
	}

	function preprocessExpr() {
		for(i in 0...topScopeArray.length) {
			topScopeArray[i] = fixWhile(topScopeArray[i]);
		}
	}

	public function convertedExpr(): TypedExpr {
		preprocessExpr();

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
				if(old == null) {
					throw "Unexpected null encountered.";
				}
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
				TVar(tvar, expr != null ? handleValueExpr(expr) : null);
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
				TMeta(m, expr.copy(processExpr(e)));
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
		if(isAssignExpr(e)) {
			final newExpr = standardizeAssignValue(e, index, varNameOverride);
			if(newExpr != null) {
				index += 1;
				return newExpr;
			}
		} else if(isBlocklikeExpr(e)) {
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
	// recursively use our "EverythingIsExprSanitizer" class
	// to tranverse it and handle its sub-expressions.
	function handleNonValueBlock(e: TypedExpr): TypedExpr {
		final eiec = new EverythingIsExprSanitizer(e, isLastExpression() ? assigneeExpr : null);
		return eiec.convertedExpr();
	}

	// -------------------------------------------------------
	// If the expression is a type of syntax that is typically
	// not an expression in other languages, but instead an
	// "expression holder", this returns true.
	function isBlocklikeExpr(e: TypedExpr, recursive: Bool = false) {
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

		final eiec = new EverythingIsExprSanitizer(e, idExpr);
		
		final varExpr = {
			expr: TVar(tvar, varAssignExpr),
			pos: e.pos,
			t: e.t
		}

		topScopeArray.insert(index, varExpr);
		topScopeArray.insert(index + 1, eiec.convertedExpr());

		return e.copy(tvarExprDef);
	}

	// -------------------------------------------------------
	// If the expression is a type of syntax that is typically
	function isAssignExpr(e: TypedExpr, recursive: Bool = false) {
		return switch(e.expr) {
			case TBinop(OpAssign | OpAssignOp(_), _, _): true;
			case _: false;
		}
	}

	function standardizeAssignValue(e: TypedExpr, index: Int, varNameOverride: Null<String> = null): Null<TypedExpr> {
		final eiec = new EverythingIsExprSanitizer(e, null);
		topScopeArray.insert(index, eiec.convertedExpr());

		final left = switch(e.expr) {
			case TBinop(OpAssign | OpAssignOp(_), left, _): {
				left;
			}
			case _: null;
		}

		return left.copy();
	}

	// =======================================================
	// * Preprocessing while
	// The conditional expression within a while is executed
	// multiple times, so it must be placed within the while.
	//
	// This collection of preprocessing functions helps fix
	// this issue.
	// =======================================================

	function fixWhile(e: TypedExpr): TypedExpr {
		switch(e.expr) {
			case TWhile(econd, e, normalWhile): {
				if(isDisallowedInWhile(econd)) {
					final newCond = makeTExpr(TConst(TBool(true)), econd.pos, econd.t);
					final ifExpr = makeTExpr(TIf(makeTExpr(TUnop(OpNot, false, econd)), makeTExpr(TBreak), null));
					final newBlockExpr = makeTExpr(TBlock(normalWhile ? [ifExpr, e] : [e, ifExpr]));
					return {
						expr: TWhile(newCond, newBlockExpr, normalWhile),
						pos: e.pos,
						t: e.t
					};
				}
			}
			case _:
		}
		return haxe.macro.TypedExprTools.map(e, fixWhile);
	}

	function isDisallowedInWhile(e: TypedExpr) {
		return switch(e.expr) {
			case TBlock(_): true;
			case TIf(_, _, _): true;
			case TSwitch(_, _, _): true;
			case TTry(_, _): true;
			case TBinop(OpAssign, _, _): true;
			case TBinop(OpAssignOp(_), _, _): true;
			case TUnop(OpIncrement | OpDecrement, _, _): true;
			case _: {
				var result = false;
				haxe.macro.TypedExprTools.iter(e, function(e) {
					if(isDisallowedInWhile(e)) {
						result = true;
					}
				});
				result;
			};
		}
	}

	function makeTExpr(def: TypedExprDef, pos: Null<haxe.macro.Expr.Position> = null, t: Null<haxe.macro.Type> = null) {
		if(pos == null) {
			pos = haxe.macro.Context.makePosition({ min: 0, max: 0, file: "" });
		}
		if(t == null) {
			t = TDynamic(null);
		}
		return {
			expr: def,
			pos: pos,
			t: t
		}
	}
}

#end
