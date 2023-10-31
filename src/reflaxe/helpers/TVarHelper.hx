// =======================================================
// * TVarHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

/**
	A modified `TVar` cannot be used by Haxe internally, so this abstract
	exists to help distiguish between modified `TVar`s and native ones.
**/
@:forward
abstract TVarOverride(TVar) from TVar {
}

/**
	Helpful functions for `TVar` class.
**/
class TVarHelper {
	public static function copy(tvar: TVar, newName: Null<String> = null): TVarOverride {
		var result: Dynamic = Reflect.copy(tvar);
		if(newName != null) {
			result.name = newName;
		}
		return (result : TVar);
	}
}

#end
