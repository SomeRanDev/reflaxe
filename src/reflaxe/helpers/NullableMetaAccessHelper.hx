// =======================================================
// * NullableMetaAccessHelper
//
// MetaAccess can be annoying sometimes because the
// functions themselves may be null. These helper
// functions wrap around the normal MetaAccess functions
// and ensure they are not null before calling.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;
import haxe.macro.Expr;

class NullableMetaAccessHelper {
	public static function maybeHas(m: Null<MetaAccess>, name: String): Bool {
		return m != null && m.has != null && m.has(name);
	}

	public static function maybeExtract(m: Null<MetaAccess>, name: String): Array<MetadataEntry> {
		if(m == null || m.extract == null) return [];
		return m.extract(name);
	}
}

#end
