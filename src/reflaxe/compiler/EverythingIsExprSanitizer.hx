// =======================================================
// * EverythingIsExprSanitizer
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

/**
	Converts block-like expressions that return a value into
	an equivalent expression that does not rely on Haxe's
	"Everything is an Expression" feature.

	View this page for more info on Haxe's "Everything is an Expression".
	https://code.haxe.org/category/principles/everything-is-an-expression.html
**/
class EverythingIsExprSanitizer {
	/**
		Whether a variable that will be initialized regardless
		should be initialized with `null`. I'm not sure what the
		default behavior should be, so I'll just control with
		a constant for now.
	**/
	public static final INIT_NULL = false;

	/**
		Stores the original, provided expression
	**/
	public var haxeExpr: TypedExpr;

	/**
		Stores the sub-expression list if the original is a TBlock
		Otherwise, is an array of length one containing "haxeExpr"
	**/
	public var topScopeArray: Array<TypedExpr>;
	var index: Int = 0;

	/**
		Reference to the BaseCompiler that using this sanitizer.
	**/
	public var compiler(default, null): BaseCompiler;

	/**
		If this expression is not null, the final expression of
		"topScopeArray" needs to be modified into an assignment
		expression assigning the final expression to "assigneeExpr"

		Used to convert `var a = { 123; }` into `var a; { a = 123 }`
		the latter being the standard syntax most languages use.
	**/
	public var assigneeExpr: Null<TypedExpr>;

	/**
		If this "EverythingIsExprSanitizer" was created from another
		"EverythingIsExprSanitizer", this is a reference to that
		original object.

		This is so we have one consistent object to manage the 
		new temporary variables names that are being created.
	**/
	public var parent: Null<EverythingIsExprSanitizer> = null;

	/**
		TODO, write overly eloborate comment here
	**/
	public var nameGenerator: TempVarNameGenerator;

	/**
		Expression stack.
	**/
	var expressionStack: Array<TypedExpr>;

	/**
		Meta stack.
	**/
	var metaStack: Array<String>;

	static var variableId = 0;

