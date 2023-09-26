// =======================================================
// * DynamicHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

/**
	Quick static extensions to help with `Dynamic`.
**/
class DynamicHelper {
	public static function isString(d: Dynamic): Bool {
		return Std.string(Type.typeof(d)) == "TClass(Class<String>)";
	}
}

#end
