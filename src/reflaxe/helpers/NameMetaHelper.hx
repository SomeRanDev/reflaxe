// =======================================================
// * NameMetaHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;

typedef NameAndMeta = {
	var name(default, never): String;
	var meta(default, never): Null<MetaAccess>;
};

/**
	This is a static extension for all objects with a
	`name: String` and a `meta: MetaAccess`. This is a 
	common pattern in `ModuleType` types and `TVar`.

	To allow compiler developers to easily grab
	either the name or the contents of the correlating
	`@:native` meta from one of these classes, this helper
	class exists.
**/
class NameMetaHelper {
	static var nativeNameOverrides: Map<String, String> = [];

	/**
		Returns `true` if a meta of `metaName` exists on the `MetaAccess`
		meta property.
	**/
	public static function hasMeta(v: NameAndMeta, metaName: String) {
		return v.meta != null && v.meta.has != null && v.meta.has(metaName);
	}

	/**
		Given an object with the properties: `{ name: String, meta: MetaAccess }`,
		this function will return the first argument of the meta of name
		`metaName`. If no meta of that name can be found, the `name`
		property is returned otherwise.
	**/
	public static function getNameOrMeta(v: NameAndMeta, metaName: String): String {
		if(hasMeta(v, metaName)) {
			final result = v.meta.extractStringFromFirstMeta(metaName);
			if(result != null) return result;
		}
		return v.name;
	}

	/**
		Returns the first argument of the `@:native` meta or the `name`
		property of the supplied object.
	**/
	public static function getNameOrNative(v: NameAndMeta): String {
		return getNameOrMeta(v, ":native");
	}

	/**
		If this object has a `@:nativeName` meta, the first argument
		of that meta is returned.

		This also retrieves any overrides configured with init macros.
	**/
	public static function getNameOrNativeName(v: NameAndMeta): String {
		if(hasMeta(v, ":nativeName")) {
			final result = v.meta.extractParamsFromFirstMeta(":nativeName");
			if(result != null && result.length > 1) {
				final id = result[1];
				if(nativeNameOverrides.exists(id)) {
					return nativeNameOverrides.get(id).trustMe();
				}
			}
		}
		return getNameOrMeta(v, ":nativeName");
	}

	/**
		Returns an instance of `NameMeta` from the content found in a 
		`FieldAccess`.
	**/
	public static function getFieldAccessNameMeta(fa: FieldAccess): NameAndMeta {
		return switch(fa) {
			case FInstance(_, _, classFieldRef): classFieldRef.get();
			case FStatic(_, classFieldRef): classFieldRef.get();
			case FAnon(classFieldRef): classFieldRef.get();
			case FClosure(_, classFieldRef): classFieldRef.get();
			case FEnum(_, enumField): enumField;
			case FDynamic(s): { name: s, meta: null };
		}
	}

	/**
		Call to override all `@:nativeName` values with a certain ID.
	**/
	public static function setNativeNameOverride(id: String, overrideValue: String) {
		nativeNameOverrides.set(id, overrideValue);
	}

	/**
		Call to override all `@:nativeName` values with a certain ID.
	**/
	public static function getNativeNameOverride(id: String): Null<String> {
		return nativeNameOverrides.get(id);
	}
}

#end
