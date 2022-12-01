// =======================================================
// * SyntaxHelper
//
// Helpful functions for quick-formatting Strings.
// i.e. Shifting all lines in a string over with a tab.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

class SyntaxHelper {
	public static function tab(s: String): String {

		// maybe replace with:
		// return StringTools.replace(s, "\n", "\n\t");
		// but this easier to understand...

		final lines = s.split("\n");
		for(i in 0...lines.length) {
			lines[i] = "\t" + lines[i];
		}
		return lines.join("\n");
	}
}

#end
