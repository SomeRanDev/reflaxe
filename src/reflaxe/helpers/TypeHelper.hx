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

	static function extractParamTypes(params: Array<TypeParameter>): Array<Type> {
		return params.map(tp -> tp.t);
	}

	public static function isString(t: Type): Bool {
		return switch(t) {
			case TInst(clsTypeRef, []): {
				final clsType = clsTypeRef.get();
				clsType.module.length == 0 && clsType.name == "String";
			}
			case _: false;
		}
	}

	public static function isPrimitive(t: Type): Bool {
		return switch(t) {
			case TAbstract(abTypeRef, []): {
				final abType = abTypeRef.get();
				abType.module.length == 0 && (abType.name == "Int" || abType.name == "Float" || abType.name == "Bool");
			}
			case _: false;
		}
	}
}

#end
