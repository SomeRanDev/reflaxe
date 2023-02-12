// =======================================================
// * TypeHelper
//
// Helpful for converting between ModuleTypes and Types.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;

class TypeHelper {
	public static function fromModuleType(t: ModuleType): Type {
		return switch(t) {
			case TClassDecl(c): TInst(c, extractParamTypes(c.get().params));
			case TEnumDecl(e): TEnum(e, extractParamTypes(e.get().params));
			case TTypeDecl(t): TType(t, extractParamTypes(t.get().params));
			case TAbstract(a): TAbstract(a, extractParamTypes(a.get().params));
		}
	}

	public static function toModuleType(t: Type): Null<ModuleType> {
		return switch(t) {
			case TInst(c, _): TClassDecl(c);
			case TEnum(e, _): TEnumDecl(e);
			case TType(t, _): TTypeDecl(t);
			case TAbstract(a, _): TAbstract(a);
			case TLazy(f): toModuleType(f());
			case TMono(t): {
				final type = t.get();
				if(type != null) {
					toModuleType(type);
				} else {
					null;
				}
			}
			case _: null;
		}
	}

	public static function getUniqueId(t: Type): String {
		return switch(t) {
			case TLazy(f): getUniqueId(f());
			case TAnonymous(_) | TFun(_, _): Std.string(t);
			case TDynamic(t): {
				if(t != null) {
					"TD" + getUniqueId(t);
				} else {
					"TD_Empty";
				}
			}
			case TMono(t): {
				final type = t.get();
				if(type != null) {
					"TM" + getUniqueId(type);
				} else {
					"TM_Empty";
				}
			}
			case _: {
				final mt = toModuleType(t);
				"T" + mt.getUniqueId();
			}
		}
	}

	public static function equals(type: Type, other: Type): Bool {
		return Std.string(type) == Std.string(other);
	}

	public static function getMeta(type: Type) {
		return switch(type) {
			case TInst(c, _): c.get().meta;
			case TEnum(e, _): e.get().meta;
			case TType(t, _): t.get().meta;
			case TAbstract(a, _): a.get().meta;
			case TLazy(f): getMeta(f());
			case TMono(t): {
				final type = t.get();
				if(type != null) {
					getMeta(type);
				} else {
					null;
				}
			}
			case _: null;
		}
	}

	public static function convertAnonToModuleType(t: Type): Null<ModuleType> {
		return switch(t) {
			case TAnonymous(anonTypeRef): {
				final anonType = anonTypeRef.get();
				switch(anonType.status) {
					case AClassStatics(c): TClassDecl(c);
					case AEnumStatics(e): TEnumDecl(e);
					case AAbstractStatics(a): TAbstract(a);
					case _: null;
				}
			}
			case _: null;
		}
	}

	public static function getParams(t: Type): Null<Array<Type>> {
		return switch(t) {
			case TEnum(_, params) |
				TInst(_, params) |
				TType(_, params) |
				TAbstract(_, params): params;
			case _: null;
		}
	}

	static function extractParamTypes(params: Array<TypeParameter>): Array<Type> {
		return params.map(tp -> tp.t);
	}

	public static function isString(t: Type): Bool {
		return switch(t) {
			case TInst(clsTypeRef, []): {
				final clsType = clsTypeRef.get();
				// Doing `clsType.name == "String"` will not work if the
				// String class has a @:native metadata.
				// There doesn't appear to be a way to get the original name,
				// so we just ignore this check if @:native exists.
				final isNameString = clsType.hasMeta(":native") || clsType.name == "String";
				isNameString && clsType.module == "String" && clsType.pack.length == 0 && clsType.hasMeta(":coreApi");
			}
			case _: false;
		}
	}

	public static function isPrimitive(t: Type): Bool {
		return switch(t) {
			case TAbstract(abTypeRef, []): {
				final abType = abTypeRef.get();
				abType.module == "StdTypes" && (abType.name == "Int" || abType.name == "Float" || abType.name == "Bool");
			}
			case _: false;
		}
	}

	public static function isNull(t: Type): Bool {
		return switch(t) {
			case TAbstract(absRef, params) if(params.length == 1): {
				absRef.get().name == "Null";
			}
			case _: false;
		}
	}

	public static function unwrapNullType(t: Type): Null<Type> {
		return switch(t) {
			case TAbstract(absRef, params) if(params.length == 1): {
				final abs = absRef.get();
				if(abs.name == "Null" && abs.pack.length == 0) {
					params[0];
				} else {
					null;
				}
			}
			case _: null;
		}
	}

	public static function unwrapNullTypeOrSelf(t: Type): Null<Type> {
		final temp = unwrapNullType(t);
		return temp != null ? temp : t;
	}

	public static function unwrapArrayType(t: Type): Null<Type> {
		return switch(t) {
			case TInst(clsRef, params) if(params.length == 1): {
				final cls = clsRef.get();
				if(cls.name == "Array" && cls.pack.length == 0) {
					params[0];
				} else {
					null;
				}
			}
			case _: null;
		}
	}
}

#end
