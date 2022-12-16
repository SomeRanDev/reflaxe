// =======================================================
// * TVarHelper
//
// Helpful functions for TVar class.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

class TVarHelper {
	public static function copy(tvar: TVar, newName: Null<String> = null): TVar {
		return {
			t: tvar.t,
			name: newName != null ? newName : tvar.name,
			meta: tvar.meta,
			id: tvar.id,
			extra: tvar.extra,
			capture: tvar.capture
		}
	}
}

#end
