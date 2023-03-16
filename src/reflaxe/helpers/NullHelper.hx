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

class NullHelper {
	public static function or<T>(maybe: Null<T>, defaultVal: T): T {
		return maybe != null ? maybe : defaultVal;
	}

	public static function trustMe<T>(maybe: Null<T>): T {
		@:nullSafety(Off) return maybe;
	}
}

#end
