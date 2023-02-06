// =======================================================
// * DynamicHelper
//
// Quick static extensions to help with Dynamic.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

class DynamicHelper {
	public static function isString(d: Dynamic): Bool {
		return Std.string(Type.typeof(d)) == "TClass(Class<String>)";
	}
}

#end
