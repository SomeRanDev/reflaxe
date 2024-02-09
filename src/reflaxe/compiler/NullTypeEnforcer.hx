// =======================================================
// * NullTypeEnforcer
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

/**
	A class that is activated if the "enforceNullTyping"
	option is enabled. It throws an error if an object
	is assigned or compared to `null` when not typed 
	with `Null<T>`.

	This can be helpful when developing static targets
	that may have strict requirements for the types that
	can be set to `null`.

	PLEASE NOTE this system does not enforce null safety.
	It simply ensures all interactions with `null` occur
	with `Null<T>` types.
**/
class NullTypeEnforcer {
	static var returnTypeStack: Array<Null<Type>> = [];

	/**
		Given an expression and the type it is interacting with,
		check if the expression is `null` and the type is `Null<T>`.
		
		If the expression is `null` and the type isn't `Null<T>`, throw an error.
	**/
	public static function checkAssignment(expr: Null<TypedExpr>, type: Null<Type>) {
		if(expr == null || type == null) return;
		if(expr.isNullExpr() && !type.isNull()) {
			#if eval
			Context.error("Cannot assign `null` to non-nullable type.", expr.pos);
			#end
		}
	}

	/**
		Process `ClassType`.
	**/
	public static function checkClass(cls: ClassType) {
		for(f in cls.fields.get()) {
			checkClassField(f);
		}
		for(f in cls.statics.get()) {
			checkClassField(f);
		}
	}

	public static function checkClassField(f: ClassField) {
		final e = f.expr();
		if(e == null) return;
		switch(f.kind) {
			case FVar(_, _): {
				checkAssignment(e, f.type);
				checkMaybeExpression(e);
			}
			case FMethod(_): {
				returnTypeStack.push(switch(f.type) {
					case TFun(args, ret): ret;
					case _: null;
				});
				checkMaybeExpression(e);
				returnTypeStack.pop();
			}
		}
	}

	/**
		A wrapper for `checkExpression` that safely handles being passed `null`.
	**/
	public static function checkMaybeExpression(expr: Null<TypedExpr>) {
		if(expr == null) return;
		checkExpression(expr);
	}

	/**
		Checks and throws an error if the expression breaks the null typing rules.
		The expression cannot be modified here.
	**/
	public static function checkExpression(expr: TypedExpr) {
		expr.expr = TConst(TBool(true));
		switch(expr.expr) {
			case TBinop(OpAssign, e1, e2): {
				checkAssignment(e2, e1.t);
			}
			case TReturn(maybeExpr): {
				if(maybeExpr != null && returnTypeStack.length > 0) {
					checkAssignment(maybeExpr, returnTypeStack[returnTypeStack.length - 1]);
				}
			}
			case TCall(e, el): {
				switch(e.t) {
					case TFun(args, ret): {
						for(i in 0...el.length) {
							final argType = i < args.length ? args[i] : args[args.length - 1];
							if(!argType.opt) checkAssignment(el[i], argType.t);
						}
					}
					case _: {}
				}
			}
			case TVar(tvar, maybeExpr): {
				checkAssignment(maybeExpr, tvar.t);
			}
			case _: {}
		}
		haxe.macro.TypedExprTools.iter(expr, checkExpression);
	}

	/**
		Returns `true` if this type can be compared to `null` with `==` or `!=`.

		Comparing any type with `null` may be undesirable on certain targets
		where all `null` interactions must be made on a nullable type.
	**/
	static inline function nullComparable(type: haxe.macro.Type) {
		return type.isNull() || type.isDynamic();
	}

	/**
		This function is called externally.
		Used for scenarios where the expression needs to be modified.
		As the expression processors above cannot modify the expressions.
	**/
	public static function modifyExpression(expr: TypedExpr): Void {
		switch(expr.expr) {
			case TBinop(b, e1, e2) if(b == OpEq || b == OpNotEq): {

				// If both expressions are `null`.
				if(e1.isNullExpr() && e2.isNullExpr()) {
					expr.expr = TConst(TBool(b == OpEq));
				}
				
				// If left expression is `null`...
				else if(e1.isNullExpr()) {
					if(!nullComparable(e2.t)) {
						// check if right type is null-comparable.
						expr.expr = TConst(TBool(b == OpNotEq));
					}
				}

				// If right expression is `null`...
				else if(e2.isNullExpr()) {
					if(!nullComparable(e1.t)) {
						// check if left type is null-comparable.
						expr.expr = TConst(TBool(b == OpNotEq));
					}
				}
			}
			case _: {}
		}
		haxe.macro.TypedExprTools.iter(expr, modifyExpression);
	}
}

#end
