// =======================================================
// * ClassFieldHelper
//
// Quick static extensions to help with ClassField.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.BaseCompiler;

class ClassFieldHelper {
	public static function findFuncData(field: ClassField): Null<ClassFuncData> {
		final e = field.expr();
		final tfunc = if(e != null) {
			switch(e.expr) {
				case TFunction(tfunc): tfunc;
				case _: null;
			}
		} else {
			null;
		}
		return switch(field.type) {
			case TFun(args, ret): {
				ret: ret,
				args: args,
				tfunc: tfunc,
				expr: tfunc != null ? tfunc.expr : null
			}
			case _: null;
		}
	}
}

#end
