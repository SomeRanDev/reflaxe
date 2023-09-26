// =======================================================
// * PositionHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;

/**
	Helpful functions for generating `Position` objects.
**/
class PositionHelper {
	public static function unknownPos(): Position {
		#if eval
		return Context.makePosition({ min: 0, max: 0, file: "(unknown)" });
		#else
		return { min: 0, max: 0, file: "(unknown)" };
		#end
	}

	public static function getFile(p: Position): String {
		#if macro
		return haxe.macro.PositionTools.toLocation(p).file.toString();
		#else
		return "<unknown file>";
		#end
	}

	public static function line(p: Position): Int {
		#if macro
		return haxe.macro.PositionTools.toLocation(p).range.start.line;
		#else
		return 0;
		#end
	}

	public static function column(p: Position): Int {
		#if macro
		return haxe.macro.PositionTools.toLocation(p).range.start.character;
		#else
		return 0;
		#end
	}
}

#end
