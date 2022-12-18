// =======================================================
// * NameMetaHelper
//
// This is a static extension for all objects with a
// "String name" and a "MetaAccess meta". This is a 
// common pattern in ModuleType types and TVar.
//
// To allow compiler developers to easily grab
// either the name or the contents of the correlating
// @:native meta from one of these classes, this helper
// class exists.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.NullableMetaAccessHelper;

typedef NameAndMeta = {
	var name(default, never): String;
	var meta(default, never): Null<MetaAccess>;
};

class NameMetaHelper {
	public static function getNameOrMeta(v: NameAndMeta, metaName: String): String {
		if(hasMeta(v, metaName)) {
			final metaList = v.meta.maybeExtract(metaName);
			for(m in metaList) {
				if(m.params.length > 0) {
					switch(m.params[0].expr) {
						case EConst(CString(s, _)): return s;
						case _:
					}
				}
			}
		}
		return v.name;
	}

	public static function hasMeta(v: NameAndMeta, metaName: String) {
		return v.meta != null && v.meta.has != null && v.meta.has(metaName);
	}

	public static function getNameOrNative(v: NameAndMeta): String {
		return getNameOrMeta(v, ":native");
	}

	public static function getNameOrNativeName(v: NameAndMeta): String {
		return getNameOrMeta(v, ":nativeName");
	}

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
}

#end
