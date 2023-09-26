// =======================================================
// * SyntaxHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

/**
	Helpful functions for quick-formatting `String`s.
	i.e. Shifting all lines in a string over with a tab.
**/
class SyntaxHelper {
	public static function tab(s: String, tabCount: Int = 1): String {
		var tabStr = "\t";
		if(tabCount > 1) {
			for(i in 1...tabCount) {
				tabStr += "\t";
			}
		}

		// maybe replace with:
		// return StringTools.replace(s, "\n", "\n\t");
		// but this easier to understand...

		final lines = s.split("\n");
		for(i in 0...lines.length) {
			if(lines[i].length > 0 && !isOnlySpaces(lines[i])) {
				lines[i] = tabStr + lines[i];
			}
		}
		return lines.join("\n");
	}

	static function isOnlySpaces(s: String): Bool {
		for(i in 0...s.length) {
			if(!StringTools.isSpace(s, i)) {
				return false;
			}
		}
		return true;
	}
}

#end
