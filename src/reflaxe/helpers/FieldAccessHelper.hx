// =======================================================
// * ExprHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;

using reflaxe.helpers.ClassFieldHelper;

/**
	Quick static extensions to help with `FieldAccess`.
**/
class FieldAccessHelper {
	public static function getVarData(fa: FieldAccess): Null<ClassVarData> {
		return switch(fa) {
			case FInstance(clsRef, params, cfRef): {
				cfRef.get().findVarData(clsRef.get(), false);
			}
			case FStatic(clsRef, cfRef): {
				cfRef.get().findVarData(clsRef.get(), false);
			}
			case _: null;
		}
	}

	public static function getFuncData(fa: FieldAccess): Null<ClassFuncData> {
		return switch(fa) {
			case FInstance(clsRef, _, cfRef): {
				cfRef.get().findFuncData(clsRef.get(), false);
			}
			case FStatic(clsRef, cfRef): {
				cfRef.get().findFuncData(clsRef.get(), false);
			}
			case _: null;
		}
	}

	public static function getClassField(fa: FieldAccess): Null<ClassField> {
		return switch(fa) {
			case FInstance(_, _, cfRef): cfRef.get();
			case FStatic(_, cfRef): cfRef.get();
			case FAnon(cfRef): cfRef.get();
			case FClosure(_, cfRef): cfRef.get();
			case _: null;
		}
	}
}

#end
