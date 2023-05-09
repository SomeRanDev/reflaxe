// =======================================================
// * TypeHelper
//
// Helpful for converting between ModuleTypes and Types.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullHelper;

class TypeHelper {
	public static function findResolvedTypeParams(t: Type, cf: ClassField): Null<Array<Type>> {
		if(cf.params.length == 0) {
			return [];
		}

		final result: Array<Null<Type>> = [];
		final paramNameIndexMap = new Map<String, Int>();
		for(i in 0...cf.params.length) {
			paramNameIndexMap.set(cf.params[i].name, i);
			result.push(null);
		}

		final resolvedTypes = getSubTypeList(t);
		final cfSubTypes = getSubTypeList(cf.type);

		for(key => subType in cfSubTypes) {
			final typeParamName = getTypeParameterName(subType);
			if(typeParamName != null && paramNameIndexMap.exists(typeParamName)) {
				final index = paramNameIndexMap.get(typeParamName);
				if(index != null && result[index] == null) {
					result[index] = resolvedTypes[key];
				}
			}
		}

		for(type in result) {
			if(type == null) {
				return null;
			}
		}

		// Safe to cast from Array<Null<Type>> to Array<Type> since we check for
		// any nulls in the for-loop directly before this.
		//
		// Only an Array without nulls can reach this return.
		return result.trustMe();
	}

