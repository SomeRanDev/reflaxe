package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ClassFieldHelper;

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
		that could POSSIBLY be the result of this process.
	**/
	public static function extractPreconstructorFieldAssignments(cls: ClassType): Map<ClassField, TypedExpr> {
		if(cls.constructor == null) {
			return [];
		}

		final constructor = cls.constructor.get();
		final constructorExpr = constructor.expr();
		if(constructorExpr == null) {
			return [];
		}

		final exprList = switch(constructorExpr.expr) {
			case TBlock(exprList): exprList;
			case _: return [];
		}

		final result: Map<ClassField, TypedExpr> = [];
		for(expr in exprList) {
			var fieldExpr = null;

			final defaultExpr = switch(expr.expr) {
				case TBinop(OpAssign, field, defaultExpr): {
					fieldExpr = field;
					defaultExpr;
				}
				case _: null;
			}

			if(defaultExpr == null || fieldExpr == null) {
				return result;
			}

			final classField = switch(fieldExpr.expr) {
				case TField({ expr: TConst(TThis) }, FInstance(_.get() == cls => true, _, cf)): {
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
				return result;
			}
			
			result.set(classField, defaultExpr);
		}

		return result;
	}
}

#end
