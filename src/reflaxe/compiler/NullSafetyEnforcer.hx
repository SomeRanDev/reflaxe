// =======================================================
// * NullTypeEnforcer
//
// A class that is activated if the "enforceNullTyping"
// option is enabled. It throws an error if an object
// is assigned or compared to `null` when not typed 
// with `Null<T>`.
//
// This can be helpful when developing static targets
// that may have strict requirements for the types that
// can be set to `null`.
//
// PLEASE NOTE this system does not enforce null safety.
// It simply ensures all interactions with `null` occur
// with `Null<T>` types.
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

class NullTypeEnforcer {
	static var returnTypeStack: Array<Type> = [];

	public static function checkAssignment(expr: Null<TypedExpr>, type: Null<Type>) {
		if(expr == null || type == null) return;
		if(expr.isNull() && !type.isNull()) {
			Context.error("Cannot assign `null` to non-nullable type.", expr.pos);
		}
	}

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

	public static function checkMaybeExpression(expr: Null<TypedExpr>) {
		if(expr == null) return;
		checkExpression(expr);
	}

	public static function checkExpression(expr: TypedExpr) {
		switch(expr.expr) {
			case TBinop(OpAssign | OpEq | OpNotEq, e1, e2): {
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
			case _: {}
		}
		haxe.macro.TypedExprTools.iter(expr, checkExpression);
	}
}

#end