	public static function getSubTypeList(t: Type): Map<String, Type> {
		final result: Map<String, Type> = [];
		var index = 0;
		if(t == null) {
			return [];
		}
		#if eval
		haxe.macro.TypeTools.iter(t, function(subType) {
			if(subType != null) {
				final si = Std.string(index);
				result.set(si, subType);
				for(id => subSubType in getSubTypeList(subType)) {
					result.set(si + "_" + id, subSubType);
				}
			}
			index++;
		});
		#end
		return result;
	}

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
				if(mt != null) {
					"T" + mt.getUniqueId();
				} else {
					"___TYPEUNIQUEID___" + Std.string(t);
				}
			}
		}
	}

	public static function equals(type: Type, other: Type): Bool {
		if(isNumberType(type) && isNumberType(other)) return true;
		return Std.string(type) == Std.string(other);
	}

	public static function getMeta(type: Type): Null<MetaAccess> {
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

	public static function withParams(t: Type, params: Array<Type>): Null<Type> {
		return switch(t) {
			case TEnum(e, _): TEnum(e, params);
			case TInst(i, _): TInst(i, params);
			case TType(t, _): TType(t, params);
			case TAbstract(a, _): TAbstract(a, params);
			case _: null;
		}
	}

	static function extractParamTypes(params: Array<TypeParameter>): Array<Type> {
		return params.map(tp -> tp.t);
	}

	// ----------------------------
	// Checks if the type is TMono.
	public static function isMonomorph(t: Type): Bool {
		return switch(t) {
			case TMono(_): true;
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is TType.
	public static function isTypedef(t: Type): Bool {
		return switch(t) {
			case TType(_, _): true;
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is TAnonymous.
	public static function isAnonStruct(t: Type): Bool {
		return switch(t) {
			case TAnonymous(_): true;
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is TDynamic.
	public static function isDynamic(t: Type): Bool {
		return switch(t) {
			case TDynamic(_): true;
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is Void.
	public static function isVoid(t: Type): Bool {
		return switch(t) {
			case TAbstract(absRef, []): {
				absRef.get().name == "Void";
			}
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is the String class.
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

	// ----------------------------
	// Checks if the type is an Int, Float, or Bool.
	public static function isPrimitive(t: Type): Bool {
		return switch(t) {
			case TAbstract(abTypeRef, []): {
				final abType = abTypeRef.get();
				abType.module == "StdTypes" && (abType.name == "Int" || abType.name == "Float" || abType.name == "Bool");
			}
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is an Int or Float.
	public static function isNumberType(t: Type): Bool {
		return switch(t) {
			case TAbstract(abTypeRef, []): {
				final abType = abTypeRef.get();
				abType.module == "StdTypes" && (abType.name == "Int" || abType.name == "Float");
			}
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is the Any abstract.
	public static function isAny(t: Type): Bool {
		return switch(t) {
			case TAbstract(absRef, []): {
				absRef.get().name == "Any";
			}
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is a Null<T>.
	public static function isNull(t: Type): Bool {
		return switch(t) {
			case TAbstract(absRef, params) if(params.length == 1): {
				absRef.get().name == "Null";
			}
			case _: false;
		}
	}

	// ----------------------------
	// Checks if the type is Class<T>.
	public static function isClass(t: Type): Bool {
		return getClassParameter(t) != null;
	}

	// ----------------------------
	// Checks if this is a variable whose type could
	// not be resolved. Probably because it was never
	// assigned.
	public static function isUnresolvedMonomorph(t: Type): Bool {
		return switch(t) {
			case TMono(tRef): {
				return tRef.get() == null;
			}
			case _: false;
		}
	}

	// ----------------------------
	public static function isTypeParameter(t: Type): Bool {
		return getTypeParameterName(t) != null;
	}

	// ----------------------------
	// If this is a placeholder type for a type parameter,
	// this returns the name of the type parameter.
	public static function getTypeParameterName(t: Type): Null<String> {
		return switch(t) {
			case TInst(clsRef, params): {
				switch(clsRef.get().kind) {
					case KTypeParameter(_): clsRef.get().name;
					case _: null;
				}
			}
			case _: null;
		}
	}

	// ----------------------------
	// If the type is Class<T>, this returns T.
	public static function getClassParameter(t: Type): Null<ModuleType> {
		return switch(t) {
			case TAbstract(absRef, [param]): {
				final abs = absRef.get();
				if(abs.name == "Class" && abs.module == "Class" && abs.pack.length == 0) {
					toModuleType(param);
				} else {
					null;
				}
			}
			case TType(defRef, []): {
				switch(defRef.get().type) {
					case TAnonymous(anon): {
						switch(anon.get().status) {
							case AClassStatics(clsRef): TClassDecl(clsRef);
							case AEnumStatics(enumRef): TEnumDecl(enumRef);
							case AAbstractStatics(absRef): TAbstract(absRef);
							case _: null;
						}
					}
					case _: null;
				}
			}
			case _: null;
		}
	}

	public static function wrapWithNull(t: Type): Type {
		return switch(Context.getType("Null")) {
			case TAbstract(abRef, _): {
				TAbstract(abRef, [t]);
			}
			case _: {
				throw "Could not find Null<T>";
			}
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

	public static function unwrapNullTypeOrSelf(t: Type): Type {
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

	public static function getTFunArgs(t: Type): Null<Array<{t: Type, opt: Bool, name: String}>> {
		return switch(t) {
			case TFun(args, _): args;
			case _: null;
		}
	}

	public static function getTFunReturn(t: Type): Null<Type> {
		return switch(t) {
			case TFun(_, ret): ret;
			case _: null;
		}
	}

	// Returns true if an abstract (or typedef to an abstract) with @:multiType.
	public static function isMultitype(t: Type): Bool {
		return switch(t) {
			#if eval
			case TType(defRef, _): {
				isMultitype(Context.follow(t));
			}
			#end
			case TAbstract(absRef, _): {
				absRef.get().hasMeta(":multiType");
			}
			case _: false;
		}
	}

	public static function isDescendantOf(t: Type, superClass: Type): Bool {
		return isChildOf(t, superClass) || implementsType(t, superClass);
	}

	public static function isChildOf(t: Type, superClass: Type): Bool {
		final superClassType = switch(superClass) {
			case TInst(clsRef, _): clsRef;
			case _: return false;
		}
		return switch(t) {
			case TInst(clsRef, _): {
				final c = clsRef.get();
				if(c.superClass != null) {
					ModuleTypeHelper.equals(TClassDecl(c.superClass.t), TClassDecl(superClassType));
				} else {
					false;
				}
			}
			case _: false;
		}
	}

	public static function implementsType(t: Type, interfaceType: Type): Bool {
		final interfaceClassType = switch(interfaceType) {
			case TInst(clsRef, _): clsRef;
			case _: return false;
		}
		if(!interfaceClassType.get().isInterface) {
			return false;
		}
		return switch(t) {
			case TInst(clsRef, _): {
				final c = clsRef.get();
				var result = false;
				for(int in c.interfaces) {
					if(ModuleTypeHelper.equals(TClassDecl(int.t), TClassDecl(interfaceClassType))) {
						result = true;
						break;
					}
				}
				result;
			}
			case _: false;
		}
	}
}

#end
