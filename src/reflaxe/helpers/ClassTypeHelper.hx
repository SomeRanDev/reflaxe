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
}

#end