	public function new(expr: TypedExpr, compiler: BaseCompiler, assignee: Null<TypedExpr> = null, nGenerator: Null<TempVarNameGenerator> = null) {
		haxeExpr = expr.copy();
		this.compiler = compiler;

		topScopeArray = switch(haxeExpr.expr) {
			case TBlock(exprs): exprs.map(e -> e.copy());
			case _: [haxeExpr];
		}

		if(assignee != null) {
			assigneeExpr = assignee.copy();
		} else {
			assigneeExpr = null;
		}

		nameGenerator = nGenerator != null ? nGenerator : new TempVarNameGenerator();

		expressionStack = [];
		metaStack = [];
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
					expr: (newExprDef : TypedExprDef),
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

				// If there's a return, throw, continue, or break statement
				// at the end, we don't want to assign from it.
				// 
				// Convert:
				// var a = { return 123; };
				//
				// To:
				// var a;
				// { return 123; }
				final isNonAssignable = switch(old.expr) {
					case TReturn(_): true;
					case TThrow(_): true;
					case TBreak: true;
					case TContinue: true;
					case _: false;
				}

				if(!isNonAssignable && !isBlocklikeExpr(old)) {
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

	/**
		Depending on the expression, we can determine
		which expressions are treated like "values" in
		the Haxe code.

		An infinite while loop is used to locally replicate
		a recursive-like system when necessary.
	**/
	function processExpr(expr: TypedExpr): Null<TypedExprDef> {
		if(expr == null) return null;

		final pushed = switch(expr.expr) {
			case TParenthesis(_) | TMeta(_, _): false;
			case _: {
				expressionStack.push(expr);
				true;
			}
		}

		final result = switch(expr.expr) {
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
			case TCall(e, el): {
				final dontSanitize = switch(e.expr) {
					case TField(_, fa): {
						switch(fa) {
							case FInstance(c, _, _) | FStatic(c, _): {
								c.get().hasMeta(":noReflaxeSanitize");
							}
							case _: false;
						}
					}
					case _: false;
				}
				if(dontSanitize) {
					expr.expr;
				} else {
					TCall(
						handleValueExpr(e),
						handleValueExprList(el)
					);
				}
			}
			case TNew(c, params, el): {
				TNew(c, params, handleValueExprList(el));
			}
			case TUnop(op, postfix, expr): {
				TUnop(op, postfix, handleValueExpr(expr));
			}
			case TFunction(tfunc): {
				final newTFunc = Reflect.copy(tfunc).trustMe();
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
					edef != null ? handleNonValueBlock(edef) : null
				);
			}
			case TReturn(expr): {
				TReturn(expr != null ? handleValueExpr(expr, "result") : null);
			}
			case TMeta(m, e): {
				metaStack.push(m.name);
				final result = expr.copy(processExpr(e));
				metaStack.pop();
				TMeta(m, result);
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
			case TCast(e, m): {
				TCast(handleValueExpr(e), m);
			}
			case TEnumIndex(e): {
				TEnumIndex(handleValueExpr(e));
			}
			case TEnumParameter(e, ef, index): {
				TEnumParameter(handleValueExpr(e), ef, index);
			}
			case TBreak | TConst(_) | TContinue | TIdent(_) | TLocal(_) | TTypeExpr(_): {
				null;
			}
		}

		if(pushed) {
			expressionStack.pop();
		}

		return result;
	}

	/**
		Handle Non-Value Expression

		If a top-level, "block-like" expression is encountered
		that is not expected to provide a value, we can simply
		recursively use our "EverythingIsExprSanitizer" class
		to tranverse it and handle its sub-expressions.
	**/
	function handleNonValueBlock(e: TypedExpr): TypedExpr {
		if(compiler.options.convertUnopIncrement && isUnopExpr(e)) {
			final newExpr = standardizeUnopValue(e, false);
			if(newExpr != null) {
				e = newExpr;
			}
		}

		final eiec = new EverythingIsExprSanitizer(e, compiler, isLastExpression() ? assigneeExpr : null, nameGenerator);
		return eiec.convertedExpr();
	}

	/**
		Handle Value Expression

		Private function that is called on expressions that
		are expected to return a value no matter what.

		If the expression is a "block-like" expression,
		we call "standardizeSubscopeValue" to transform it
		into a variable declaraion and scoped block that
		modifies the aforementioned variable.

		There are also various transformations we need to
		look out for when an expression is used as a value.

		[isNullCoalExpr/standardizeNullCoalValue]
		Converts (a ?? b) => (a != null ? a : b)

		[isUnopExpr/standardizeUnopValue]
		Converts (a++) => (a += 1)

		[isFunctionRef/standardizeFunctionValue]
		Wraps functions passed as a variable in a lambda.

		[isAssignExpr/standardizeAssignValue]
		Converts (a = b = 1) => (b = 1; a = b)
	**/
	function handleValueExpr(e: TypedExpr, varNameOverride: Null<String> = null): TypedExpr {
		if(e == null) return { expr: TIdent("null"), pos: PositionHelper.unknownPos(), t: TDynamic(null) };
		if(compiler.options.convertNullCoal && isNullCoalExpr(e)) {
			final newExpr = standardizeNullCoalValue(e);
			if(newExpr != null) {
				e = newExpr;
			}
		}
		if(compiler.options.convertUnopIncrement && isUnopExpr(e)) {
			final newExpr = standardizeUnopValue(e, true);
			if(newExpr != null) {
				e = newExpr;
			}
		}
		if(isFunctionRef(e)) {
			final newExpr = standardizeFunctionValue(e);
			if(newExpr != null) {
				e = newExpr;
			}
		}

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

	/**
		Same as handleValueExpr, but works on Array of TypedExpr.
	**/
	function handleValueExprList(el: Array<TypedExpr>): Array<TypedExpr> {
		final newExprs = [];
		for(e in el) {
			newExprs.push(handleValueExpr(e));
		}
		return newExprs;
	}

	/**
		Assignment Expression Value

		If the expression is an assignment, it is transformed
		into two separate statements. The assignment is placed
		outside and the assigned expression is used afterward.
	**/
	function isAssignExpr(e: TypedExpr) {
		if(e == null) return false;
		return switch(e.expr) {
			case TBinop(OpAssign | OpAssignOp(_), _, _): true;
			case _: false;
		}
	}

	function standardizeAssignValue(e: TypedExpr, index: Int, varNameOverride: Null<String> = null): Null<TypedExpr> {
		final eiec = new EverythingIsExprSanitizer(e, compiler, null);
		topScopeArray.insert(index, eiec.convertedExpr());

		final left = switch(e.expr) {
			case TBinop(OpAssign | OpAssignOp(_), left, _): {
				left;
			}
			case _: null;
		}

		return left != null ? left.copy() : null;
	}

	/**
		Block-Like Values

		If the expression is a type of syntax that is typically
		not an expression in other languages, but instead an
		"expression holder", this returns true.

		The following couple of functions convert these
		block-like expressions into a standardized syntax
		if they're being treated like values.
	**/
	public static function isBlocklikeExpr(e: TypedExpr) {
		if(e == null) return false;
		return switch(e.expr) {
			case TBlock(_): true;
			case TIf(_, _, _): true;
			case TSwitch(_, _, _): true;
			case TTry(_, _): true;
			case TParenthesis(e1) | TMeta(_, e1): isBlocklikeExpr(e1);
			case _: false;
		}
	}

	/**
		Generates a TVar object given a name and Type.
	**/
	function genTVar(name: String, t: Type): TVar {
		// Let's construct the TVar using an expression.
		final ct = haxe.macro.TypeTools.toComplexType(t);
		final untypedExpr = INIT_NULL ? (macro var $name: $ct = null) : (macro var $name: $ct);

		// We must type the expression to get the TVar.
		// However, the type might contain type parameters or unknown types that might cause an error.
		// So if the typing fails, make sure it doesn't cause any problems.
		var typedExpr = #if macro try {
			Context.typeExpr(untypedExpr);
		} catch(e) #end {
			null;
		}

		// If the typing did fail, try again. But this time, exclude the variable type.
		var untypedTVar = false;
		if(typedExpr == null) {
			#if macro
			typedExpr = Context.typeExpr(INIT_NULL ? (macro var $name = null) : (macro var $name));
			untypedTVar = true;
			#end
		}

		if(typedExpr == null) {
			throw "Impossible";
		}

		// Finally, extract the TVar object from the TVar TypedExprDef.
		return switch(typedExpr.expr) {
			case TVar(tvar, _): {
				return if(untypedTVar) {
					final result: Dynamic = tvar;
					result.t = t;
					result;
				} else {
					tvar;
				}
			}
			case _: throw "Impossible. The expressions provided are always TVar.";
		}
	}

	function standardizeSubscopeValue(e: TypedExpr, index: Int, varNameOverride: Null<String> = null): Null<TypedExpr> {
		var varName = nameGenerator.generateName(e.t, varNameOverride);

		final varAssignExpr = { expr: TConst(TNull), pos: e.pos, t: e.t };
		final tvar = genTVar(varName, e.t);

		final tvarExprDef = TLocal(tvar);

		final idExpr = {
			expr: tvarExprDef,
			pos: e.pos,
			t: e.t
		};

		final eiec = new EverythingIsExprSanitizer(e, compiler, idExpr, nameGenerator);
		
		final varExpr = {
			expr: TVar(tvar, !INIT_NULL ? null : varAssignExpr),
			pos: e.pos,
			t: e.t
		}

		topScopeArray.insert(index, varExpr);
		topScopeArray.insert(index + 1, eiec.convertedExpr());

		return e.copy(tvarExprDef);
	}

	/**
		Null Coalesce Rewrite

		Converts `a ?? b` to `{ var _a = a; _a != null ? _a : b; }`
	**/
	function isNullCoalExpr(e: TypedExpr) {
		return switch(e.expr) {
			case TBinop(OpNullCoal, _, _): true;
			case _: false;
		}
	}

	function standardizeNullCoalValue(e: TypedExpr): Null<TypedExpr> {
		return switch(e.expr) {
			case TBinop(OpNullCoal, e1, e2): {
				final pos = PositionHelper.unknownPos();
				final t = TDynamic(null);
				final newName = nameGenerator.generateName(e.t, "maybeNull");
				final newNameExpr = { expr: TIdent(newName), t: t, pos: pos };
				final nullExpr = { expr: TConst(TNull), t: t, pos: pos };
				{
					expr: TBlock([
						{
							expr: TVar(genTVar(newName, e1.t), null),
							pos: e1.pos,
							t: t
						},
						{
							expr: TIf({
								expr: TBinop(OpNotEq, newNameExpr, nullExpr),
								t: t,
								pos: pos
							}, newNameExpr, e2),
							t: e1.t,
							pos: pos
						}
					]),
					t: e1.t,
					pos: e.pos
				}
			}
			case _: null;
		}
	}

	/**
		Prefix/Postfix Increment/Decrement Rewrite

		Certain targets don't support a++ or ++a.
		This converts the syntax into an assignment or
		block expression that is subsequently converted
		with later transformations.
	**/
	function isUnopExpr(e: TypedExpr) {
		return switch(e.expr) {
			case TUnop(OpIncrement | OpDecrement, _, _): true;
			case _: false;
		}
	}

	function standardizeUnopValue(e: TypedExpr, expectValue: Bool): Null<TypedExpr> {
		final opInfo = switch(e.expr) {
			case TUnop(op, postfix, internalExpr): { op: op, postfix: postfix, e: internalExpr };
			case _: null;
		}

		if(opInfo == null) return null;

		final pos = PositionHelper.unknownPos();
		final t = TDynamic(null);

		function getAddSubOp(isAdd: Bool) return isAdd ? Binop.OpAdd : Binop.OpSub;

		final oneExpr = { expr: TConst(TInt(1)), pos: pos, t: t };
		final isInc = opInfo.op == OpIncrement;
		final opExpr = { expr: TBinop(OpAssignOp(getAddSubOp(isInc)), opInfo.e, oneExpr), pos: pos, t: t };

		return if(expectValue) {
			final secondExpr = if(opInfo.postfix) {
				{ expr: TBinop(getAddSubOp(!isInc), opInfo.e, oneExpr), pos: pos, t: t };
			} else {
				opInfo.e;
			}

			{ expr: TBlock([opExpr, secondExpr]), pos: pos, t: t };
		} else {
			opExpr;
		}
	}

	/**
		Inline Function Wrapping

		Functions that are extern or use syntax injecting 
		metadata like @:native or @:nativeFunctionCode cannot
		be referenced at runtime. To help fix this, uncalled
		function values are wrapped in a lambda to enable
		complete support.
	**/
	function isFunctionRef(e: Null<TypedExpr>) {
		// Check if this feature is disabled
		final option = compiler.options.wrapFunctionReferences;
		if(option == Never) {
			return false;
		}

		// Ensure this is being referenced, not called!!
		// If it's being called, it can be treated like normal.
		final lastExpr = expressionStack[expressionStack.length - 1];
		if(lastExpr != null) {
			switch(lastExpr.expr) {
				case TCall(_, _): return false;
				case _:
			}
		}

		if(metaStack.contains(":wrappedInLambda")) {
			return false;
		}

		// Do not process nullable expression
		if(e == null) {
			return false;
		}

		// get FieldAccess
		var fieldAccess = null;
		switch(e.t) {
			case TFun(_, _): {
				switch(e.expr) {
					case TField(_, fa): {
						fieldAccess = fa;
					}
					case _:
				}
			}
			case _:
		}

		if(fieldAccess != null) {
			if(option == Yes) {
				return true;
			}

			var clsExtern = false;
			switch(fieldAccess) {
				case FInstance(clsTypeRef, _, cfRef) | FStatic(clsTypeRef, cfRef):
					clsExtern = clsTypeRef.get().isExtern;
				case _:
			}

			switch(fieldAccess) {
				case FInstance(_, _, cfRef) | FStatic(_, cfRef) | FAnon(cfRef) | FClosure(_, cfRef): {
					final cf = cfRef.get();
					if(option == ExternOnly && (clsExtern || cf.isExtern)) {
						return true;
					}

					final m = cf.meta;
					for(metaName in compiler.options.wrapFunctionMetadata) {
						if(m.maybeHas(metaName)) {
							return true;
						}
					}
				}
				case _:
			}
		}

		return false;
	}

	function standardizeFunctionValue(e: TypedExpr): Null<TypedExpr> {
		final pos = PositionHelper.unknownPos();

		final args = [];
		final createArgs = [];
		var retType: Null<haxe.macro.Type> = null;
		switch(e.t) {
			case TFun(tfunArgs, tfunRet): {
				for(a in tfunArgs) {
					args.push({
						expr: TIdent(a.name),
						pos: pos,
						t: a.t
					});
					createArgs.push(genTVar(a.name, a.t));
					retType = tfunRet;
				}
			}
			case _: false;
		}

		var voidType = #if eval Context.getType("Void") #else null #end;
		if(voidType == null) throw "Could not find void";

		retType = retType.or(voidType);

		// Expression for TFunction
		final funcExpr: TypedExpr = {
			expr: TReturn({
				expr: TCall({
					expr: TMeta({ name: ":wrappedInLambda", pos: pos }, e),
					pos: pos,
					t: retType.trustMe()
				}, args),
				pos: pos,
				t: voidType
			}),
			pos: pos,
			t: e.t
		};

		// Wrap in function expression
		final result = {
			expr: TBlock([{
				expr: TFunction({
					t: retType.trustMe(),
					expr: funcExpr,
					args: createArgs.map(a -> { value: null, v: a })
				}),
				pos: e.pos,
				t: e.t
			}]),
			pos: pos,
			t: e.t
		};

		final eiec = new EverythingIsExprSanitizer(result, compiler, null, nameGenerator);
		return unwrapBlock(eiec.convertedExpr());
	}

	function unwrapBlock(e: TypedExpr): TypedExpr {
		return switch(e.expr) {
			case TBlock(el) if(el.length == 1): el[0];
			case _: e;
		}
	}

	/**
		Preprocessing while

		The conditional expression within a while is executed
		multiple times, so it must be placed within the while.

		This collection of preprocessing functions helps fix
		this issue.
	**/
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
			case TParenthesis(e1) | TMeta(_, e1): isDisallowedInWhile(e1);
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

	function makeTExpr(def: TypedExprDef, pos: Null<haxe.macro.Expr.Position> = null, t: Null<haxe.macro.Type> = null): TypedExpr {
		return {
			expr: def,
			pos: pos.or(PositionHelper.unknownPos()),
			t: t.or(TDynamic(null))
		}
	}
}

#end
