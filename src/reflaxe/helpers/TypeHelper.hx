// =======================================================
// * TypeHelper
//
// Helpful for converting between ModuleTypes and Types.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

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

	public static function equals(type: Type, other: Type): String {
		return Std.string(type) == Std.string(other);
	}

	public static function getMeta(type: Type) {
		return switch(t) {
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
				clsType.module == clsType.name && clsType.name == "String";
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
