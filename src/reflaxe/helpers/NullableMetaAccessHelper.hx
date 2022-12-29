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

import haxe.macro.Context;
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

	public static function maybeAdd(m: Null<MetaAccess>, name: String, params: Array<Expr>, pos: Position): Void {
		if(m != null && m.add != null) {
			m.add(name, params, pos);
		}
	}

	// Extracts and formats content of @:meta metadata.
	// Can be used as easy method for retrieving metadata that should be generated in output.
	public static function extractNativeMeta(metaAccess: Null<MetaAccess>, allowMultiParam: Bool = true): Null<Array<String>> {
		if(metaAccess == null || metaAccess.extract == null) {
			return null;
		}
		final result = [];
		final meta = metaAccess.extract(":meta");
		for(m in meta) {
			if(m.params == null || m.params.length == 0) {
				Context.error("Native meta expression expected as parameter.", m.pos);
			}
			if(!allowMultiParam && m.params.length > 1) {
				Context.error("Only one expression should be supplied for native meta.", m.pos);
			}
			for(param in m.params) {
				result.push(haxe.macro.ExprTools.toString(param));
			}
		}
		return result;
	}
}

#end
