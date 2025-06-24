// =======================================================
// * NullableMetaAccessHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

/**
	Helpers for `Null<T>` types.
**/
class NullHelper {
	public static inline function or<T>(maybe: Null<T>, defaultVal: T): T {
		return maybe != null ? maybe : defaultVal;
	}

	public static inline function trustMe<T>(maybe: Null<T>): T {
		return orError(maybe, "Trusted on null value.");
	}

	public static inline function orError<T>(maybe: Null<T>, errorString: String): T {
		if(maybe == null) throw errorString;
		@:nullSafety(Off) return maybe;
	}
}

#end
