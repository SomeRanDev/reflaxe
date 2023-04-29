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
	/**
		Extracts the `ClassFuncData` from a function `ClassField`.

		What's important to note is how arguments are retrieved here. There are two
		methods for extracting the arguments, using `TFunc` or using the field's
		`TFun` type.

		`TFunc` provides more information (such as the default value's `TypedExpr`
		and the `TVar`); however, it only exists if the function has code in it
		(functions might be extern or abstract). Therefore, if `TFunc` exists, the
		array of `ClassFuncArg`s is populated with detailed information, but if it
		doesn't, it falls back on the limited info within `TFun`.
	**/
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
				// Generate ClassFuncArg depending on whether tfunc is available.
				final dataArgs: Array<ClassFuncArg> = if(tfunc != null) {
					tfunc.args.map(a -> {
						t: a.v.t,
						opt: a.value != null,
						name: a.v.name,
						expr: a.value,
						tvar: a.v
					});
				} else {
					args.map(a -> {
						t: a.t,
						opt: a.opt,
						name: a.name,
						expr: null,
						tvar: null
					});
				}

				// Return the `ClassFuncData`
				{
					ret: ret,
					args: dataArgs,
					tfunc: tfunc,
					expr: tfunc != null ? tfunc.expr : null
				};
			}
			case _: null;
		}
	}
}

#end
