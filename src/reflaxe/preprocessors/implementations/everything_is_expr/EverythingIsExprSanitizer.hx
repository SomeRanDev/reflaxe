// =======================================================
// * EverythingIsExprSanitizer
// =======================================================

package reflaxe.preprocessors.implementations.everything_is_expr;

#if (macro || reflaxe_runtime)

import reflaxe.helpers.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;

using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.FieldAccessHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.OperatorHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

/**
	Used for `BaseCompilerOptions.wrapFunctionReferencesWithLambda`.
**/
enum LambdaWrapType {
	/**
		Reflaxe will never wrap function references.
	**/
	Never;

	/**
		Reflaxe will ONLY wrap function fields that use
		`@:native`, `@:nativeFunctionCode`, or whatever
		is listed in the `wrapFunctionMetadata` option.
	**/
	NativeMetaOnly;

	/**
		Reflaxe will wrap both extern function references
		and `wrapFunctionMetadata` metadata fields.

		This includes both functions marked `extern` and
		functions from `extern` classes.
	**/
	ExternOnly;

	/**
		Reflaxe will wrap all function references.
	**/
	Yes;
}

/**
	Options for `ExpressionPreprocessor.EverythingIsExprSanitizer`.
**/
@:structInit
class EverythingIsExprSanitizerOptions {
	/**
		If `true`, during the EIE normalization phase, all
		instances of prefix/postfix increment and decrement
		are converted to a Binop form.

		Helpful on Python-like targets that do not support
		the `++` or `--` operators.
	**/
	public var convertIncrementAndDecrementOperators: Bool = false;

	/**
		If `true`, during the EIE normalization phase, all
		instances of null coalescence are converted to a
		null-check if statement.
	**/
	public var convertNullCoalescing: Bool = false;

	/**
		If `true`, variables generated for "Everything is an Expression" 
		will be initialized with `null` and wrapped with `Null<T>`.
	**/
	public var setUninitializedVariablesToNull: Bool = false;

	/**
		When enabled, function properties that are referenced
		as a value will be wrapped in a lambda.

		For example this:
		```haxe
		var fcc = String.fromCharCode
		```

		Gets converted to this:
		```haxe
		var fcc = function(i: Int): String {
			return String.fromCharCode(i);
		}
		```
	**/
	public var wrapFunctionReferencesWithLambda: LambdaWrapType = ExternOnly;

	/**
		If `wrapFunctionReferencesWithLambda` is set to either `NativeMetaOnly`
		or `ExternOnly`, the metadata listed here will trigger a
		function to be wrapped in a lambda.

		Metadata that will modify the code that's generated for a
		function at its call-site should be included here.
	**/
	public var wrapFunctionMetadata: Array<String> = [
		":native",
		":nativeFunctionCode"
	];
}

/**
	Converts block-like expressions that return a value into
	an equivalent expression that does not rely on Haxe's
	"Everything is an Expression" feature.

	View this page for more info on Haxe's "Everything is an Expression".
	https://code.haxe.org/category/principles/everything-is-an-expression.html
**/
class EverythingIsExprSanitizer {
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
		The `EverythingIsExprSanitizerOptions` config for this.
	**/
	var options: EverythingIsExprSanitizerOptions;

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
		Stores variables' expressions in this block by ID.
	**/
	public var variables(default, null): Map<Int, Null<TypedExpr>> = [];

	/**
		Variable usage tracker.
	**/
	public var variableUsageCount(default, null): Null<Map<Int, Int>> = null;

	/**
		Expression stack.
	**/
	var expressionStack: Array<TypedExpr>;

	/**
		Meta stack.
	**/
	var metaStack: Array<String>;

