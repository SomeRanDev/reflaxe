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

typedef NameAndMeta = {
	var name(default, never): String;
	var meta(default, never): Null<MetaAccess>;
};

class NameMetaHelper {
	public static function getNameOrNative(v: NameAndMeta): String {
		if(v.meta != null && v.meta.has(":native")) {
			final metaList = v.meta.extract(":native");
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
}

#end
