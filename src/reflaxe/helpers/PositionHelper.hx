// =======================================================
// * PositionHelper
//
// Helpful functions for generating Position objects.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;

class PositionHelper {
	public static function unknownPos(): Position {
		#if eval
		return Context.makePosition({ min: 0, max: 0, file: "(unknown)" });
		#else
		return { min: 0, max: 0, file: "(unknown)" };
		#end
	}
}

#end