	public function new(expr: TypedExpr, options: EverythingIsExprSanitizerOptions, parent: Null<EverythingIsExprSanitizer> = null, assignee: Null<TypedExpr> = null, nGenerator: Null<TempVarNameGenerator> = null) {
		haxeExpr = expr.copy();
		this.options = options;
		this.parent = parent;

		// Only top-level sanitizer should have counter
		if(parent == null) {
			variableUsageCount = [];
		}

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

	/**
		Search through parents to find valid `variableUsageCount`.
	**/
	function getVariableUsageCount(): Map<Int, Int> {
		var p = this;
		while(p.parent != null) {
			p = p.parent;
		}
		return p.variableUsageCount.trustMe(); // The top-most should always exist.
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

		// No reason to wrap in TBlock if it's just one block-like expression already.
		if(topScopeArray.length == 1 && isBlocklikeExpr(topScopeArray[0])) {
			return topScopeArray[0];
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
				final leftExpr = handleValueExpr(e1, "left", op.isAssign());
				final rightExpr = handleValueExpr(e2, "right");

				#if reflaxe.allow_rose
				final rose = ReassignOnSubfieldEdit.checkForROSE(this, op, leftExpr, rightExpr);
				if(rose != null) {
					rose;
				} else #end {
					TBinop(op, leftExpr, rightExpr);
				}
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
			case TVar(tvar, maybeExpr): {
				if(maybeExpr != null) {
					variables.set(tvar.id, maybeExpr);
				}
				getVariableUsageCount().set(tvar.id, 0);
				TVar(tvar, maybeExpr != null ? handleValueExpr(maybeExpr) : null);
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
			case TLocal(tvar): {
				final vuc = getVariableUsageCount();
				vuc.set(tvar.id, (vuc.get(tvar.id) ?? 0) + 1);
				null;
			}
			case TBreak | TConst(_) | TContinue | TIdent(_) | TTypeExpr(_): {
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
		if(options.convertIncrementAndDecrementOperators && isUnopExpr(e)) {
			final newExpr = standardizeUnopValue(e, false);
			if(newExpr != null) {
				e = newExpr;
			}
		}

		final eiec = new EverythingIsExprSanitizer(e, options, this, isLastExpression() ? assigneeExpr : null, nameGenerator);
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
	function handleValueExpr(e: TypedExpr, varNameOverride: Null<String> = null, isLvalue: Bool = false): TypedExpr {
		if(e == null) {
			return { expr: TIdent("null"), pos: PositionHelper.unknownPos(), t: TDynamic(null) };
		}

		switch(e.expr) {
			case TParenthesis(e): {
				return { expr: TParenthesis(handleValueExpr(e)), pos: e.pos, t: e.t };
			}
			case _:
		}

		if(options.convertNullCoalescing && isNullCoalExpr(e)) {
			final newExpr = standardizeNullCoalValue(e);
			if(newExpr != null) {
				e = newExpr;
			}
		}
		if(options.convertIncrementAndDecrementOperators && isUnopExpr(e)) {
			final newExpr = standardizeUnopValue(e, true);
			if(newExpr != null) {
				e = newExpr;
			}
		}
		if(!isLvalue && isFunctionRef(e)) {
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
			final inlinable = isInlinableBlocklikeExpr(e);
			if(inlinable != null) {
				return handleValueExpr(inlinable);
			}

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
		final eiec = new EverythingIsExprSanitizer(e, options, this);
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
		Similar to the function above, this function checks if the
		provided TypedExpr `e` is a block-like expression.

		However, if the block-like expression can be safely replaced
		with a non-block-like expression, this function returns the
		expression that can replace it. Otherwise, `null` is returned.

		This occurs for block expressions with one expression inside.
	**/
		public static function isInlinableBlocklikeExpr(e: TypedExpr): Null<TypedExpr> {
			if(e == null) return null;
			return switch(e.expr) {
				case TBlock(expressions) if(expressions.length == 1): expressions[0];
				case TParenthesis(e1): {
					final inner = isInlinableBlocklikeExpr(e1);
					inner != null ? e.copy(TParenthesis(inner)) : null;
				}
				case TMeta(m, e1): {
					final inner = isInlinableBlocklikeExpr(e1);
					inner != null ? e.copy(TMeta(m, inner)) : null;
				}
				case _: null;
			}
		}

	/**
		Generates a TVar object given a name and Type.
	**/
	function genTVar(name: String, t: Type): TVar {
		final initNull = options.setUninitializedVariablesToNull;

		// Let's construct the TVar using an expression.
		var ct = haxe.macro.TypeTools.toComplexType(t);
		if(ct != null && initNull) {
			ct = macro : Null<$ct>;
		}
		final untypedExpr = initNull ? (macro var $name: $ct = null) : (macro var $name: $ct);

		// We must type the expression to get the TVar.
		// However, the type might contain type parameters or unknown types that might cause an error.
		// So if the typing fails, make sure it doesn't cause any problems.
		var typedExpr = try {
			Context.typeExpr(untypedExpr);
		} catch(e) {
			null;
		}

		// If the typing did fail, try again. But this time, exclude the variable type.
		var untypedTVar = false;
		if(typedExpr == null) {
			typedExpr = Context.typeExpr(initNull ? (macro var $name = null) : (macro var $name));
			untypedTVar = true;
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

		final eiec = new EverythingIsExprSanitizer(e, options, this, idExpr, nameGenerator);
		
		final initNull = options.setUninitializedVariablesToNull;

		// Wrap `e.t` with `Null<T>` if initializing with `null`.
		final t = if(initNull && !e.t.isNull()) {
			static var absRef: Null<Ref<AbstractType>> = null;
			if(absRef == null) {
				absRef = switch(Context.getType("Null")) {
					case TAbstract(absRef, _): absRef;
					case _: throw "`Null` does not refer to an abstract type.";
				}
			}
			TAbstract(absRef, [e.t]);
		} else {
			e.t;
		}

		// Generate TVar
		final varExpr = {
			expr: TVar(tvar, !initNull ? null : varAssignExpr),
			pos: e.pos,
			t: t
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
		final t = e.t;

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
		final option = options.wrapFunctionReferencesWithLambda;
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
					for(metaName in options.wrapFunctionMetadata) {
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

		final eiec = new EverythingIsExprSanitizer(result, options, this, null, nameGenerator);
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
