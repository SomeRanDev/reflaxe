package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.NullHelper;

/**
	Helper functions for `ClassType`.
**/
class ClassTypeHelper {
	public static function isTypeParameter(cls: ClassType): Bool {
		return switch(cls.kind) {
			case KTypeParameter(_): true;
			case _: false;
		}
	}

	public static function isExprClass(cls: ClassType): Bool {
		return switch(cls.kind) {
			case KExpr(_): true;
			case _: false;
		}
	}

	/**
		The Haxe compiler automatically takes fields with default
		expressions, removes the default expression, and assigns it
		instead to the field at the start of the constructor.
		
		This function checks the constructor expression for assignments
		that almost certainly are the result of this process.

		The resulting value contains two properties:
			- `assignments` is a map of the fields to their default values
			as `TypedExpr`.

			- `expressions` is a list of the original `TypedExpr`s.

			- `modifiedConstructor` is a modified `TypedExpr` from the
			constructor with the assignments removed. It can be used to
			generate a constructor with the assignments if desired.
	**/
	public static function extractPreconstructorFieldAssignments(cls: ClassType, overrideConstructorExpr: Null<TypedExpr> = null): Null<{
		assignments: Map<ClassField, TypedExpr>,
		expressions: Array<TypedExpr>,
		modifiedConstructor: TypedExpr
	}> {
		if(cls.constructor == null) {
			return null;
		}

		final constructorExpr = if(overrideConstructorExpr != null) {
			overrideConstructorExpr;
		} else {
			final constructor = cls.constructor.get();
			constructor.expr();
		}

		if(constructorExpr == null) {
			return null;
		}

		final exprList: Null<Array<TypedExpr>> = switch(constructorExpr.expr) {
			// For when using ClassField.expr()
			case TFunction(tfunc): {
				switch(tfunc.expr.expr) {
					case TBlock(exprList): exprList;
					case _: return null;
				}
			}

			// For when using `overrideConstructorExpr`
			case TBlock(exprList): exprList;

			case _: return null;
		}

		final exprList = exprList.trustMe();

		var remainingExprsIndex = 0;
		final expressions: Array<TypedExpr> = [];
		final result: Map<ClassField, TypedExpr> = [];
		for(expr in exprList.trustMe()) {
			remainingExprsIndex++;

			var fieldExpr = null;

			final defaultExpr = switch(expr.expr) {
				case TBinop(OpAssign, field, defaultExpr): {
					fieldExpr = field;
					defaultExpr;
				}
				case _: null;
			}

			if(defaultExpr == null || fieldExpr == null) {
				break;
			}

			final classField = switch(fieldExpr.expr) {
				case TField({ expr: TConst(TThis) }, FInstance(_.get() => fieldClass, _, cf)) if(Std.string(fieldClass) == Std.string(cls)): {
					final classField = cf.get();
					if(classField.hasDefaultValue()) {
						classField;
					} else {
						null;
					}
				}
				case _: null;
			}

			if(classField == null) {
				break;
			}
			
			expressions.push(expr);
			result.set(classField, defaultExpr);
		}

		return {
			assignments: result,
			expressions: expressions,
			modifiedConstructor: {
				expr: TBlock(exprList.slice(remainingExprsIndex - 1)),
				pos: constructorExpr.pos,
				t: constructorExpr.t
			}
		}
	}
}

#end
