// =======================================================
// * TVarHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

/**
	Helpful functions for `TVar` class.
**/
class TVarHelper {
	public static function copy(tvar: TVar, newName: Null<String> = null): TVar {
		var result: Dynamic = Reflect.copy(tvar);
		if(newName != null) {
			result.name = newName;
		}
		return result;
	}
}

#end
