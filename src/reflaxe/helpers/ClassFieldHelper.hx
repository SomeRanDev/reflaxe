// =======================================================
// * ClassFieldHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.data.ClassFuncArg;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;

/**
	Quick static extensions to help with `ClassField`.
**/
class ClassFieldHelper {
	public static function isVarKind(field: ClassField): Bool {
		return switch(field.kind) {
			case FVar(_, _): true;
			case _: false;
		}
	}

	public static function isMethodKind(field: ClassField): Bool {
		return switch(field.kind) {
			case FMethod(_): true;
			case _: false;
		}
	}

	public static function equals(field: ClassField, other: ClassField): Bool {
		return Std.string(field) == Std.string(other);
	}

	// TODO: change to local static after Haxe bug is fixed
	// https://github.com/HaxeFoundation/haxe/issues/11193
	static var findVarData_cache: Map<String, ClassVarData> = [];
	static var findFuncData_cache: Map<String, ClassFuncData> = [];

	/**
		Generates a unique `String` id for a `ClassField`.
	**/
	static function generateId(isVar: Bool, field: ClassField, clsType: ClassType) {
		return if(isVar) {
			'${clsType.pack.join(".")} ${clsType.name} ${field.name}';
		} else {
			var id = '${clsType.pack.join(".")} ${clsType.name} ${field.name}';
			if(field.overloads.get().length != 0) {
				id += switch(field.type) {
					case TFun(args, ret): 
						args.map(a -> a.name + " " + Std.string(a.t)) + ":" + Std.string(ret);
					case _:
						"";
				}
			}
			id;
		}
	}

	/**
		Extracts the `ClassVarData` from a variable `ClassField`.
	**/
	public static function findVarData(field: ClassField, clsType: ClassType, isStatic: Null<Bool> = null): Null<ClassVarData> {
		final id = generateId(true, field, clsType);
		if(findVarData_cache.exists(id)) {
			return findVarData_cache.get(id);
		}

		if(isStatic == null) {
			isStatic = clsType.statics.get().filter(f -> f.name == field.name).length > 0;
		}

		return switch(field.kind) {
			case FVar(read, write): {
				final result = new ClassVarData(clsType, field, isStatic, read, write);
				findVarData_cache.set(id, result);
				result;
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
	public static function findFuncData(field: ClassField, clsType: ClassType, isStatic: Null<Bool> = null): Null<ClassFuncData> {
		final id = generateId(false, field, clsType);
		if(findFuncData_cache.exists(id)) {
			return findFuncData_cache.get(id);
		}

		// If `isStatic` is not explicitly provided, manually check if is static.
		if(isStatic == null) {
			isStatic = false;
			for(s in clsType.statics.get()) {
				if(equals(s, field)) {
					isStatic = true;
					break;
				}
			}
		}

		// Extract TFunc
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
					tfunc.args.map(a -> new ClassFuncArg(index++, a.v.t, a.value != null, a.v.name, a.v.meta, a.value, a.v));
				} else {
					args.map(a -> new ClassFuncArg(index++, a.t, a.opt, a.name));
				}

				final kind = switch(field.kind) {
					case FMethod(kind): kind;
					case _: throw "Not a method.";
				}

				// Return the `ClassFuncData`
				final result = new ClassFuncData(id, clsType, field, isStatic, kind, ret, dataArgs, tfunc, tfunc != null ? tfunc.expr : null);
				for(a in dataArgs) a.setFuncData(result);
				findFuncData_cache.set(id, result);
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

	public static function getAllVariableNames(data: ClassFuncData, compiler: BaseCompiler) {
		final fields = data.classType.fields.get();
		final fieldNames = [];
		for(f in fields) {
			switch(f.kind) {
				case FVar(_, _): fieldNames.push(compiler.compileVarName(f.name, null, f));
				case _: {}
			}
		}
		return fieldNames;
	}

	public static function hasDefaultValue(field: ClassField): Bool {
		return field.hasMeta(":value");
	}

	public static function getHaxeName(field: ClassField): String {
		return if(field.hasMeta(":realPath")) {
			field.meta.extractStringFromFirstMeta(":realPath") ?? field.name;
		} else {
			field.name;
		}
	}
}

#end
