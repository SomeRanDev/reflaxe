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
		Extracts the `ClassVarData` from a variable `ClassField`.
	**/
	public static function findVarData(field: ClassField, clsType: ClassType, isStatic: Null<Bool> = null): Null<ClassVarData> {
		static var cache: Map<ClassField, ClassVarData> = [];

		if(cache.exists(field)) {
			return cache.get(field);
		}

		if(isStatic == null) {
			isStatic = clsType.statics.get().contains(field);
		}

		return switch(field.kind) {
			case FVar(read, write): {
				new ClassVarData(clsType, field, isStatic, read, write);
			}
			case _: {
				throw "Not a variable.";
			}
		}
	}

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
		static var cache: Map<ClassField, ClassFuncData> = [];

		if(cache.exists(field)) {
			return cache.get(field);
		}

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
				// Generate ClassFuncArg depending on whether TFunc is available.
				var index = 0;
				final dataArgs: Array<ClassFuncArg> = if(tfunc != null) {
					tfunc.args.map(a -> new ClassFuncArg(index++, a.v.t, a.value != null, a.v.name, a.value, a.v));
				} else {
					args.map(a -> new ClassFuncArg(index++, a.t, a.opt, a.name));
				}

				final kind = switch(field.kind) {
					case FMethod(kind): kind;
					case _: throw "Not a method.";
				}

				// Return the `ClassFuncData`
				final result = new ClassFuncData(clsType, field, isStatic, kind, ret, dataArgs, tfunc, tfunc != null ? tfunc.expr : null);
				for(a in dataArgs) a.setFuncData(result);
				cache.set(field, result);
				result;
			}
			case _: null;
		}
	}

	public static function findFuncDataFromType(field: ClassField, type: Type): Null<ClassFuncData> {
		return switch(type) {
			case TInst(clsRef, _): findFuncData(field, clsRef.get());
			case _: null;
		}
	}
}

#end
